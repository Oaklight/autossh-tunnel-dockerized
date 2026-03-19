package main

import (
	"errors"
	"sync"
	"testing"
)

// --- NewConnTracker ---

func TestNewConnTracker(t *testing.T) {
	ct := NewConnTracker(10)
	if ct == nil {
		t.Fatal("NewConnTracker returned nil")
	}
	if ct.maxConns != 10 {
		t.Errorf("maxConns = %d, want 10", ct.maxConns)
	}
	if ct.Count() != 0 {
		t.Errorf("Count() = %d, want 0 for new tracker", ct.Count())
	}
}

// --- Acquire / Release / Count ---

func TestAcquire_Success(t *testing.T) {
	ct := NewConnTracker(5)
	hash := "aaaabbbbccccddddeeeeffffaaaabbbb"

	err := ct.Acquire(hash)
	if err != nil {
		t.Fatalf("Acquire(%q) returned error: %v", hash, err)
	}
	if ct.Count() != 1 {
		t.Errorf("Count() = %d, want 1 after Acquire", ct.Count())
	}
}

func TestAcquire_MultipleHashes(t *testing.T) {
	ct := NewConnTracker(5)
	hashes := []string{
		"aaaa0000000000000000000000000001",
		"aaaa0000000000000000000000000002",
		"aaaa0000000000000000000000000003",
	}

	for _, h := range hashes {
		if err := ct.Acquire(h); err != nil {
			t.Fatalf("Acquire(%q) returned error: %v", h, err)
		}
	}
	if ct.Count() != 3 {
		t.Errorf("Count() = %d, want 3", ct.Count())
	}
}

func TestAcquire_ErrHashInUse(t *testing.T) {
	ct := NewConnTracker(5)
	hash := "aaaabbbbccccddddeeeeffffaaaabbbb"

	if err := ct.Acquire(hash); err != nil {
		t.Fatalf("first Acquire failed: %v", err)
	}

	err := ct.Acquire(hash)
	if !errors.Is(err, ErrHashInUse) {
		t.Errorf("second Acquire(%q) = %v, want ErrHashInUse", hash, err)
	}

	// Count should still be 1 (failed acquire should not change count)
	if ct.Count() != 1 {
		t.Errorf("Count() = %d, want 1 after duplicate Acquire", ct.Count())
	}
}

func TestAcquire_ErrMaxConnections(t *testing.T) {
	ct := NewConnTracker(2)
	h1 := "aaaa0000000000000000000000000001"
	h2 := "aaaa0000000000000000000000000002"
	h3 := "aaaa0000000000000000000000000003"

	ct.Acquire(h1)
	ct.Acquire(h2)

	err := ct.Acquire(h3)
	if !errors.Is(err, ErrMaxConnections) {
		t.Errorf("Acquire(%q) when at max = %v, want ErrMaxConnections", h3, err)
	}

	if ct.Count() != 2 {
		t.Errorf("Count() = %d, want 2 after rejected Acquire", ct.Count())
	}
}

func TestAcquire_MaxOneConnection(t *testing.T) {
	ct := NewConnTracker(1)
	h1 := "aaaa0000000000000000000000000001"
	h2 := "aaaa0000000000000000000000000002"

	if err := ct.Acquire(h1); err != nil {
		t.Fatalf("Acquire(%q) failed: %v", h1, err)
	}

	err := ct.Acquire(h2)
	if !errors.Is(err, ErrMaxConnections) {
		t.Errorf("Acquire(%q) with max=1 = %v, want ErrMaxConnections", h2, err)
	}
}

// --- Release ---

func TestRelease(t *testing.T) {
	ct := NewConnTracker(5)
	hash := "aaaabbbbccccddddeeeeffffaaaabbbb"

	ct.Acquire(hash)
	ct.Release(hash)

	if ct.Count() != 0 {
		t.Errorf("Count() = %d, want 0 after Release", ct.Count())
	}
}

func TestRelease_AllowsReacquire(t *testing.T) {
	ct := NewConnTracker(5)
	hash := "aaaabbbbccccddddeeeeffffaaaabbbb"

	ct.Acquire(hash)
	ct.Release(hash)

	// Should be able to acquire the same hash again
	err := ct.Acquire(hash)
	if err != nil {
		t.Errorf("re-Acquire(%q) after Release failed: %v", hash, err)
	}
}

func TestRelease_FreesSlotForNewHash(t *testing.T) {
	ct := NewConnTracker(1)
	h1 := "aaaa0000000000000000000000000001"
	h2 := "aaaa0000000000000000000000000002"

	ct.Acquire(h1)
	ct.Release(h1)

	// Now h2 should be acquirable even with max=1
	err := ct.Acquire(h2)
	if err != nil {
		t.Errorf("Acquire(%q) after releasing h1 failed: %v", h2, err)
	}
}

func TestRelease_NonExistent(t *testing.T) {
	ct := NewConnTracker(5)
	// Releasing a hash that was never acquired should not panic
	ct.Release("aaaa0000000000000000000000000001")
	if ct.Count() != 0 {
		t.Errorf("Count() = %d, want 0 after releasing non-existent hash", ct.Count())
	}
}

// --- IsActive ---

func TestIsActive(t *testing.T) {
	ct := NewConnTracker(5)
	hash := "aaaabbbbccccddddeeeeffffaaaabbbb"

	if ct.IsActive(hash) {
		t.Error("IsActive should be false before Acquire")
	}

	ct.Acquire(hash)
	if !ct.IsActive(hash) {
		t.Error("IsActive should be true after Acquire")
	}

	ct.Release(hash)
	if ct.IsActive(hash) {
		t.Error("IsActive should be false after Release")
	}
}

// --- Concurrent Access ---

func TestConcurrentAcquireRelease(t *testing.T) {
	ct := NewConnTracker(100)
	var wg sync.WaitGroup
	n := 50

	// Spawn 50 goroutines that each acquire a unique hash
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			// Generate unique 32-char hex hash per goroutine
			hash := uniqueHash(idx)
			if err := ct.Acquire(hash); err != nil {
				t.Errorf("concurrent Acquire(%q) failed: %v", hash, err)
			}
		}(i)
	}
	wg.Wait()

	if ct.Count() != n {
		t.Errorf("Count() = %d, want %d after concurrent Acquires", ct.Count(), n)
	}

	// Release all concurrently
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			ct.Release(uniqueHash(idx))
		}(i)
	}
	wg.Wait()

	if ct.Count() != 0 {
		t.Errorf("Count() = %d, want 0 after concurrent Releases", ct.Count())
	}
}

func TestConcurrentDuplicateAcquire(t *testing.T) {
	ct := NewConnTracker(100)
	hash := "aaaabbbbccccddddeeeeffffaaaabbbb"
	n := 20

	var (
		wg        sync.WaitGroup
		mu        sync.Mutex
		successes int
		hashInUse int
	)

	for i := 0; i < n; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			err := ct.Acquire(hash)
			mu.Lock()
			defer mu.Unlock()
			if err == nil {
				successes++
			} else if errors.Is(err, ErrHashInUse) {
				hashInUse++
			}
		}()
	}
	wg.Wait()

	if successes != 1 {
		t.Errorf("expected exactly 1 successful Acquire, got %d", successes)
	}
	if hashInUse != n-1 {
		t.Errorf("expected %d ErrHashInUse errors, got %d", n-1, hashInUse)
	}
}

func TestConcurrentMaxConnections(t *testing.T) {
	maxConns := 5
	ct := NewConnTracker(maxConns)
	n := 20

	var (
		wg        sync.WaitGroup
		mu        sync.Mutex
		successes int
		maxConErr int
	)

	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			hash := uniqueHash(idx)
			err := ct.Acquire(hash)
			mu.Lock()
			defer mu.Unlock()
			if err == nil {
				successes++
			} else if errors.Is(err, ErrMaxConnections) {
				maxConErr++
			}
		}(i)
	}
	wg.Wait()

	if successes != maxConns {
		t.Errorf("expected %d successful Acquires, got %d", maxConns, successes)
	}
	if maxConErr != n-maxConns {
		t.Errorf("expected %d ErrMaxConnections, got %d", n-maxConns, maxConErr)
	}
}

// uniqueHash generates a deterministic 32-char hex hash from an index.
func uniqueHash(idx int) string {
	// Pad index to 32 hex chars: "00000000000000000000000000000042"
	s := "00000000000000000000000000000000"
	suffix := hexIndex(idx)
	return s[:32-len(suffix)] + suffix
}

func hexIndex(n int) string {
	const digits = "0123456789abcdef"
	if n == 0 {
		return "0"
	}
	result := ""
	for n > 0 {
		result = string(digits[n%16]) + result
		n /= 16
	}
	return result
}
