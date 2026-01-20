package main

import (
	"encoding/json"
	"fmt"
	"html/template"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path/filepath"
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
}

type TunnelStatus struct {
	Name   string `json:"name"`
	Status string `json:"status"`
}

type Config struct {
	Tunnels []Tunnel `yaml:"tunnels" json:"tunnels"`
}

func loadConfig() (Config, error) {
	var config Config
	if _, err := os.Stat(configFile); os.IsNotExist(err) {
		return Config{Tunnels: []Tunnel{}}, nil
	}
	data, err := ioutil.ReadFile(configFile)
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

	if err := ioutil.WriteFile(configFile, data, mode); err != nil {
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

func fetchTunnelStatuses() (map[string]string, error) {
	if apiBaseURL == "" {
		return nil, nil
	}
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(apiBaseURL + "/status")
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var statuses []TunnelStatus
	if err := json.NewDecoder(resp.Body).Decode(&statuses); err != nil {
		return nil, err
	}

	statusMap := make(map[string]string)
	for _, s := range statuses {
		statusMap[s.Name] = s.Status
	}
	return statusMap, nil
}

func getConfigHandler(w http.ResponseWriter, r *http.Request) {
	config, err := loadConfig()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Fetch statuses
	statuses, err := fetchTunnelStatuses()
	if err != nil {
		logMsg("WARN", "WEB", "Error fetching statuses: %v", err)
	}

	for i := range config.Tunnels {
		if statuses == nil {
			config.Tunnels[i].Status = "N/A"
		} else if status, ok := statuses[config.Tunnels[i].Name]; ok {
			config.Tunnels[i].Status = status
		} else {
			config.Tunnels[i].Status = "STOPPED"
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(config)
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

	logMsg("INFO", "WEB", "Starting server on %s", defaultPort)
	err := http.ListenAndServe(defaultPort, nil)
	if err != nil {
		logMsg("ERROR", "WEB", "Server failed: %v", err)
		os.Exit(1)
	}
}
