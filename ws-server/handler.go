package main

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/creack/pty"
	"github.com/gorilla/websocket"
)

// StatusMessage represents a JSON status message sent to the client.
type StatusMessage struct {
	Type     string `json:"type"`
	Code     string `json:"code"`
	Message  string `json:"message"`
	ExitCode int    `json:"exit_code,omitempty"`
}

// WebSocket upgrader with custom origin check
var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin:     checkOrigin,
}

// wsAuthHandler handles WebSocket connections for interactive authentication.
func wsAuthHandler(w http.ResponseWriter, r *http.Request) {
	// Extract hash from URL path: /ws/auth/{hash}
	path := strings.TrimPrefix(r.URL.Path, "/ws/auth/")
	hash := strings.TrimSuffix(path, "/")

	// Validate hash format
	if !validateHash(hash) {
		logf("WARN", "Invalid hash format: %s", hash)
		http.Error(w, "Invalid hash format", http.StatusBadRequest)
		return
	}

	// Verify API key
	if !verifyAPIKey(r) {
		logf("WARN", "Unauthorized request for hash: %s", hash)
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	// Acquire connection slot
	if err := connTracker.Acquire(hash); err != nil {
		logf("WARN", "Connection rejected for hash %s: %v", hash, err)
		if err == ErrHashInUse {
			http.Error(w, "Session already active for this tunnel", http.StatusConflict)
		} else {
			http.Error(w, "Too many connections", http.StatusServiceUnavailable)
		}
		return
	}

	// Upgrade to WebSocket
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		logf("ERROR", "WebSocket upgrade failed for hash %s: %v", hash, err)
		connTracker.Release(hash)
		return
	}

	logf("INFO", "WebSocket connection established for hash: %s", hash)

	// Handle the session
	handleAuthSession(conn, hash)
}

// killProcessGroup sends a signal to the process group of cmd.
// Returns true if the signal was sent successfully.
func killProcessGroup(cmd *exec.Cmd, sig syscall.Signal) bool {
	if cmd.Process == nil {
		return false
	}
	return syscall.Kill(-cmd.Process.Pid, sig) == nil
}

// handleAuthSession manages the PTY session for interactive authentication.
func handleAuthSession(conn *websocket.Conn, hash string) {
	defer func() {
		conn.Close()
		connTracker.Release(hash)
		logf("INFO", "WebSocket connection closed for hash: %s", hash)
	}()

	// Prepare command
	cmd := exec.Command("/usr/local/bin/autossh-cli", "auth", hash)

	// Set environment variables
	cmd.Env = append(os.Environ(),
		"TERM=xterm-256color",
		"WS_MODE=1", // Tells interactive_auth.sh to skip tee
	)

	// Note: pty.Start() sets Setsid and Setctty on SysProcAttr internally.
	// Do NOT set Setpgid here — it conflicts with Setsid (EPERM).
	// Process group cleanup still works because setsid() makes the child
	// its own session leader, so PID == PGID.

	// Start command with PTY
	ptmx, err := pty.Start(cmd)
	if err != nil {
		logf("ERROR", "Failed to start PTY for hash %s: %v", hash, err)
		sendStatus(conn, "error", "Failed to start authentication session", 0)
		return
	}

	// Track session state
	var (
		sessionDone    = make(chan struct{})
		clientDone     = make(chan struct{})
		clientDoneOnce sync.Once
		lastActivity   atomic.Int64
		timedOut       atomic.Bool
	)
	lastActivity.Store(time.Now().Unix())

	// terminateProcess kills the process group with SIGTERM, then SIGKILL
	// after a timeout. Must be called before waiting on sessionDone.
	terminateProcess := func() {
		ptmx.Close()
		killProcessGroup(cmd, syscall.SIGTERM)

		select {
		case <-sessionDone:
		case <-time.After(3 * time.Second):
			killProcessGroup(cmd, syscall.SIGKILL)
		}
	}

	// Goroutine: PTY -> WebSocket
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		buf := make([]byte, 4096)
		for {
			n, err := ptmx.Read(buf)
			if err != nil {
				if err != io.EOF {
					logf("DEBUG", "PTY read error for hash %s: %v", hash, err)
				}
				return
			}
			if n > 0 {
				lastActivity.Store(time.Now().Unix())
				if err := conn.WriteMessage(websocket.BinaryMessage, buf[:n]); err != nil {
					logf("DEBUG", "WebSocket write error for hash %s: %v", hash, err)
					return
				}
			}
		}
	}()

	// Goroutine: WebSocket -> PTY
	wg.Add(1)
	go func() {
		defer wg.Done()
		defer func() { clientDoneOnce.Do(func() { close(clientDone) }) }()
		for {
			_, data, err := conn.ReadMessage()
			if err != nil {
				if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure) {
					logf("DEBUG", "WebSocket read error for hash %s: %v", hash, err)
				}
				return
			}
			lastActivity.Store(time.Now().Unix())
			if _, err := ptmx.Write(data); err != nil {
				logf("DEBUG", "PTY write error for hash %s: %v", hash, err)
				return
			}
		}
	}()

	// Goroutine: Wait for command to exit
	go func() {
		cmd.Wait()
		close(sessionDone)
	}()

	// Goroutine: Idle/max-duration watchdog
	go func() {
		ticker := time.NewTicker(5 * time.Second)
		defer ticker.Stop()

		startTime := time.Now()
		for {
			select {
			case <-sessionDone:
				return
			case <-ticker.C:
				// Check max duration
				if time.Since(startTime) > maxDuration {
					logf("WARN", "Session exceeded max duration for hash %s", hash)
					timedOut.Store(true)
					terminateProcess()
					return
				}

				// Check idle timeout
				lastAct := time.Unix(lastActivity.Load(), 0)
				if time.Since(lastAct) > idleTimeout {
					logf("WARN", "Session idle timeout for hash %s", hash)
					timedOut.Store(true)
					terminateProcess()
					return
				}
			}
		}
	}()

	// Wait for session to complete or client to disconnect.
	// Prioritize sessionDone to avoid killing a successfully forked SSH
	// process when both channels fire near-simultaneously.
	select {
	case <-sessionDone:
		// Command exited normally (e.g., ssh -f parent exits after fork)
	default:
		select {
		case <-sessionDone:
			// Command exited normally
		case <-clientDone:
			// Client disconnected while command still running — kill it
			logf("INFO", "Client disconnected for hash %s, terminating session", hash)
			terminateProcess()
			<-sessionDone
		}
	}

	// Determine exit status and send status message BEFORE waiting for
	// I/O goroutines — the PTY read goroutine may have already errored
	// out, which can cause the browser to close the WebSocket before we
	// get a chance to send the status.
	exitCode := 0
	if cmd.ProcessState != nil {
		exitCode = cmd.ProcessState.ExitCode()
	}

	if timedOut.Load() {
		sendStatus(conn, "timeout", "Session timed out", exitCode)
	} else if exitCode == 0 {
		// ssh -f forks after successful auth, parent exits with code 0
		// This indicates successful authentication
		sendStatus(conn, "success", "Tunnel authenticated and running", exitCode)
	} else {
		sendStatus(conn, "error", "Authentication failed", exitCode)
	}

	// Wait for I/O goroutines to finish
	wg.Wait()
}

// sendStatus sends a JSON status message over the WebSocket connection.
func sendStatus(conn *websocket.Conn, code, message string, exitCode int) {
	status := StatusMessage{
		Type:    "status",
		Code:    code,
		Message: message,
	}
	if code == "error" {
		status.ExitCode = exitCode
	}

	data, err := json.Marshal(status)
	if err != nil {
		logf("ERROR", "Failed to marshal status message: %v", err)
		return
	}

	if err := conn.WriteMessage(websocket.TextMessage, data); err != nil {
		logf("DEBUG", "Failed to send status message: %v", err)
	}
}
