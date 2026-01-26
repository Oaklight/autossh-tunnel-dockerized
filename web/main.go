package main

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"gopkg.in/yaml.v3"
)

const (
	configDir    = "/home/myuser/config"
	configFile   = "/home/myuser/config/config.yaml"
	staticDir    = "static"
	templatesDir = "templates"
	backupDir    = "/home/myuser/config/backups"
	defaultPort  = ":5000"
)

var apiBaseURL string

func logMsg(level, component, format string, v ...interface{}) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	msg := fmt.Sprintf(format, v...)
	fmt.Printf("[%s] [%s] [%s] %s\n", timestamp, level, component, msg)
}

type Tunnel struct {
	Name        string `yaml:"name" json:"name"`
	RemoteHost  string `yaml:"remote_host" json:"remote_host"`
	RemotePort  string `yaml:"remote_port" json:"remote_port"`
	LocalPort   string `yaml:"local_port" json:"local_port"`
	Interactive bool   `yaml:"interactive" json:"interactive"`
	Direction   string `yaml:"direction" json:"direction"`
	Status      string `yaml:"-" json:"status,omitempty"`
	Hash        string `yaml:"-" json:"hash,omitempty"`
}

type Config struct {
	Tunnels []Tunnel `yaml:"tunnels" json:"tunnels"`
}

type Language struct {
	Code string `json:"code"`
	Name string `json:"name"`
}

// calculateTunnelHash calculates MD5 hash for tunnel configuration
// This must match the hash calculation in scripts/config_parser.sh
func calculateTunnelHash(t Tunnel) string {
	// Format: name|remote_host|remote_port|local_port|direction|interactive
	interactive := "false"
	if t.Interactive {
		interactive = "true"
	}
	hashInput := fmt.Sprintf("%s|%s|%s|%s|%s|%s",
		t.Name, t.RemoteHost, t.RemotePort, t.LocalPort, t.Direction, interactive)
	
	hash := md5.Sum([]byte(hashInput))
	return hex.EncodeToString(hash[:])
}

func loadConfig() (Config, error) {
	var config Config
	if _, err := os.Stat(configFile); os.IsNotExist(err) {
		return Config{Tunnels: []Tunnel{}}, nil
	}
	data, err := os.ReadFile(configFile)
	if err != nil {
		return config, err
	}
	err = yaml.Unmarshal(data, &config)
	if err != nil {
		return config, err
	}
	for i := range config.Tunnels {
		if config.Tunnels[i].Direction == "" {
			config.Tunnels[i].Direction = "remote_to_local"
		}
		// Calculate and set hash for each tunnel
		config.Tunnels[i].Hash = calculateTunnelHash(config.Tunnels[i])
	}
	return config, nil
}

func getFileOwnershipAndPermissions(filePath string) (uid, gid int, mode os.FileMode, err error) {
	info, err := os.Stat(filePath)
	if err != nil {
		return 0, 0, 0, err
	}

	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok {
		return 0, 0, 0, fmt.Errorf("failed to get file ownership")
	}

	return int(stat.Uid), int(stat.Gid), info.Mode(), nil
}

func setFileOwnershipAndPermissions(filePath string, uid, gid int, mode os.FileMode) error {
	// Change ownership
	if err := os.Chown(filePath, uid, gid); err != nil {
		return err
	}

	// Change permissions
	if err := os.Chmod(filePath, mode); err != nil {
		return err
	}

	return nil
}

func createDirectoryWithOwnership(dirPath string, uid, gid int, mode os.FileMode) error {
	if err := os.MkdirAll(dirPath, mode); err != nil {
		return err
	}
	return setFileOwnershipAndPermissions(dirPath, uid, gid, mode)
}

func saveConfig(config Config) error {
	logMsg("INFO", "WEB", "Starting saveConfig...")
	timestamp := time.Now().Format("20060102150405")
	backupFile := filepath.Join(backupDir, fmt.Sprintf("config_%s.yaml", timestamp))

	// Get ownership and permissions of the original config file
	uid, gid, mode, err := getFileOwnershipAndPermissions(configFile)
	if err != nil && !os.IsNotExist(err) {
		logMsg("ERROR", "WEB", "Error getting file ownership and permissions: %v", err)
		return err
	}

	// Ensure the backup directory exists with the correct ownership and permissions
	// Add execute permission for the owner (0100)
	backupMode := mode | os.ModeDir | 0100

	// Ensure the backup directory exists with the correct ownership and permissions
	if err := createDirectoryWithOwnership(backupDir, uid, gid, backupMode); err != nil {
		logMsg("ERROR", "WEB", "Error creating backup directory: %v", err)
		return err
	}

	// Backup the existing config file if it exists
	if _, err := os.Stat(configFile); !os.IsNotExist(err) {
		if err := os.Rename(configFile, backupFile); err != nil {
			logMsg("ERROR", "WEB", "Error backing up config file: %v", err)
			return err
		}

		// Apply the same ownership and permissions to the backup file
		if err := setFileOwnershipAndPermissions(backupFile, uid, gid, mode); err != nil {
			logMsg("ERROR", "WEB", "Error setting ownership/permissions on backup file: %v", err)
			return err
		}
	}

	// Write the new config file
	data, err := yaml.Marshal(config)
	if err != nil {
		logMsg("ERROR", "WEB", "Error marshaling config to YAML: %v", err)
		return err
	}

	if err := os.WriteFile(configFile, data, mode); err != nil {
		logMsg("ERROR", "WEB", "Error writing config file: %v. Check ownership and permissions.", err)
		return err
	}

	// Apply the same ownership and permissions to the new config file
	if err := setFileOwnershipAndPermissions(configFile, uid, gid, mode); err != nil {
		logMsg("ERROR", "WEB", "Error setting ownership/permissions on config file: %v", err)
		return err
	}

	logMsg("INFO", "WEB", "Config saved successfully.")
	return nil
}

func checkConfigDirectory() error {
	info, err := os.Stat(configDir)
	if os.IsNotExist(err) {
		return fmt.Errorf("config directory '%s' does not exist. Please ensure it is mounted correctly", configDir)
	}
	if err != nil {
		return fmt.Errorf("failed to access config directory '%s': %v", configDir, err)
	}

	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok {
		return fmt.Errorf("failed to get ownership of config directory '%s'", configDir)
	}

	uid, gid := int(stat.Uid), int(stat.Gid)
	expectedUID, expectedGID := os.Getuid(), os.Getgid()
	if uid != expectedUID || gid != expectedGID {
		return fmt.Errorf("ownership mismatch for config directory '%s'. Expected UID: %d, GID: %d; Got UID: %d, GID: %d",
			configDir, expectedUID, expectedGID, uid, gid)
	}

	return nil
}

func homeHandler(w http.ResponseWriter, r *http.Request) {
	tmpl := template.Must(template.ParseFiles(filepath.Join(templatesDir, "index.html")))
	tmpl.Execute(w, nil)
}

func helpHandler(w http.ResponseWriter, r *http.Request) {
	tmpl := template.Must(template.ParseFiles(filepath.Join(templatesDir, "help.html")))
	tmpl.Execute(w, nil)
}

func tunnelDetailHandler(w http.ResponseWriter, r *http.Request) {
	tmpl := template.Must(template.ParseFiles(filepath.Join(templatesDir, "tunnel-detail.html")))
	data := struct {
		APIBaseURL string
	}{
		APIBaseURL: apiBaseURL,
	}
	tmpl.Execute(w, data)
}

func getConfigHandler(w http.ResponseWriter, r *http.Request) {
	config, err := loadConfig()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(config)
}

// getAPIConfigHandler returns API configuration for frontend
func getAPIConfigHandler(w http.ResponseWriter, r *http.Request) {
	response := map[string]string{
		"base_url": apiBaseURL,
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func updateConfigHandler(w http.ResponseWriter, r *http.Request) {
	var config Config
	err := json.NewDecoder(r.Body).Decode(&config)
	if err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}
	err = saveConfig(config)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status": "success"}`))
}

func getLanguagesHandler(w http.ResponseWriter, r *http.Request) {
	localesDir := filepath.Join(staticDir, "locales")
	
	// Check if locales directory exists
	if _, err := os.Stat(localesDir); os.IsNotExist(err) {
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

	apiBaseURL = os.Getenv("API_BASE_URL")

	// Check if the config directory exists and has correct ownership
	if err := checkConfigDirectory(); err != nil {
		logMsg("ERROR", "WEB", "Configuration error: %v", err)
		os.Exit(1)
	}

	fs := http.FileServer(http.Dir(staticDir))
	http.Handle("/static/", http.StripPrefix("/static/", fs))

	http.HandleFunc("/", homeHandler)
	http.HandleFunc("/help", helpHandler)
	http.HandleFunc("/tunnel-detail", tunnelDetailHandler)
	http.HandleFunc("/api/config", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			getConfigHandler(w, r)
		case http.MethodPost:
			updateConfigHandler(w, r)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})
	http.HandleFunc("/api/languages", getLanguagesHandler)
	http.HandleFunc("/api/config/api", getAPIConfigHandler)

	logMsg("INFO", "WEB", "Starting server on %s", defaultPort)
	err := http.ListenAndServe(defaultPort, nil)
	if err != nil {
		logMsg("ERROR", "WEB", "Server failed: %v", err)
		os.Exit(1)
	}
}
