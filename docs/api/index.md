# Tunnel Control API

The SSH Tunnel Manager provides both CLI and HTTP API interfaces for advanced tunnel management. This allows you to independently start, stop, and manage individual SSH tunnels without affecting other running tunnels.

## Features

- **Independent Control**: Start or stop any tunnel individually
- **Smart Detection**: Automatically checks if a tunnel is already running before starting
- **State Management**: Real-time tracking of each tunnel's running status
- **Multiple Interfaces**: Supports both CLI commands and HTTP API
- **Isolated Logging**: Each tunnel has its own log file

## Quick Reference

### CLI Commands

```bash
# List all configured tunnels
autossh-cli list

# View tunnel running status
autossh-cli status

# Start a specific tunnel
autossh-cli start-tunnel <hash>

# Stop a specific tunnel
autossh-cli stop-tunnel <hash>

# Start all tunnels
autossh-cli start

# Stop all tunnels
autossh-cli stop
```

### HTTP API Endpoints

| Method | Endpoint        | Description                        |
| ------ | --------------- | ---------------------------------- |
| GET    | `/list`         | Get list of all configured tunnels |
| GET    | `/status`       | Get running status of all tunnels  |
| POST   | `/start`        | Start all tunnels                  |
| POST   | `/stop`         | Stop all tunnels                   |
| POST   | `/start/<hash>` | Start a specific tunnel            |
| POST   | `/stop/<hash>`  | Stop a specific tunnel             |

## Tunnel Hash

Each tunnel has a unique hash (MD5) used for identification and control. The hash is calculated based on:

- Tunnel name
- Remote host
- Remote port
- Local port
- Tunnel direction
- Interactive mode

You can view each tunnel's hash using the `autossh-cli list` command.

## Documentation

- [CLI Reference](cli-reference.md) - Detailed CLI command documentation
- [HTTP API](http-api.md) - HTTP API endpoint documentation
- [Tunnel Lifecycle](tunnel-lifecycle.md) - Understanding tunnel state management

## Using in Docker Container

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