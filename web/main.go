package main

import (
	"encoding/json"
	"fmt"
	"html/template"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	staticDir    = "static"
	templatesDir = "templates"
	defaultPort  = ":5000"
)

var version = "dev"
var apiBaseURL string
var apiKey string
var wsBaseURL string

func printBanner() {
	line1 := fmt.Sprintf("AutoSSH Tunnel Manager  %s", version)
	line2 := fmt.Sprintf("Web Panel: http://0.0.0.0%s", defaultPort)
	width := len(line1)
	if len(line2) > width {
		width = len(line2)
	}
	border := strings.Repeat("═", width+6)
	fmt.Printf("  ╔%s╗\n", border)
	fmt.Printf("  ║   %-*s   ║\n", width, line1)
	fmt.Printf("  ║   %-*s   ║\n", width, line2)
	fmt.Printf("  ╚%s╝\n", border)
}

func logMsg(level, component, format string, v ...interface{}) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	msg := fmt.Sprintf(format, v...)
	fmt.Printf("[%s] [%s] [%s] %s\n", timestamp, level, component, msg)
}

type Language struct {
	Code string `json:"code"`
	Name string `json:"name"`
}

func homeHandler(w http.ResponseWriter, r *http.Request) {
	logMsg("INFO", "WEB", "GET / from %s", r.RemoteAddr)
	tmpl := template.Must(template.ParseFiles(filepath.Join(templatesDir, "index.html")))
	tmpl.Execute(w, nil)
}

func helpHandler(w http.ResponseWriter, r *http.Request) {
	logMsg("INFO", "WEB", "GET /help from %s", r.RemoteAddr)
	tmpl := template.Must(template.ParseFiles(filepath.Join(templatesDir, "help.html")))
	tmpl.Execute(w, nil)
}

func tunnelDetailHandler(w http.ResponseWriter, r *http.Request) {
	logMsg("INFO", "WEB", "GET /tunnel-detail?%s from %s", r.URL.RawQuery, r.RemoteAddr)
	tmpl := template.Must(template.ParseFiles(filepath.Join(templatesDir, "tunnel-detail.html")))
	data := struct {
		APIBaseURL string
	}{
		APIBaseURL: apiBaseURL,
	}
	tmpl.Execute(w, data)
}

// APIConfigResponse contains API configuration for frontend
type APIConfigResponse struct {
	BaseURL   string `json:"base_url"`
	APIKey    string `json:"api_key,omitempty"`
	WSEnabled bool   `json:"ws_enabled"`
}

// getAPIConfigHandler returns API configuration for frontend
func getAPIConfigHandler(w http.ResponseWriter, r *http.Request) {
	logMsg("DEBUG", "WEB", "GET /api/config/api from %s", r.RemoteAddr)
	config := APIConfigResponse{
		BaseURL:   apiBaseURL,
		APIKey:    apiKey,
		WSEnabled: wsBaseURL != "",
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(config)
}

func getLanguagesHandler(w http.ResponseWriter, r *http.Request) {
	logMsg("DEBUG", "WEB", "GET /api/languages from %s", r.RemoteAddr)
	localesDir := filepath.Join(staticDir, "locales")

	// Check if locales directory exists
	if _, err := os.Stat(localesDir); os.IsNotExist(err) {
		logMsg("ERROR", "WEB", "Locales directory not found: %s", localesDir)
		http.Error(w, "Locales directory not found", http.StatusNotFound)
		return
	}

	// Read directory contents
	files, err := os.ReadDir(localesDir)
	if err != nil {
		http.Error(w, "Failed to read locales directory", http.StatusInternalServerError)
		return
	}

	var languages []Language
	// 9 core languages: Chinese (Simplified & Traditional), English, Japanese, Korean, Spanish, French, Russian, Arabic
	languageNames := map[string]string{
		"zh":      "中文 (简体)",
		"zh-hant": "中文 (繁體)",
		"en":      "English",
		"ja":      "日本語",
		"ko":      "한국어",
		"es":      "Español",
		"fr":      "Français",
		"ru":      "Русский",
		"ar":      "العربية",
	}

	// Scan for .json files
	for _, file := range files {
		if !file.IsDir() && strings.HasSuffix(file.Name(), ".json") {
			// Extract language code from filename (e.g., "en.json" -> "en")
			langCode := strings.TrimSuffix(file.Name(), ".json")

			// Get language name from map, fallback to code if not found
			langName := languageNames[langCode]
			if langName == "" {
				langName = strings.ToUpper(langCode) // Fallback to uppercase code
			}

			languages = append(languages, Language{
				Code: langCode,
				Name: langName,
			})
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(languages)
}

// WebSocket upgrader for client connections
var wsUpgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		// Allow all origins for now; in production, you may want to restrict this
		return true
	},
}

// wsProxyHandler proxies WebSocket connections to the backend ws-server
func wsProxyHandler(w http.ResponseWriter, r *http.Request) {
	if wsBaseURL == "" {
		logMsg("ERROR", "WEB", "WebSocket proxy requested but WS_BASE_URL not configured")
		http.Error(w, "WebSocket not configured", http.StatusServiceUnavailable)
		return
	}

	// Extract hash from URL path: /ws/auth/{hash}
	path := strings.TrimPrefix(r.URL.Path, "/ws/auth/")
	hash := strings.TrimSuffix(path, "/")

	logMsg("INFO", "WEB", "WebSocket proxy request for hash %s from %s", hash, r.RemoteAddr)

	// Build backend WebSocket URL
	backendURL, err := url.Parse(wsBaseURL)
	if err != nil {
		logMsg("ERROR", "WEB", "Invalid WS_BASE_URL: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}
	backendURL.Path = "/ws/auth/" + hash

	// Forward query parameters (including token)
	backendURL.RawQuery = r.URL.RawQuery

	// Upgrade client connection
	clientConn, err := wsUpgrader.Upgrade(w, r, nil)
	if err != nil {
		logMsg("ERROR", "WEB", "Failed to upgrade client WebSocket: %v", err)
		return
	}
	defer clientConn.Close()

	// Build headers for backend connection
	backendHeaders := http.Header{}
	if auth := r.Header.Get("Authorization"); auth != "" {
		backendHeaders.Set("Authorization", auth)
	}

	// Connect to backend ws-server
	backendConn, _, err := websocket.DefaultDialer.Dial(backendURL.String(), backendHeaders)
	if err != nil {
		logMsg("ERROR", "WEB", "Failed to connect to backend WebSocket: %v", err)
		clientConn.WriteMessage(websocket.TextMessage, []byte(`{"type":"status","code":"error","message":"Failed to connect to authentication server"}`))
		return
	}
	defer backendConn.Close()

	logMsg("INFO", "WEB", "WebSocket proxy established for hash %s", hash)

	// Bidirectional proxy
	var wg sync.WaitGroup
	wg.Add(2)

	// Client -> Backend
	go func() {
		defer wg.Done()
		for {
			messageType, data, err := clientConn.ReadMessage()
			if err != nil {
				if !websocket.IsCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure) {
					logMsg("DEBUG", "WEB", "Client read error for hash %s: %v", hash, err)
				}
				backendConn.Close()
				return
			}
			if err := backendConn.WriteMessage(messageType, data); err != nil {
				logMsg("DEBUG", "WEB", "Backend write error for hash %s: %v", hash, err)
				return
			}
		}
	}()

	// Backend -> Client
	go func() {
		defer wg.Done()
		for {
			messageType, data, err := backendConn.ReadMessage()
			if err != nil {
				if !websocket.IsCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure) {
					logMsg("DEBUG", "WEB", "Backend read error for hash %s: %v", hash, err)
				}
				clientConn.Close()
				return
			}
			if err := clientConn.WriteMessage(messageType, data); err != nil {
				logMsg("DEBUG", "WEB", "Client write error for hash %s: %v", hash, err)
				return
			}
		}
	}()

	wg.Wait()
	logMsg("INFO", "WEB", "WebSocket proxy closed for hash %s", hash)
}

func main() {
	// Configure logging to match the unified format
	// [YYYY-MM-DD HH:MM:SS] [LEVEL] [COMPONENT] Message
	log.SetFlags(0) // Disable default flags
	log.SetOutput(os.Stdout)

	printBanner()

	apiBaseURL = os.Getenv("API_BASE_URL")
	apiKey = os.Getenv("API_KEY")
	wsBaseURL = os.Getenv("WS_BASE_URL")

	if apiKey != "" {
		logMsg("INFO", "WEB", "API key authentication enabled")
	}

	if apiBaseURL == "" {
		logMsg("WARN", "WEB", "API_BASE_URL not set, frontend will not be able to communicate with autossh API")
	} else {
		logMsg("INFO", "WEB", "API base URL: %s", apiBaseURL)
	}

	if wsBaseURL != "" {
		logMsg("INFO", "WEB", "WebSocket proxy enabled, backend URL: %s", wsBaseURL)
	} else {
		logMsg("INFO", "WEB", "WebSocket proxy disabled (WS_BASE_URL not set)")
	}

	listenAddr := defaultPort
	if p := os.Getenv("PORT"); p != "" {
		if !strings.HasPrefix(p, ":") {
			p = ":" + p
		}
		listenAddr = p
	}

	fs := http.FileServer(http.Dir(staticDir))
	http.Handle("/static/", http.StripPrefix("/static/", fs))

	http.HandleFunc("/", homeHandler)
	http.HandleFunc("/help", helpHandler)
	http.HandleFunc("/tunnel-detail", tunnelDetailHandler)
	http.HandleFunc("/api/languages", getLanguagesHandler)
	http.HandleFunc("/api/config/api", getAPIConfigHandler)
	http.HandleFunc("/ws/auth/", wsProxyHandler)

	logMsg("INFO", "WEB", "Starting server on %s", listenAddr)
	logMsg("INFO", "WEB", "Web panel is now a static server - all config operations go through autossh API")
	err := http.ListenAndServe(listenAddr, nil)
	if err != nil {
		logMsg("ERROR", "WEB", "Server failed: %v", err)
		os.Exit(1)
	}
}

// Ensure io package is used (for potential future use)
var _ = io.EOF
