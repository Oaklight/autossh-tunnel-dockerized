package main

import (
	"net/http/httptest"
	"testing"
)

// --- validateHash ---

func TestValidateHash_Valid(t *testing.T) {
	valid := []string{
		"aaaabbbbccccddddeeeeffffaaaabbbb",
		"00000000000000000000000000000000",
		"ffffffffffffffffffffffffffffffff",
		"0123456789abcdef0123456789abcdef",
		"a1b2c3d4e5f60718293a4b5c6d7e8f90",
	}
	for _, h := range valid {
		if !validateHash(h) {
			t.Errorf("validateHash(%q) = false, want true", h)
		}
	}
}

func TestValidateHash_Invalid(t *testing.T) {
	invalid := []string{
		"",                                   // empty
		"abc",                                // too short
		"aaaabbbbccccddddeeeeffff",           // 24 chars (too short)
		"aaaabbbbccccddddeeeeffffaaaabbbbcc", // 34 chars (too long)
		"AAAABBBBCCCCDDDDEEEEFFFFAAAABBBB",   // uppercase
		"gggghhhhiiiijjjjkkkkllllmmmmnnnn",   // non-hex chars
		"aaaabbbbccccddddeeeeffffaaaabbb!",   // special char
		"aaaa bbbb cccc dddd eeee ffff aaaa",  // spaces
		"aaaa\nbbbbccccddddeeeeffffaaaabbbb",  // newline
	}
	for _, h := range invalid {
		if validateHash(h) {
			t.Errorf("validateHash(%q) = true, want false", h)
		}
	}
}

// --- parseAllowedOrigins ---

func TestParseAllowedOrigins(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  []string
	}{
		{
			name:  "empty string",
			input: "",
			want:  nil,
		},
		{
			name:  "single origin",
			input: "http://localhost:5000",
			want:  []string{"http://localhost:5000"},
		},
		{
			name:  "multiple origins",
			input: "http://localhost:5000,http://example.com:3000",
			want:  []string{"http://localhost:5000", "http://example.com:3000"},
		},
		{
			name:  "with whitespace",
			input: " http://localhost:5000 , http://example.com:3000 ",
			want:  []string{"http://localhost:5000", "http://example.com:3000"},
		},
		{
			name:  "wildcard",
			input: "*",
			want:  []string{"*"},
		},
		{
			name:  "trailing comma",
			input: "http://localhost:5000,",
			want:  []string{"http://localhost:5000"},
		},
		{
			name:  "empty entries filtered",
			input: "http://a.com,,http://b.com",
			want:  []string{"http://a.com", "http://b.com"},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseAllowedOrigins(tt.input)
			if tt.want == nil {
				if got != nil {
					t.Errorf("parseAllowedOrigins(%q) = %v, want nil", tt.input, got)
				}
				return
			}
			if len(got) != len(tt.want) {
				t.Errorf("parseAllowedOrigins(%q) returned %d items, want %d", tt.input, len(got), len(tt.want))
				return
			}
			for i := range tt.want {
				if got[i] != tt.want[i] {
					t.Errorf("parseAllowedOrigins(%q)[%d] = %q, want %q", tt.input, i, got[i], tt.want[i])
				}
			}
		})
	}
}

// --- verifyAPIKey ---

// withAPIKey sets the package-level apiKey for the duration of a test.
func withAPIKey(t *testing.T, key string) {
	t.Helper()
	old := apiKey
	apiKey = key
	t.Cleanup(func() { apiKey = old })
}

func TestVerifyAPIKey_NoKeyConfigured(t *testing.T) {
	withAPIKey(t, "")

	r := httptest.NewRequest("GET", "/ws/auth/abc", nil)
	if !verifyAPIKey(r) {
		t.Error("verifyAPIKey should allow all requests when API_KEY is empty")
	}
}

func TestVerifyAPIKey_QueryParam(t *testing.T) {
	withAPIKey(t, "secret-123")

	// Correct token
	r := httptest.NewRequest("GET", "/ws/auth/abc?token=secret-123", nil)
	if !verifyAPIKey(r) {
		t.Error("verifyAPIKey should accept correct token in query param")
	}

	// Wrong token
	r = httptest.NewRequest("GET", "/ws/auth/abc?token=wrong", nil)
	if verifyAPIKey(r) {
		t.Error("verifyAPIKey should reject wrong token in query param")
	}
}

func TestVerifyAPIKey_BearerHeader(t *testing.T) {
	withAPIKey(t, "secret-123")

	// Correct Bearer token
	r := httptest.NewRequest("GET", "/ws/auth/abc", nil)
	r.Header.Set("Authorization", "Bearer secret-123")
	if !verifyAPIKey(r) {
		t.Error("verifyAPIKey should accept correct Bearer token")
	}

	// Wrong Bearer token
	r = httptest.NewRequest("GET", "/ws/auth/abc", nil)
	r.Header.Set("Authorization", "Bearer wrong")
	if verifyAPIKey(r) {
		t.Error("verifyAPIKey should reject wrong Bearer token")
	}
}

func TestVerifyAPIKey_RawHeader(t *testing.T) {
	withAPIKey(t, "secret-123")

	// Correct raw token
	r := httptest.NewRequest("GET", "/ws/auth/abc", nil)
	r.Header.Set("Authorization", "secret-123")
	if !verifyAPIKey(r) {
		t.Error("verifyAPIKey should accept correct raw Authorization header")
	}

	// Wrong raw token
	r = httptest.NewRequest("GET", "/ws/auth/abc", nil)
	r.Header.Set("Authorization", "nope")
	if verifyAPIKey(r) {
		t.Error("verifyAPIKey should reject wrong raw Authorization header")
	}
}

func TestVerifyAPIKey_NoCredentials(t *testing.T) {
	withAPIKey(t, "secret-123")

	r := httptest.NewRequest("GET", "/ws/auth/abc", nil)
	if verifyAPIKey(r) {
		t.Error("verifyAPIKey should reject requests with no credentials when API_KEY is set")
	}
}

// --- checkOrigin ---

// withAllowedOrigins sets the package-level allowedOrigins for the duration of a test.
func withAllowedOrigins(t *testing.T, origins []string) {
	t.Helper()
	old := allowedOrigins
	allowedOrigins = origins
	t.Cleanup(func() { allowedOrigins = old })
}

func TestCheckOrigin_NoOriginHeader(t *testing.T) {
	withAllowedOrigins(t, nil)

	r := httptest.NewRequest("GET", "/ws/auth/abc", nil)
	r.Host = "localhost:8022"
	// No Origin header — should allow (non-browser client)
	if !checkOrigin(r) {
		t.Error("checkOrigin should allow requests without Origin header")
	}
}

func TestCheckOrigin_SameOrigin(t *testing.T) {
	withAllowedOrigins(t, nil) // no allowlist → same-origin check

	// Same host
	r := httptest.NewRequest("GET", "/ws/auth/abc", nil)
	r.Host = "localhost:8022"
	r.Header.Set("Origin", "http://localhost:5000")
	if !checkOrigin(r) {
		t.Error("checkOrigin should allow same-origin (localhost == localhost)")
	}

	// Different host
	r = httptest.NewRequest("GET", "/ws/auth/abc", nil)
	r.Host = "localhost:8022"
	r.Header.Set("Origin", "http://evil.com")
	if checkOrigin(r) {
		t.Error("checkOrigin should reject different origin (evil.com != localhost)")
	}
}

func TestCheckOrigin_SameOrigin_HostWithoutPort(t *testing.T) {
	withAllowedOrigins(t, nil)

	// Host without port
	r := httptest.NewRequest("GET", "/ws/auth/abc", nil)
	r.Host = "myapp.example.com"
	r.Header.Set("Origin", "https://myapp.example.com")
	if !checkOrigin(r) {
		t.Error("checkOrigin should allow same-origin when Host has no port")
	}
}

func TestCheckOrigin_AllowedList_Match(t *testing.T) {
	withAllowedOrigins(t, []string{"http://localhost:5000", "https://app.example.com"})

	r := httptest.NewRequest("GET", "/ws/auth/abc", nil)
	r.Host = "localhost:8022"
	r.Header.Set("Origin", "http://localhost:5000")
	if !checkOrigin(r) {
		t.Error("checkOrigin should allow origin in allowedOrigins list")
	}

	r = httptest.NewRequest("GET", "/ws/auth/abc", nil)
	r.Host = "localhost:8022"
	r.Header.Set("Origin", "https://app.example.com")
	if !checkOrigin(r) {
		t.Error("checkOrigin should allow second origin in allowedOrigins list")
	}
}

func TestCheckOrigin_AllowedList_NoMatch(t *testing.T) {
	withAllowedOrigins(t, []string{"http://localhost:5000"})

	r := httptest.NewRequest("GET", "/ws/auth/abc", nil)
	r.Host = "localhost:8022"
	r.Header.Set("Origin", "http://attacker.com")
	if checkOrigin(r) {
		t.Error("checkOrigin should reject origin not in allowedOrigins list")
	}
}

func TestCheckOrigin_AllowedList_Wildcard(t *testing.T) {
	withAllowedOrigins(t, []string{"*"})

	r := httptest.NewRequest("GET", "/ws/auth/abc", nil)
	r.Host = "localhost:8022"
	r.Header.Set("Origin", "http://anything.com")
	if !checkOrigin(r) {
		t.Error("checkOrigin should allow any origin when wildcard is in list")
	}
}

func TestCheckOrigin_AllowedList_HostMatch(t *testing.T) {
	// When allowedOrigins contains just a host (no scheme), it should match originURL.Host
	withAllowedOrigins(t, []string{"localhost:5000"})

	r := httptest.NewRequest("GET", "/ws/auth/abc", nil)
	r.Host = "localhost:8022"
	r.Header.Set("Origin", "http://localhost:5000")
	if !checkOrigin(r) {
		t.Error("checkOrigin should match origin host against allowedOrigins host entries")
	}
}

func TestCheckOrigin_InvalidOriginURL(t *testing.T) {
	withAllowedOrigins(t, nil)

	r := httptest.NewRequest("GET", "/ws/auth/abc", nil)
	r.Host = "localhost:8022"
	r.Header.Set("Origin", "://invalid")
	// url.Parse may or may not fail on this depending on Go version,
	// but we at least verify it doesn't panic
	checkOrigin(r)
}

func TestCheckOrigin_IPAddress(t *testing.T) {
	withAllowedOrigins(t, nil)

	// Same IP
	r := httptest.NewRequest("GET", "/ws/auth/abc", nil)
	r.Host = "192.168.1.100:8022"
	r.Header.Set("Origin", "http://192.168.1.100:5000")
	if !checkOrigin(r) {
		t.Error("checkOrigin should allow same IP origin")
	}

	// Different IP
	r = httptest.NewRequest("GET", "/ws/auth/abc", nil)
	r.Host = "192.168.1.100:8022"
	r.Header.Set("Origin", "http://10.0.0.1:5000")
	if checkOrigin(r) {
		t.Error("checkOrigin should reject different IP origin")
	}
}
