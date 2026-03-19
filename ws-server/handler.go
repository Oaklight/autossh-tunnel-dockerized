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

	// Set process group for cleanup
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Setpgid: true,
	}

	// Start command with PTY
	ptmx, err := pty.Start(cmd)
	if err != nil {
		logf("ERROR", "Failed to start PTY for hash %s: %v", hash, err)
		sendStatus(conn, "error", "Failed to start authentication session", 0)
		return
	}

	// Track session state
	var (
		sessionDone  = make(chan struct{})
		lastActivity atomic.Int64
		timedOut     atomic.Bool
	)
	lastActivity.Store(time.Now().Unix())

	// Cleanup function
	cleanup := func() {
		// Close PTY
		ptmx.Close()

		// Kill process group
		if cmd.Process != nil {
			pgid := -cmd.Process.Pid
			// Send SIGTERM to process group
			syscall.Kill(pgid, syscall.SIGTERM)

			// Wait up to 3 seconds for graceful shutdown
			done := make(chan struct{})
			go func() {
				cmd.Wait()
				close(done)
			}()

			select {
			case <-done:
				// Process exited gracefully
			case <-time.After(3 * time.Second):
				// Force kill
				syscall.Kill(pgid, syscall.SIGKILL)
				cmd.Wait()
			}
		}
	}
	defer cleanup()

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
					ptmx.Close()
					return
				}

				// Check idle timeout
				lastAct := time.Unix(lastActivity.Load(), 0)
				if time.Since(lastAct) > idleTimeout {
					logf("WARN", "Session idle timeout for hash %s", hash)
					timedOut.Store(true)
					ptmx.Close()
					return
				}
			}
		}
	}()

	// Wait for session to complete
	<-sessionDone

	// Wait for I/O goroutines to finish
	wg.Wait()

	// Determine exit status and send appropriate message
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
