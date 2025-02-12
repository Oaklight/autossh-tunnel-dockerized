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
	configDir       = "config"
	configFile      = "config/config.yaml"
	staticDir       = "static"
	templatesDir    = "templates"
	backupDir       = "config/backups"
	defaultPort     = ":5000"
)

type Tunnel struct {
	Name        string `yaml:"name" json:"name"`
	RemoteHost  string `yaml:"remote_host" json:"remote_host"`
	RemotePort  string `yaml:"remote_port" json:"remote_port"`
	LocalPort   string `yaml:"local_port" json:"local_port"`
	Direction   string `yaml:"direction" json:"direction"`
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
	timestamp := time.Now().Format("20060102150405")
	backupFile := filepath.Join(backupDir, fmt.Sprintf("config_%s.yaml", timestamp))

	// Get ownership and permissions of the original config file
	uid, gid, mode, err := getFileOwnershipAndPermissions(configFile)
	if err != nil && !os.IsNotExist(err) {
		return err
	}

	// Ensure the backup directory exists with the correct ownership and permissions
	if err := createDirectoryWithOwnership(backupDir, uid, gid, mode|os.ModeDir); err != nil {
		return err
	}

	// Backup the existing config file if it exists
	if _, err := os.Stat(configFile); !os.IsNotExist(err) {
		err := os.Rename(configFile, backupFile)
		if err != nil {
			return err
		}

		// Apply the same ownership and permissions to the backup file
		if err := setFileOwnershipAndPermissions(backupFile, uid, gid, mode); err != nil {
			return err
		}
	}

	// Write the new config file
	data, err := yaml.Marshal(config)
	if err != nil {
		return err
	}
	if err := ioutil.WriteFile(configFile, data, mode); err != nil {
		return err
	}

	// Apply the same ownership and permissions to the new config file
	if err := setFileOwnershipAndPermissions(configFile, uid, gid, mode); err != nil {
		return err
	}

	return nil
}

func homeHandler(w http.ResponseWriter, r *http.Request) {
	tmpl := template.Must(template.ParseFiles(filepath.Join(templatesDir, "index.html")))
	tmpl.Execute(w, nil)
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

	fmt.Printf("Starting server on %s\n", defaultPort)
	log.Fatal(http.ListenAndServe(defaultPort, nil))
}
