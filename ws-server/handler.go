package main

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"os/exec"
	"os/user"
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

	// Set environment variables.
	// Ensure HOME matches the real user from /etc/passwd so that SSH
	// config resolution (~/.ssh) and interactive auth work correctly.
	env := os.Environ()
	if u, err := user.Current(); err == nil && u.HomeDir != os.Getenv("HOME") {
		filtered := env[:0]
		for _, e := range env {
			if !strings.HasPrefix(e, "HOME=") {
				filtered = append(filtered, e)
			}
		}
		env = append(filtered, "HOME="+u.HomeDir)
	}
	cmd.Env = append(env,
		"TERM=xterm-256color",
		"WS_MODE=1", // Tells interactive_auth.sh to skip tee
	)

	// Use StartWithAttrs to control session/terminal setup precisely.
	// Setsid:  true — child becomes session leader (PID == PGID), required
	//                 for PTY I/O and process-group cleanup.
	// Setctty: true — make the PTY the controlling terminal. OpenSSH opens
	//                 /dev/tty for password and keyboard-interactive
	//                 prompts; without a controlling terminal it cannot
	//                 prompt and fails with "Permission denied
	//                 (keyboard-interactive)". The forked `ssh -f` child is
	//                 kept alive by the delayed ptmx.Close() after the
	//                 session exits (see below), not by omitting the
	//                 controlling terminal.
	ptmx, err := pty.StartWithAttrs(cmd, nil, &syscall.SysProcAttr{
		Setsid:  true,
		Setctty: true,
	})
	if err != nil {
		logf("ERROR", "Failed to start PTY for hash %s: %v", hash, err)
		msg := StatusMessage{Type: "status", Code: "error", Message: "Failed to start authentication session"}
		if data, err := json.Marshal(msg); err == nil {
			conn.WriteMessage(websocket.TextMessage, data)
		}
		return
	}

	// Track session state
	var (
		sessionDone    = make(chan struct{})
		clientDone     = make(chan struct{})
		clientDoneOnce sync.Once
		lastActivity   atomic.Int64
		timedOut       atomic.Bool
		wsMu           sync.Mutex // protects conn.WriteMessage (gorilla disallows concurrent writes)
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
				wsMu.Lock()
				err := conn.WriteMessage(websocket.BinaryMessage, buf[:n])
				wsMu.Unlock()
				if err != nil {
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

	exitCode := 0
	if cmd.ProcessState != nil {
		exitCode = cmd.ProcessState.ExitCode()
	}

	if timedOut.Load() {
		sendStatus(conn, &wsMu, "timeout", "Session timed out", exitCode)
	} else if exitCode == 0 {
		sendStatus(conn, &wsMu, "success", "Tunnel authenticated and running", exitCode)
	} else {
		sendStatus(conn, &wsMu, "error", "Authentication failed", exitCode)
	}

	if exitCode == 0 && !timedOut.Load() {
		// ssh -f forks after successful auth. The forked SSH child and its
		// ProxyJump subprocess inherit the PTY slave (as stderr). Closing
		// ptmx immediately would hang up the slave and kill ProxyJump,
		// breaking the tunnel's transport pipe.
		//
		// Wait for the child to fully detach (setsid + close inherited fds),
		// then close ptmx. Also close the WebSocket first so the PTY→WS
		// goroutine won't try to write after conn is gone.
		conn.Close()
		time.Sleep(3 * time.Second)
		ptmx.Close()
	} else {
		ptmx.Close()
		conn.Close()
	}

	// Wait for I/O goroutines to finish.
	wg.Wait()
}

// sendStatus sends a JSON status message over the WebSocket connection.
// mu must be the same mutex used to guard conn.WriteMessage elsewhere.
func sendStatus(conn *websocket.Conn, mu *sync.Mutex, code, message string, exitCode int) {
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

	mu.Lock()
	err = conn.WriteMessage(websocket.TextMessage, data)
	mu.Unlock()
	if err != nil {
		logf("DEBUG", "Failed to send status message: %v", err)
	}
}
