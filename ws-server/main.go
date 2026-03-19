// Package main provides a WebSocket server for interactive SSH authentication sessions.
// It spawns autossh-cli auth <hash> with a PTY and pipes I/O to the browser.
package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"
)

// Configuration with defaults
var (
	wsPort         = 8022
	apiKey         = ""
	maxConnections = 5
	idleTimeout    = 120 * time.Second
	maxDuration    = 300 * time.Second
	allowedOrigins []string
)

// Global connection tracker
var connTracker *ConnTracker

// logf formats and prints a log message with timestamp and level.
func logf(level, format string, args ...interface{}) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	msg := fmt.Sprintf(format, args...)
	log.Printf("[%s] [%s] [WS] %s", timestamp, level, msg)
}

// loadConfig reads configuration from environment variables.
func loadConfig() {
	if port := os.Getenv("WS_PORT"); port != "" {
		if p, err := strconv.Atoi(port); err == nil && p > 0 && p < 65536 {
			wsPort = p
		}
	}

	apiKey = os.Getenv("API_KEY")

	if maxConn := os.Getenv("WS_MAX_CONNECTIONS"); maxConn != "" {
		if m, err := strconv.Atoi(maxConn); err == nil && m > 0 {
			maxConnections = m
		}
	}

	if idle := os.Getenv("WS_IDLE_TIMEOUT"); idle != "" {
		if d, err := time.ParseDuration(idle); err == nil && d > 0 {
			idleTimeout = d
		}
	}

	if maxDur := os.Getenv("WS_MAX_DURATION"); maxDur != "" {
		if d, err := time.ParseDuration(maxDur); err == nil && d > 0 {
			maxDuration = d
		}
	}

	allowedOrigins = parseAllowedOrigins(os.Getenv("WS_ALLOWED_ORIGINS"))
}

// healthHandler returns the server health status.
func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, `{"status":"ok","connections":%d,"max_connections":%d}`,
		connTracker.Count(), maxConnections)
}

func main() {
	// Configure log output
	log.SetFlags(0)
	log.SetOutput(os.Stdout)

	// Load configuration
	loadConfig()

	// Initialize connection tracker
	connTracker = NewConnTracker(maxConnections)

	logf("INFO", "Starting WebSocket server on port %d", wsPort)
	logf("INFO", "Max connections: %d, Idle timeout: %s, Max duration: %s",
		maxConnections, idleTimeout, maxDuration)

	// Setup HTTP handlers
	mux := http.NewServeMux()
	mux.HandleFunc("/health", healthHandler)
	mux.HandleFunc("/ws/auth/", wsAuthHandler)

	// Create server with timeouts
	server := &http.Server{
		Addr:              fmt.Sprintf(":%d", wsPort),
		Handler:           mux,
		ReadHeaderTimeout: 10 * time.Second,
	}

	// Channel to signal shutdown
	done := make(chan struct{})

	// Handle graceful shutdown
	go func() {
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, syscall.SIGTERM, syscall.SIGINT)
		sig := <-sigChan
		logf("INFO", "Received signal %v, shutting down...", sig)

		// Create shutdown context with timeout
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := server.Shutdown(ctx); err != nil {
			logf("ERROR", "Server shutdown error: %v", err)
		}
		close(done)
	}()

	// Start server
	logf("INFO", "Server listening on :%d", wsPort)
	if err := server.ListenAndServe(); err != http.ErrServerClosed {
		logf("ERROR", "Server error: %v", err)
		os.Exit(1)
	}

	<-done
	logf("INFO", "Server stopped")
}
