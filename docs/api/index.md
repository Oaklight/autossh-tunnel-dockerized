# Tunnel Control API Documentation

## Overview

This document describes the individual tunnel control functionality in the SSH Tunnel Manager project, allowing you to independently start, stop, and manage individual SSH tunnels without affecting other running tunnels.

## Features

- **Independent Control**: Start or stop any tunnel individually
- **Smart Detection**: Automatically checks if a tunnel is already running before starting
- **State Management**: Real-time tracking of each tunnel's running status
- **Multiple Interfaces**: Supports both CLI commands and HTTP API
- **Isolated Logging**: Each tunnel has its own log file

## CLI Commands

### Basic Commands

```bash
# List all configured tunnels
autossh-cli list

# View tunnel running status
autossh-cli status

# Show detailed information for a specific tunnel
autossh-cli show-tunnel <hash>

# Start a single tunnel
autossh-cli start-tunnel <hash>

# Stop a single tunnel
autossh-cli stop-tunnel <hash>
```

### Usage Examples

```bash
# 1. View available tunnel configurations
$ autossh-cli list
Configured Tunnels
  done-hub             NORMAL       0.0.0.0:33001 -> cloud.usa2:127.0.0.1:33000 (7b840f8344679dff5df893eefd245043)
  argo-proxy           INTERACTIVE  44498 -> lambda5:44497 (f55793c77944b6e0cd3a46889422487e)
  dockge@tempest       NORMAL       55001 -> oaklight.tempest:5001 (2ea730e749b28910932f2b141638ade8)

# 2. Stop a specific tunnel
$ autossh-cli stop-tunnel 7b840f8344679dff5df893eefd245043
INFO: Stopping tunnel: 7b840f8344679dff5df893eefd245043
[2026-01-25 12:03:14] [INFO] [STATE] Stopping tunnel: done-hub (7b840f8344679dff5df893eefd245043, PID: 186)

# 3. Start a specific tunnel
$ autossh-cli start-tunnel 7b840f8344679dff5df893eefd245043
INFO: Starting tunnel: 7b840f8344679dff5df893eefd245043
[2026-01-25 12:03:23] [INFO] [STATE] Starting tunnel: done-hub (7b840f8344679dff5df893eefd245043)
SUCCESS: Tunnel started successfully: 7b840f8344679dff5df893eefd245043

# 4. Check status
$ autossh-cli status
Tunnel Status
Managed tunnels:
  done-hub             RUNNING    0.0.0.0:33001 -> cloud.usa2:127.0.0.1:33000 (7b840f8344679dff5df893eefd245043)
  dockge@tempest       RUNNING    55001 -> oaklight.tempest:5001 (2ea730e749b28910932f2b141638ade8)
```

### Using in Docker Container

If your autossh is running in a Docker container:

```bash
# List tunnels
docker exec -it autotunnel-autossh-1 autossh-cli list

# Stop a tunnel
docker exec -it autotunnel-autossh-1 autossh-cli stop-tunnel <hash>

# Start a tunnel
docker exec -it autotunnel-autossh-1 autossh-cli start-tunnel <hash>

# View status
docker exec -it autotunnel-autossh-1 autossh-cli status
```

## HTTP API

### API Endpoints

| Method | Endpoint        | Description                        |
| ------ | --------------- | ---------------------------------- |
| GET    | `/list`         | Get list of all configured tunnels |
| GET    | `/status`       | Get running status of all tunnels  |
| POST   | `/start`        | Start all tunnels                  |
| POST   | `/stop`         | Stop all tunnels                   |
| POST   | `/start/<hash>` | Start a specific tunnel            |
| POST   | `/stop/<hash>`  | Stop a specific tunnel             |

### API Usage Examples

```bash
# Get tunnel list
curl -X GET http://localhost:8080/list

# Get tunnel status
curl -X GET http://localhost:8080/status

# Start a specific tunnel
curl -X POST http://localhost:8080/start/7b840f8344679dff5df893eefd245043

# Stop a specific tunnel
curl -X POST http://localhost:8080/stop/7b840f8344679dff5df893eefd245043

# Stop all tunnels
curl -X POST http://localhost:8080/stop

# Start all tunnels
curl -X POST http://localhost:8080/start
```

### API Response Format

#### Success Response

```json
{
  "status": "success",
  "tunnel_hash": "7b840f8344679dff5df893eefd245043",
  "output": "Tunnel started successfully"
}
```

#### Error Response

```json
{
  "error": "Tunnel hash required"
}
```

## Tunnel Hash

Each tunnel has a unique hash (MD5) used for identification and control. The hash is calculated based on:

- Tunnel name
- Remote host
- Remote port
- Local port
- Tunnel direction
- Interactive mode

You can view each tunnel's hash using the `autossh-cli list` command.

## State Management

### Tunnel States

- **RUNNING**: Tunnel is running
- **STOPPED**: Tunnel is stopped
- **STARTING**: Tunnel is starting
- **DEAD**: Tunnel process terminated abnormally

### State File

Tunnel state is saved in `/tmp/autossh_tunnels.state`, containing:

- Tunnel configuration information
- Process ID (PID)
- Running status

### Log Files

Each tunnel's logs are saved in separate files:

```
/tmp/autossh-logs/tunnel-<hash>.log
```

View logs for a specific tunnel:

```bash
# View all tunnel logs
autossh-cli logs

# View specific tunnel logs
autossh-cli logs <hash>
```

## Advanced Features

### Smart Restart

When the configuration file is updated, the system will:

1. Detect configuration changes
2. Stop deleted tunnels
3. Start new tunnels
4. Keep unchanged tunnels running

### Interactive Tunnels

Tunnels marked with `interactive: true` require manual password input and will not start automatically. These tunnels are displayed as `INTERACTIVE` status in the list.

### Batch Operations

```bash
# Start all non-interactive tunnels
autossh-cli start

# Use full restart mode (stop all tunnels then restart)
autossh-cli start --full

# Stop all tunnels
autossh-cli stop
```

## Troubleshooting

### Common Issues

#### 1. Tunnel Cannot Start

Check:

- SSH config file `~/.ssh/config` is correct
- SSH key permissions are correct (600)
- Remote host is accessible
- Port is not in use

#### 2. Tunnel Stops Automatically

Possible causes:

- Unstable network connection
- SSH server configuration issues
- Authentication failure

View logs for details:

```bash
autossh-cli logs <hash>
```

#### 3. Status Out of Sync

If status display is incorrect, clean up dead processes:

```bash
autossh-cli cleanup
```

### Debug Commands

```bash
# Validate configuration file
autossh-cli validate

# Show configuration paths
autossh-cli config

# Parse configuration file
autossh-cli parse

# View statistics
autossh-cli stats
```

## Configuration Example

### config.yaml

```yaml
tunnels:
  # Remote to local tunnel
  - name: "database"
    remote_host: "user@db-server"
    remote_port: "3306"
    local_port: "13306"
    direction: "remote_to_local"
    interactive: false

  # Local to remote tunnel
  - name: "web-service"
    remote_host: "user@gateway"
    remote_port: "8080"
    local_port: "3000"
    direction: "local_to_remote"
    interactive: false

  # Tunnel requiring interactive authentication
  - name: "secure-tunnel"
    remote_host: "admin@secure-host"
    remote_port: "22"
    local_port: "2222"
    direction: "remote_to_local"
    interactive: true
```

## Security Recommendations

1. **Use SSH Key Authentication**: Avoid password authentication
2. **Restrict Port Binding**: Use specific IP addresses instead of 0.0.0.0
3. **Regular Updates**: Keep SSH client and server updated
4. **Monitor Logs**: Regularly check tunnel logs for anomalies
5. **Principle of Least Privilege**: Only open necessary ports and services

## Related Links

- [Project Homepage](https://github.com/Oaklight/autossh-tunnel-dockerized)
- [Docker Hub](https://hub.docker.com/r/oaklight/autossh-tunnel)
- [SSH Configuration Guide](../ssh-config.md)