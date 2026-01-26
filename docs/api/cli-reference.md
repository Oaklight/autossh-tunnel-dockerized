# CLI Reference

The `autossh-cli` command-line tool provides comprehensive tunnel management capabilities.

!!! important "Docker Container Only"
    The `autossh-cli` tool is designed to run **inside the Docker container**. It is not a standalone package that can be installed on your host system. All CLI commands should be executed using `docker exec`.

## Using the CLI

All commands should be prefixed with `docker exec`:

```bash
docker exec -it <container_name> autossh-cli <command>
```

For example:
```bash
docker exec -it autotunnel-autossh-1 autossh-cli list
```

## Basic Commands

### List Tunnels

List all configured tunnels with their details:

```bash
autossh-cli list
```

**Example Output:**

```
Configured Tunnels
  done-hub             NORMAL       0.0.0.0:33001 -> cloud.usa2:127.0.0.1:33000 (7b840f8344679dff5df893eefd245043)
  argo-proxy           INTERACTIVE  44498 -> lambda5:44497 (f55793c77944b6e0cd3a46889422487e)
  dockge@tempest       NORMAL       55001 -> oaklight.tempest:5001 (2ea730e749b28910932f2b141638ade8)
```

### View Status

View the running status of all tunnels:

```bash
autossh-cli status
```

**Example Output:**

```
Tunnel Status
Managed tunnels:
  done-hub             RUNNING    0.0.0.0:33001 -> cloud.usa2:127.0.0.1:33000 (7b840f8344679dff5df893eefd245043)
  dockge@tempest       RUNNING    55001 -> oaklight.tempest:5001 (2ea730e749b28910932f2b141638ade8)
```

### Show Tunnel Details

Display detailed information for a specific tunnel:

```bash
autossh-cli show-tunnel <hash>
```

**Example:**

```bash
autossh-cli show-tunnel 7b840f8344679dff5df893eefd245043
```

## Tunnel Control Commands

### Start a Single Tunnel

Start a specific tunnel by its hash:

```bash
autossh-cli start-tunnel <hash>
```

**Example:**

```bash
$ autossh-cli start-tunnel 7b840f8344679dff5df893eefd245043
INFO: Starting tunnel: 7b840f8344679dff5df893eefd245043
[2026-01-25 12:03:23] [INFO] [STATE] Starting tunnel: done-hub (7b840f8344679dff5df893eefd245043)
SUCCESS: Tunnel started successfully: 7b840f8344679dff5df893eefd245043
```

### Stop a Single Tunnel

Stop a specific tunnel by its hash:

```bash
autossh-cli stop-tunnel <hash>
```

**Example:**

```bash
$ autossh-cli stop-tunnel 7b840f8344679dff5df893eefd245043
INFO: Stopping tunnel: 7b840f8344679dff5df893eefd245043
[2026-01-25 12:03:14] [INFO] [STATE] Stopping tunnel: done-hub (7b840f8344679dff5df893eefd245043, PID: 186)
```

### Start All Tunnels

Start all non-interactive tunnels:

```bash
autossh-cli start
```

Use the `--full` flag for a complete restart (stop all tunnels first, then start):

```bash
autossh-cli start --full
```

### Stop All Tunnels

Stop all running tunnels:

```bash
autossh-cli stop
```

## Utility Commands

### View Logs

View tunnel logs:

```bash
# View all tunnel logs
autossh-cli logs

# View specific tunnel logs
autossh-cli logs <hash>
```

### Validate Configuration

Validate the configuration file:

```bash
autossh-cli validate
```

### Show Configuration Paths

Display configuration file paths:

```bash
autossh-cli config
```

### Parse Configuration

Parse and display the configuration file:

```bash
autossh-cli parse
```

### View Statistics

Display tunnel statistics:

```bash
autossh-cli stats
```

### Cleanup Dead Processes

Clean up orphaned tunnel processes:

```bash
autossh-cli cleanup
```

## Command Examples

```bash
# List tunnels
docker exec -it autotunnel-autossh-1 autossh-cli list

# Stop a tunnel
docker exec -it autotunnel-autossh-1 autossh-cli stop-tunnel <hash>

# Start a tunnel
docker exec -it autotunnel-autossh-1 autossh-cli start-tunnel <hash>

# View status
docker exec -it autotunnel-autossh-1 autossh-cli status

# View logs
docker exec -it autotunnel-autossh-1 autossh-cli logs

# Validate configuration
docker exec -it autotunnel-autossh-1 autossh-cli validate
```

## Exit Codes

| Code | Description |
|------|-------------|
| 0    | Success |
| 1    | General error |
| 2    | Invalid arguments |
| 3    | Tunnel not found |
| 4    | Tunnel already running |
| 5    | Tunnel failed to start |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CONFIG_FILE` | Path to configuration file | `/config/config.yaml` |
| `STATE_FILE` | Path to state file | `/tmp/autossh_tunnels.state` |
| `LOG_DIR` | Directory for tunnel logs | `/tmp/autossh-logs` |