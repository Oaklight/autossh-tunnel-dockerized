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

## Hash Prefix Support

!!! tip "Short Hash Prefix"
    All commands that accept a tunnel hash also support **short hash prefixes** (minimum 8 characters), similar to Git short commits. This makes it easier to specify tunnels without typing the full 32-character hash.

**Examples:**

```bash
# Using 8-character prefix instead of full hash
autossh-cli logs 7b840f83
autossh-cli start-tunnel 99acb12f
autossh-cli stop-tunnel fc3cce10
autossh-cli show-tunnel 2ea730e7

# Full hash still works
autossh-cli logs 7b840f8344679dff5df893eefd245043
```

**Error Handling:**

- **Prefix too short**: If you provide fewer than 8 characters, you'll get an error message
- **No match**: If no tunnel matches the prefix, an error is displayed with available log files
- **Ambiguous match**: If multiple tunnels match the prefix, all matching hashes are listed and you're asked to use more characters

## Tunnel Control Commands

### Interactive Authentication

Start an interactive tunnel that requires manual authentication (2FA/Password):

```bash
autossh-cli auth <hash>
```

!!! important "User Context Required"
    The `auth` command must be run as the `myuser` user to properly access SSH configuration files. Use the `-u myuser` flag with `docker exec`:
    
    ```bash
    docker exec -it -u myuser <container_name> autossh-cli auth <hash>
    ```

**Example:**

```bash
# Start interactive authentication for a tunnel
$ docker exec -it -u myuser autotunnel-autossh-1 autossh-cli auth c5ed76f1

Interactive Authentication
[2026-02-03 16:44:21] [INFO] [INTERACTIVE] Initializing interactive tunnel: test-2fa-tunnel (c5ed76f1dfccb8959815fbfdc69d582d)

[2026-02-03 16:44:21] [INFO] [INTERACTIVE] Starting SSH session for: test-2fa-tunnel
[2026-02-03 16:44:21] [INFO] [INTERACTIVE] You may be prompted for password or 2FA.
[2026-02-03 16:44:21] [INFO] [INTERACTIVE] The session will go to background upon successful authentication.

[2026-02-03 16:44:21] [INFO] [INTERACTIVE] Direction: remote_to_local (Local Forwarding)
[2026-02-03 16:44:21] [INFO] [INTERACTIVE] Forwarding: localhost:18888 <- test-2fa-server:localhost:8888
(testuser@localhost) Verification code: ******

[2026-02-03 16:44:29] [INFO] [INTERACTIVE] Authentication successful. Tunnel running in background.
[2026-02-03 16:44:30] [INFO] [INTERACTIVE] Tunnel PID: 55085
[2026-02-03 16:44:30] [INFO] [INTERACTIVE] Tunnel registered in state file.

[2026-02-03 16:44:30] [INFO] [INTERACTIVE] Tunnel 'test-2fa-tunnel' is now running.
[2026-02-03 16:44:30] [INFO] [INTERACTIVE] Use 'autossh-cli status' to check tunnel status.
[2026-02-03 16:44:30] [INFO] [INTERACTIVE] Use 'autossh-cli stop-tunnel c5ed76f1dfccb8959815fbfdc69d582d' to stop.
SUCCESS: Interactive tunnel started successfully
```

**Key Features:**

- Uses plain SSH instead of autossh to avoid automatic reconnection attempts
- Supports keyboard-interactive authentication (2FA, password prompts)
- Tunnel runs in background after successful authentication
- Uses SSH control sockets for PID tracking and management

!!! note "Interactive Tunnels"
    Interactive tunnels are marked with `interactive: true` in the configuration file. They are **not** started automatically when the container starts. You must manually authenticate using the `auth` command.

### Start a Single Tunnel

Start a specific tunnel by its hash (or 8+ character prefix):

```bash
autossh-cli start-tunnel <hash>
```

**Example:**

```bash
# Using full hash
$ autossh-cli start-tunnel 7b840f8344679dff5df893eefd245043
INFO: Starting tunnel: 7b840f8344679dff5df893eefd245043
[2026-01-25 12:03:23] [INFO] [STATE] Starting tunnel: done-hub (7b840f8344679dff5df893eefd245043)
SUCCESS: Tunnel started successfully: 7b840f8344679dff5df893eefd245043

# Using 8-character prefix
$ autossh-cli start-tunnel 7b840f83
INFO: Starting tunnel: 7b840f83
[2026-01-25 12:03:23] [INFO] [STATE] Starting tunnel: done-hub (7b840f8344679dff5df893eefd245043)
SUCCESS: Tunnel started successfully: 7b840f83
```

### Stop a Single Tunnel

Stop a specific tunnel by its hash (or 8+ character prefix):

```bash
autossh-cli stop-tunnel <hash>
```

**Example:**

```bash
# Using 8-character prefix
$ autossh-cli stop-tunnel 7b840f83
INFO: Stopping tunnel: 7b840f83
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

# View specific tunnel logs (supports 8+ char prefix)
autossh-cli logs <hash>

# Example with prefix
autossh-cli logs 7b840f83
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
| 1    | Error (general error, invalid arguments, tunnel not found, etc.) |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AUTOSSH_CONFIG_FILE` | Path to configuration file | `/etc/autossh/config/config.yaml` |
| `SSH_CONFIG_DIR` | SSH config directory | `/home/myuser/.ssh` |
| `AUTOSSH_STATE_FILE` | Path to state file | `/tmp/autossh_tunnels.state` |
| `API_ENABLE` | Enable HTTP API server | `false` |
| `API_PORT` | HTTP API server port | `8080` |
| `PUID` | User ID for file permissions | `1000` |
| `PGID` | Group ID for file permissions | `1000` |
| `AUTOSSH_GATETIME` | Autossh gate time | `0` |