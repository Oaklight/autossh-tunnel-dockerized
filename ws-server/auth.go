package main

import (
	"net/http"
	"net/url"
	"regexp"
	"strings"
)

// hashRegex validates that a hash is exactly 32 hex characters (MD5 output).
var hashRegex = regexp.MustCompile(`^[0-9a-f]{32}$`)

// parseAllowedOrigins parses a comma-separated list of allowed origins.
func parseAllowedOrigins(origins string) []string {
	if origins == "" {
		return nil
	}
	parts := strings.Split(origins, ",")
	result := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			result = append(result, p)
		}
	}
	return result
}

// checkOrigin validates the WebSocket upgrade request origin.
// If WS_ALLOWED_ORIGINS is set, checks against the list.
// Otherwise, performs same-origin check (Origin host == Host header).
func checkOrigin(r *http.Request) bool {
	origin := r.Header.Get("Origin")
	if origin == "" {
		// No origin header, allow (e.g., non-browser clients)
		return true
	}

	// Parse origin URL
	originURL, err := url.Parse(origin)
	if err != nil {
		logf("WARN", "Invalid origin URL: %s", origin)
		return false
	}

	// If allowed origins are configured, check against the list
	if len(allowedOrigins) > 0 {
		for _, allowed := range allowedOrigins {
			if allowed == "*" {
				return true
			}
			// Compare full origin or just host
			if origin == allowed || originURL.Host == allowed {
				return true
			}
		}
		logf("WARN", "Origin %s not in allowed list", origin)
		return false
	}

	// Same-origin check: Origin host must match Host header
	host := r.Host
	// Remove port from host if present for comparison
	if idx := strings.LastIndex(host, ":"); idx != -1 {
		host = host[:idx]
	}
	originHost := originURL.Hostname()

	if originHost != host {
		logf("WARN", "Origin host %s does not match request host %s", originHost, host)
		return false
	}

	return true
}

// verifyAPIKey checks the API key from query parameter or Authorization header.
// If API_KEY env var is empty, allows all requests (matches http_utils.sh:verify_auth pattern).
func verifyAPIKey(r *http.Request) bool {
	// If no API key configured, allow all
	if apiKey == "" {
		return true
	}

	// Check query parameter first
	token := r.URL.Query().Get("token")
	if token == apiKey {
		return true
	}

	// Check Authorization header
	authHeader := r.Header.Get("Authorization")
	if authHeader != "" {
		// Support "Bearer <token>" format
		if strings.HasPrefix(authHeader, "Bearer ") {
			token = strings.TrimPrefix(authHeader, "Bearer ")
			if token == apiKey {
				return true
			}
		}
		// Also support raw token
		if authHeader == apiKey {
			return true
		}
	}

	return false
}

// validateHash checks if the hash is a valid 32-character hex string.
// This matches the MD5 output format from config_parser.sh:calculate_tunnel_hash.
func validateHash(hash string) bool {
	return hashRegex.MatchString(hash)
}
