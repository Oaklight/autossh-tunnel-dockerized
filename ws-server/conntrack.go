package main

import (
	"errors"
	"sync"
)

// ErrHashInUse is returned when a hash already has an active connection.
var ErrHashInUse = errors.New("hash already has an active connection")

// ErrMaxConnections is returned when the maximum number of connections is reached.
var ErrMaxConnections = errors.New("maximum connections reached")

// ConnTracker manages active WebSocket connections with per-hash tracking.
type ConnTracker struct {
	mu       sync.Mutex
	active   map[string]struct{}
	maxConns int
}

// NewConnTracker creates a new connection tracker with the specified maximum connections.
func NewConnTracker(maxConns int) *ConnTracker {
	return &ConnTracker{
		active:   make(map[string]struct{}),
		maxConns: maxConns,
	}
}

// Acquire attempts to acquire a connection slot for the given hash.
// Returns an error if the hash is already in use or the maximum connections are reached.
func (ct *ConnTracker) Acquire(hash string) error {
	ct.mu.Lock()
	defer ct.mu.Unlock()

	// Check if hash is already in use
	if _, exists := ct.active[hash]; exists {
		return ErrHashInUse
	}

	// Check global connection limit
	if len(ct.active) >= ct.maxConns {
		return ErrMaxConnections
	}

	// Acquire the slot
	ct.active[hash] = struct{}{}
	return nil
}

// Release releases the connection slot for the given hash.
func (ct *ConnTracker) Release(hash string) {
	ct.mu.Lock()
	defer ct.mu.Unlock()
	delete(ct.active, hash)
}

// Count returns the current number of active connections.
func (ct *ConnTracker) Count() int {
	ct.mu.Lock()
	defer ct.mu.Unlock()
	return len(ct.active)
}

// IsActive checks if a hash has an active connection.
func (ct *ConnTracker) IsActive(hash string) bool {
	ct.mu.Lock()
	defer ct.mu.Unlock()
	_, exists := ct.active[hash]
	return exists
}
