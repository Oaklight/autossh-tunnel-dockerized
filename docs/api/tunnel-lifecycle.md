# Tunnel Lifecycle Management

This document describes how SSH tunnels are managed throughout their lifecycle, including startup, shutdown, and state management.

## Tunnel States

Each tunnel can be in one of the following states:

| State | Description |
|-------|-------------|
| **RUNNING** | Tunnel is active and connected |
| **STOPPED** | Tunnel is not running |
| **STARTING** | Tunnel is in the process of starting |
| **DEAD** | Tunnel process terminated abnormally |
| **INTERACTIVE** | Tunnel requires manual password input |

## Lifecycle Phases

### 1. Container Startup

When the container starts:

- **Clean old state**: Remove `/tmp/autossh_tunnels.state` to ensure accuracy
- **Create infrastructure**:
  - Create state file (permission 666)
  - Create log directory `/tmp/autossh-logs` (permission 777)
  - Set correct ownership (myuser:mygroup)

### 2. Starting a Single Tunnel

```bash
autossh-cli start-tunnel <hash>
# or
curl -X POST http://localhost:8080/start/<hash>
```

Process:

1. Check if tunnel is already running
2. Start autossh process
3. **Write to state file**: Record PID and configuration
4. **Create log file**: `/tmp/autossh-logs/tunnel-<hash>.log`

### 3. Stopping a Single Tunnel

```bash
autossh-cli stop-tunnel <hash>
# or
curl -X POST http://localhost:8080/stop/<hash>
```

Process:

1. Stop process (SIGTERM first, then SIGKILL)
2. **Remove state entry**: Remove tunnel record from state file
3. **Delete log file**: Clean up corresponding log file

### 4. Stopping All Tunnels

```bash
autossh-cli stop
# or
curl -X POST http://localhost:8080/stop
```

Process:

1. Stop all tunnel processes
2. **Clear state file**: Remove all records
3. **Delete all logs**: Clean up entire log directory

## File Management

### State File

Location: `/tmp/autossh_tunnels.state`

Format:
```
remote_host<TAB>remote_port<TAB>local_port<TAB>direction<TAB>name<TAB>hash<TAB>pid
```

Example:
```
cloud.usa2	127.0.0.1:33000	0.0.0.0:33001	remote_to_local	done-hub	7b840f8344679dff5df893eefd245043	186
```

### Log Files

Location: `/tmp/autossh-logs/tunnel-<hash>.log`

Each tunnel has its own log file for isolated debugging.

### File Management Strategy

| Operation | State File | Log Files |
|-----------|------------|-----------|
| Container Start | Clear (recreate) | Keep directory structure |
| Start Tunnel | Add entry | Create new log |
| Stop Tunnel | Remove entry | Delete corresponding log |
| Stop Service | Clear entire file | Delete all logs |

## Permissions

| File/Directory | Permission |
|----------------|------------|
| State file | 666 (rw-rw-rw-) |
| Log directory | 777 (rwxrwxrwx) |
| Log files | Created by process owner |

## Smart Restart

When the configuration file is updated, the system will:

1. Detect configuration changes
2. Stop removed tunnels
3. Start new tunnels
4. Keep unchanged tunnels running

This ensures minimal disruption to existing connections.

## Interactive Tunnels

Tunnels marked as `interactive: true` in the configuration:

- Require manual password input
- Won't start automatically
- Show as `INTERACTIVE` status in the list
- Must be started manually after providing credentials

## Cleanup Rules

1. **Individual tunnel stop**: Clean only that tunnel's resources
2. **Service stop**: Clean all resources
3. **Container restart**: Start fresh with empty state
4. **Dead process cleanup**: Remove orphaned entries and logs

Use `autossh-cli cleanup` to manually clean up dead processes.

## Monitoring

### Check Tunnel Health

```bash
# View all tunnel status
autossh-cli status

# View specific tunnel logs
autossh-cli logs <hash>

# View statistics
autossh-cli stats
```

### Common Issues

#### Tunnel Keeps Restarting

Possible causes:

- Network instability
- SSH server configuration issues
- Authentication failures

Check logs for details:

```bash
autossh-cli logs <hash>
```

#### State Out of Sync

If status display is incorrect:

```bash
autossh-cli cleanup
```

This will remove orphaned entries and synchronize the state file with actual running processes.