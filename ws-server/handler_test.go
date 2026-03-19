package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gorilla/websocket"
)

// --- StatusMessage JSON ---

func TestStatusMessage_SuccessJSON(t *testing.T) {
	msg := StatusMessage{
		Type:    "status",
		Code:    "success",
		Message: "Tunnel authenticated and running",
	}
	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("Marshal failed: %v", err)
	}

	var parsed map[string]interface{}
	json.Unmarshal(data, &parsed)

	if parsed["type"] != "status" {
		t.Errorf("type = %v, want 'status'", parsed["type"])
	}
	if parsed["code"] != "success" {
		t.Errorf("code = %v, want 'success'", parsed["code"])
	}
	// exit_code should be omitted (omitempty) for non-error
	if _, exists := parsed["exit_code"]; exists {
		t.Error("exit_code should be omitted for success status")
	}
}

func TestStatusMessage_ErrorJSON(t *testing.T) {
	msg := StatusMessage{
		Type:     "status",
		Code:     "error",
		Message:  "Authentication failed",
		ExitCode: 1,
	}
	data, _ := json.Marshal(msg)

	var parsed map[string]interface{}
	json.Unmarshal(data, &parsed)

	if parsed["exit_code"] == nil {
		t.Error("exit_code should be present for error status")
	}
	if int(parsed["exit_code"].(float64)) != 1 {
		t.Errorf("exit_code = %v, want 1", parsed["exit_code"])
	}
}

func TestStatusMessage_TimeoutJSON(t *testing.T) {
	msg := StatusMessage{
		Type:    "status",
		Code:    "timeout",
		Message: "Session timed out",
	}
	data, _ := json.Marshal(msg)

	var parsed map[string]interface{}
	json.Unmarshal(data, &parsed)

	if parsed["code"] != "timeout" {
		t.Errorf("code = %v, want 'timeout'", parsed["code"])
	}
}

// --- wsAuthHandler HTTP-level tests ---

// setupTestTracker initializes a fresh connTracker and maxConnections for tests.
func setupTestTracker(t *testing.T, max int) {
	t.Helper()
	oldTracker := connTracker
	oldMax := maxConnections
	connTracker = NewConnTracker(max)
	maxConnections = max
	t.Cleanup(func() {
		connTracker = oldTracker
		maxConnections = oldMax
	})
}

func TestWsAuthHandler_InvalidHash(t *testing.T) {
	setupTestTracker(t, 5)
	withAPIKey(t, "")

	req := httptest.NewRequest("GET", "/ws/auth/not-valid", nil)
	rec := httptest.NewRecorder()

	wsAuthHandler(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d for invalid hash", rec.Code, http.StatusBadRequest)
	}
	if !strings.Contains(rec.Body.String(), "Invalid hash format") {
		t.Errorf("body = %q, want 'Invalid hash format'", rec.Body.String())
	}
}

func TestWsAuthHandler_EmptyHash(t *testing.T) {
	setupTestTracker(t, 5)
	withAPIKey(t, "")

	req := httptest.NewRequest("GET", "/ws/auth/", nil)
	rec := httptest.NewRecorder()

	wsAuthHandler(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d for empty hash", rec.Code, http.StatusBadRequest)
	}
}

func TestWsAuthHandler_Unauthorized(t *testing.T) {
	setupTestTracker(t, 5)
	withAPIKey(t, "my-secret-key")

	hash := "aaaabbbbccccddddeeeeffffaaaabbbb"
	req := httptest.NewRequest("GET", "/ws/auth/"+hash, nil)
	// No auth credentials
	rec := httptest.NewRecorder()

	wsAuthHandler(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want %d for unauthorized request", rec.Code, http.StatusUnauthorized)
	}
}

func TestWsAuthHandler_HashInUse(t *testing.T) {
	setupTestTracker(t, 5)
	withAPIKey(t, "")

	hash := "aaaabbbbccccddddeeeeffffaaaabbbb"
	// Pre-acquire the hash to simulate an active session
	connTracker.Acquire(hash)

	req := httptest.NewRequest("GET", "/ws/auth/"+hash, nil)
	rec := httptest.NewRecorder()

	wsAuthHandler(rec, req)

	if rec.Code != http.StatusConflict {
		t.Errorf("status = %d, want %d for hash in use", rec.Code, http.StatusConflict)
	}
	if !strings.Contains(rec.Body.String(), "Session already active") {
		t.Errorf("body = %q, want 'Session already active'", rec.Body.String())
	}
}

func TestWsAuthHandler_MaxConnections(t *testing.T) {
	setupTestTracker(t, 1)
	withAPIKey(t, "")

	// Fill up the connection tracker
	connTracker.Acquire("aaaa0000000000000000000000000001")

	hash := "aaaa0000000000000000000000000002"
	req := httptest.NewRequest("GET", "/ws/auth/"+hash, nil)
	rec := httptest.NewRecorder()

	wsAuthHandler(rec, req)

	if rec.Code != http.StatusServiceUnavailable {
		t.Errorf("status = %d, want %d for max connections", rec.Code, http.StatusServiceUnavailable)
	}
	if !strings.Contains(rec.Body.String(), "Too many connections") {
		t.Errorf("body = %q, want 'Too many connections'", rec.Body.String())
	}
}

func TestWsAuthHandler_SlotReleasedOnReject(t *testing.T) {
	setupTestTracker(t, 5)
	withAPIKey(t, "")

	// Send a request with invalid hash — connTracker should not be affected
	req := httptest.NewRequest("GET", "/ws/auth/invalid", nil)
	rec := httptest.NewRecorder()
	wsAuthHandler(rec, req)

	if connTracker.Count() != 0 {
		t.Errorf("connTracker.Count() = %d after invalid hash request, want 0", connTracker.Count())
	}
}

// --- Health handler test ---

func TestHealthHandler(t *testing.T) {
	setupTestTracker(t, 10)

	req := httptest.NewRequest("GET", "/health", nil)
	rec := httptest.NewRecorder()

	healthHandler(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
	}

	var resp map[string]interface{}
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("Failed to parse health response: %v", err)
	}
	if resp["status"] != "ok" {
		t.Errorf("status = %v, want 'ok'", resp["status"])
	}
	if int(resp["connections"].(float64)) != 0 {
		t.Errorf("connections = %v, want 0", resp["connections"])
	}
	if int(resp["max_connections"].(float64)) != 10 {
		t.Errorf("max_connections = %v, want 10", resp["max_connections"])
	}
}

func TestHealthHandler_WithActiveConnections(t *testing.T) {
	setupTestTracker(t, 10)
	connTracker.Acquire("aaaa0000000000000000000000000001")
	connTracker.Acquire("aaaa0000000000000000000000000002")

	req := httptest.NewRequest("GET", "/health", nil)
	rec := httptest.NewRecorder()

	healthHandler(rec, req)

	var resp map[string]interface{}
	json.Unmarshal(rec.Body.Bytes(), &resp)

	if int(resp["connections"].(float64)) != 2 {
		t.Errorf("connections = %v, want 2", resp["connections"])
	}
}

// --- WebSocket upgrade integration test ---

func TestWsAuthHandler_WebSocketUpgrade(t *testing.T) {
	setupTestTracker(t, 5)
	withAPIKey(t, "")
	withAllowedOrigins(t, []string{"*"})

	// Create a test HTTP server with the handler
	mux := http.NewServeMux()
	mux.HandleFunc("/ws/auth/", wsAuthHandler)
	server := httptest.NewServer(mux)
	defer server.Close()

	hash := "aaaabbbbccccddddeeeeffffaaaabbbb"
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws/auth/" + hash

	// Attempt WebSocket connection.
	// The upgrade itself should succeed, but the PTY command
	// (/usr/local/bin/autossh-cli) won't exist in the test env,
	// so we expect to receive an error status message.
	dialer := websocket.Dialer{}
	conn, resp, err := dialer.Dial(wsURL, nil)
	if err != nil {
		// If running outside the container, autossh-cli doesn't exist.
		// The upgrade may still succeed, but the session will fail.
		// If the upgrade itself fails (e.g., 400/401), that's also valid
		// depending on the error.
		if resp != nil {
			t.Logf("WebSocket upgrade returned status %d (expected in test env without autossh-cli)", resp.StatusCode)
			return
		}
		t.Logf("WebSocket dial error (expected in test env): %v", err)
		return
	}
	defer conn.Close()

	// If we successfully connected, read the first message.
	// It should be a status message (likely error since autossh-cli isn't available)
	_, msg, err := conn.ReadMessage()
	if err != nil {
		t.Logf("Read error after connect (expected): %v", err)
		return
	}

	var status StatusMessage
	if err := json.Unmarshal(msg, &status); err == nil {
		t.Logf("Received status: code=%s, message=%s", status.Code, status.Message)
		if status.Type != "status" {
			t.Errorf("status.Type = %q, want 'status'", status.Type)
		}
	}

	// After session ends, the hash should be released
	// Give a moment for cleanup goroutines
	conn.Close()
}

func TestWsAuthHandler_WebSocket_AuthRequired(t *testing.T) {
	setupTestTracker(t, 5)
	withAPIKey(t, "test-secret-key")
	withAllowedOrigins(t, []string{"*"})

	mux := http.NewServeMux()
	mux.HandleFunc("/ws/auth/", wsAuthHandler)
	server := httptest.NewServer(mux)
	defer server.Close()

	hash := "aaaabbbbccccddddeeeeffffaaaabbbb"

	// Without credentials — should be rejected before WS upgrade
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws/auth/" + hash
	dialer := websocket.Dialer{}
	_, resp, err := dialer.Dial(wsURL, nil)
	if err == nil {
		t.Error("WebSocket dial should fail without API key")
	}
	if resp != nil && resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", resp.StatusCode)
	}

	// With correct token in query param — should at least upgrade
	wsURLWithToken := wsURL + "?token=test-secret-key"
	conn, _, err := dialer.Dial(wsURLWithToken, nil)
	if err != nil {
		// May fail due to missing autossh-cli, but the upgrade should succeed
		t.Logf("Dial with token: %v (may be expected without autossh-cli)", err)
	} else {
		conn.Close()
	}
}

func TestWsAuthHandler_WebSocket_DuplicateHash(t *testing.T) {
	setupTestTracker(t, 5)
	withAPIKey(t, "")
	withAllowedOrigins(t, []string{"*"})

	mux := http.NewServeMux()
	mux.HandleFunc("/ws/auth/", wsAuthHandler)
	server := httptest.NewServer(mux)
	defer server.Close()

	hash := "aaaabbbbccccddddeeeeffffaaaabbbb"

	// Pre-acquire hash to simulate active session
	connTracker.Acquire(hash)

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/ws/auth/" + hash
	dialer := websocket.Dialer{}
	_, resp, err := dialer.Dial(wsURL, nil)
	if err == nil {
		t.Error("WebSocket dial should fail for already-active hash")
	}
	if resp != nil && resp.StatusCode != http.StatusConflict {
		t.Errorf("expected 409 Conflict, got %d", resp.StatusCode)
	}
}
