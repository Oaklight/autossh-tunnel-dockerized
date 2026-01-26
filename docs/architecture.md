# Architecture

This document describes the architecture of the SSH Tunnel Manager, including the Docker containers and their interactions.

## System Overview

The SSH Tunnel Manager provides two Docker images:

1. **autossh-tunnel** (Required) - The core tunnel management container
2. **autossh-tunnel-web-panel** (Optional) - Web-based management interface

!!! note "Minimal Setup"
    You only need the `autossh-tunnel` container to run SSH tunnels. The web panel is optional and provides a convenient UI for management.

```mermaid
graph TB
    subgraph "Host Machine"
        SSH[~/.ssh<br/>SSH Keys & Config]
        CONFIG[./config<br/>config.yaml]
        BROWSER[Browser]
    end
    
    subgraph "Docker Containers"
        subgraph "autossh Container (Required)"
            ENTRY[entrypoint.sh]
            MONITOR[spinoff_monitor.sh]
            CLI[autossh-cli]
            API[API Server<br/>:8080]
            AUTOSSH[autossh processes]
            STATE[State Manager]
        end
        
        subgraph "web Container (Optional)"
            WEBSERVER[Go Web Server<br/>:5000]
        end
    end
    
    subgraph "Remote Servers"
        REMOTE1[Remote Host 1]
        REMOTE2[Remote Host 2]
    end
    
    SSH -->|read-only mount| ENTRY
    CONFIG -->|read-only mount| ENTRY
    CONFIG -->|read-write mount| WEBSERVER
    
    ENTRY --> MONITOR
    MONITOR --> CLI
    CLI --> STATE
    CLI --> AUTOSSH
    API --> CLI
    
    BROWSER -->|Static files| WEBSERVER
    BROWSER -->|Direct API calls| API
    
    AUTOSSH -->|SSH Tunnel| REMOTE1
    AUTOSSH -->|SSH Tunnel| REMOTE2
```

---

## autossh-tunnel Container

**Image:** `oaklight/autossh-tunnel:latest`

The core container that manages SSH tunnels using autossh.

### Components

| Component | Description |
|-----------|-------------|
| `entrypoint.sh` | Initializes the container, sets up permissions, and starts the main process |
| `spinoff_monitor.sh` | Monitors config file changes and triggers tunnel restarts |
| `autossh-cli` | Command-line interface for tunnel management |
| `API Server` | HTTP API for programmatic control (optional, port 8080) |
| `autossh` | The actual SSH tunnel processes |
| `State Manager` | Tracks running tunnels and their PIDs |

### Volume Mounts

| Host Path | Container Path | Mode | Description |
|-----------|----------------|------|-------------|
| `~/.ssh` | `/home/myuser/.ssh` | `ro` | SSH keys and config (read-only) |
| `./config` | `/etc/autossh/config` | `ro` | Tunnel configuration (read-only) |

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `PUID` | User ID for file permissions | `1000` | No |
| `PGID` | Group ID for file permissions | `1000` | No |
| `API_ENABLE` | Enable HTTP API server | `false` | No |
| `API_PORT` | HTTP API server port (when API enabled) | `8080` | No |
| `AUTOSSH_GATETIME` | Autossh gate time (seconds before connection considered stable) | `0` | No |
| `AUTOSSH_CONFIG_FILE` | Path to configuration file | `/etc/autossh/config/config.yaml` | No |
| `SSH_CONFIG_DIR` | SSH config directory | `/home/myuser/.ssh` | No |
| `AUTOSSH_STATE_FILE` | Path to state file | `/tmp/autossh_tunnels.state` | No |

### API Endpoints (when API_ENABLE=true)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/list` | List all configured tunnels |
| GET | `/status` | Get status of all tunnels |
| POST | `/start` | Start all tunnels |
| POST | `/stop` | Stop all tunnels |
| POST | `/start/{hash}` | Start specific tunnel |
| POST | `/stop/{hash}` | Stop specific tunnel |
| GET | `/logs` | List available log files |
| GET | `/logs/{hash}` | Get logs for specific tunnel |

### Minimal Docker Compose Example

```yaml
name: autotunnel
services:
  autossh:
    image: oaklight/autossh-tunnel:latest
    volumes:
      - ~/.ssh:/home/myuser/.ssh:ro
      - ./config:/etc/autossh/config:ro
    environment:
      - PUID=1000
      - PGID=1000
    network_mode: "host"
    restart: always
```

### With API Enabled

```yaml
name: autotunnel
services:
  autossh:
    image: oaklight/autossh-tunnel:latest
    volumes:
      - ~/.ssh:/home/myuser/.ssh:ro
      - ./config:/etc/autossh/config:ro
    environment:
      - PUID=1000
      - PGID=1000
      - API_ENABLE=true
      - API_PORT=8080
    network_mode: "host"
    restart: always
```

---

## autossh-tunnel-web-panel Container

**Image:** `oaklight/autossh-tunnel-web-panel:latest`

An optional web-based management interface that communicates with the autossh container's API.

!!! warning "Prerequisite"
    The web panel requires the autossh container to have `API_ENABLE=true` set.

### Components

| Component | Description |
|-----------|-------------|
| `Go Web Server` | Serves static files and manages configuration |
| `Web UI` | HTML/CSS/JavaScript frontend with i18n support (runs in browser) |

### Volume Mounts

| Host Path | Container Path | Mode | Description |
|-----------|----------------|------|-------------|
| `./config` | `/home/myuser/config` | `rw` | Tunnel configuration (for editing) |

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `PUID` | User ID for file permissions | `1000` | No |
| `PGID` | Group ID for file permissions | `1000` | No |
| `TZ` | Timezone for log timestamps | `UTC` | No |
| `API_BASE_URL` | URL of the autossh API server (passed to browser) | `http://localhost:8080` | **Yes** |

!!! info "Direct API Architecture"
    The `API_BASE_URL` is passed to the browser-based frontend, which makes API calls directly to the autossh container. The Go web server does not proxy API requests - it only serves static files and manages configuration.

### Docker Compose Example

```yaml
name: autotunnel
services:
  web:
    image: oaklight/autossh-tunnel-web-panel:latest
    ports:
      - "5000:5000"
    volumes:
      - ./config:/home/myuser/config
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Shanghai
      - API_BASE_URL=http://localhost:8080
    restart: always
```

!!! note "Network Mode"
    The web container uses bridge networking with port mapping instead of host network mode. API calls are made directly from the browser to the API server.

---

## Full Stack Deployment

When using both containers together:

```yaml
name: autotunnel
services:
  autossh:
    image: oaklight/autossh-tunnel:latest
    volumes:
      - ~/.ssh:/home/myuser/.ssh:ro
      - ./config:/etc/autossh/config:ro
    environment:
      - PUID=1000
      - PGID=1000
      - AUTOSSH_GATETIME=0
      - API_ENABLE=true
      - API_PORT=8080
    network_mode: "host"
    restart: always

  web:
    image: oaklight/autossh-tunnel-web-panel:latest
    ports:
      - "5000:5000"
    volumes:
      - ./config:/home/myuser/config:rw
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Shanghai
      - API_BASE_URL=http://localhost:8080
    restart: always
```

!!! note "Configuration Editing"
    The web panel mounts the config directory as read-write (`rw`) to allow editing the configuration through the UI. The autossh container only needs read access (`ro`) since it only reads the configuration.

!!! info "Network Architecture"
    - The **autossh container** uses host network mode to allow tunnels to bind to specific IP addresses
    - The **web container** uses bridge networking with port mapping (5000:5000)
    - The browser makes **direct API calls** to the autossh API server (port 8080)
    - The Go web server only serves static files and configuration management endpoints

---

## Communication Flow

### Web Panel to Tunnel Control (Direct API Architecture)

The web panel uses a **direct API architecture** where the browser makes API calls directly to the autossh API server, bypassing the Go web server for tunnel control operations.

```mermaid
sequenceDiagram
    participant User
    participant Browser as Browser
    participant WebServer as Go Web Server (:5000)
    participant API as API Server (:8080)
    participant CLI as autossh-cli
    participant Tunnel as autossh process

    Note over Browser,WebServer: Initial page load
    User->>Browser: Open web panel
    Browser->>WebServer: GET / (static files)
    WebServer-->>Browser: HTML/CSS/JS
    Browser->>WebServer: GET /api/config/api
    WebServer-->>Browser: {base_url: "http://localhost:8080"}
    
    Note over Browser,API: Direct API calls from browser
    User->>Browser: Click "Start Tunnel"
    Browser->>API: POST /start/{hash}
    API->>CLI: autossh-cli start-tunnel {hash}
    CLI->>Tunnel: Start autossh process
    Tunnel-->>CLI: PID
    CLI-->>API: Success + output
    API-->>Browser: JSON response
    Browser-->>User: Update UI
```

!!! tip "Benefits of Direct API Architecture"
    - **Simplified networking**: Web container doesn't need host network mode
    - **Reduced latency**: No proxy overhead for API calls
    - **Better scalability**: Web server only handles static files
    - **Clearer separation**: Configuration management vs tunnel control

### Configuration Change Detection

```mermaid
sequenceDiagram
    participant User
    participant WebUI as Web UI
    participant Config as config.yaml
    participant Monitor as spinoff_monitor.sh
    participant CLI as autossh-cli
    participant Tunnels as autossh processes

    User->>WebUI: Save configuration
    WebUI->>Config: Write config.yaml
    Monitor->>Config: Detect file change (inotify)
    Monitor->>CLI: autossh-cli start
    CLI->>Tunnels: Smart restart
    Note over CLI,Tunnels: Only restart changed tunnels
```

---

## Network Mode

The containers use different network modes based on their requirements:

### autossh Container (Host Network)

The autossh container uses `network_mode: "host"` to:

1. Allow direct access to host network interfaces
2. Enable tunnels to bind to specific IP addresses
3. Simplify port forwarding configuration

### web Container (Bridge Network)

The web container uses bridge networking with port mapping:

```yaml
ports:
  - "5000:5000"
```

This is possible because:

1. The web server only serves static files and configuration endpoints
2. All API calls are made directly from the browser to the API server
3. No proxy functionality is needed between web and autossh containers

!!! note "API Accessibility"
    Since the browser makes direct API calls to port 8080, the API server must be accessible from the user's browser. When using host network mode for autossh, the API is available on `localhost:8080` from the host machine.

---

## File Structure

```
/home/myuser/                    # In containers
├── .ssh/                        # SSH keys and config (from host)
│   ├── config                   # SSH host configurations
│   ├── id_ed25519              # Private key
│   └── known_hosts             # Known hosts
└── config/                      # Tunnel configuration (web container)
    └── config.yaml             # Tunnel definitions

/etc/autossh/config/             # In autossh container
└── config.yaml                  # Tunnel definitions

/tmp/                            # Runtime files
├── autossh_tunnels.state       # Tunnel state tracking
└── autossh-logs/               # Tunnel log files
    └── tunnel-{hash}.log       # Per-tunnel logs
```

---

## Security Considerations

1. **SSH Keys**: Mounted read-only to prevent modification
2. **Non-root User**: Containers run as `myuser` (configurable via PUID/PGID)
3. **State Isolation**: Each tunnel has isolated state and logs
4. **API Access**: API server only accessible on localhost by default (host network mode)