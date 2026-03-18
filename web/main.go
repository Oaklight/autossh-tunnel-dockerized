package main

import (
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	staticDir    = "static"
	templatesDir = "templates"
	defaultPort  = ":5000"
)

var version = "dev"
var apiBaseURL string
var apiKey string

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
	BaseURL string `json:"base_url"`
	APIKey  string `json:"api_key,omitempty"`
}

// getAPIConfigHandler returns API configuration for frontend
func getAPIConfigHandler(w http.ResponseWriter, r *http.Request) {
	logMsg("DEBUG", "WEB", "GET /api/config/api from %s", r.RemoteAddr)
	config := APIConfigResponse{
		BaseURL: apiBaseURL,
		APIKey:  apiKey,
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

func main() {
	// Configure logging to match the unified format
	// [YYYY-MM-DD HH:MM:SS] [LEVEL] [COMPONENT] Message
	log.SetFlags(0) // Disable default flags
	log.SetOutput(os.Stdout)

	printBanner()

	apiBaseURL = os.Getenv("API_BASE_URL")
	apiKey = os.Getenv("API_KEY")

	if apiKey != "" {
		logMsg("INFO", "WEB", "API key authentication enabled")
	}

	if apiBaseURL == "" {
		logMsg("WARN", "WEB", "API_BASE_URL not set, frontend will not be able to communicate with autossh API")
	} else {
		logMsg("INFO", "WEB", "API base URL: %s", apiBaseURL)
	}

	fs := http.FileServer(http.Dir(staticDir))
	http.Handle("/static/", http.StripPrefix("/static/", fs))

	http.HandleFunc("/", homeHandler)
	http.HandleFunc("/help", helpHandler)
	http.HandleFunc("/tunnel-detail", tunnelDetailHandler)
	http.HandleFunc("/api/languages", getLanguagesHandler)
	http.HandleFunc("/api/config/api", getAPIConfigHandler)

	logMsg("INFO", "WEB", "Starting server on %s", defaultPort)
	logMsg("INFO", "WEB", "Web panel is now a static server - all config operations go through autossh API")
	err := http.ListenAndServe(defaultPort, nil)
	if err != nil {
		logMsg("ERROR", "WEB", "Server failed: %v", err)
		os.Exit(1)
	}
}
