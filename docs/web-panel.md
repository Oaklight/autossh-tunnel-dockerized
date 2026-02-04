# Web Panel User Guide

The web panel provides a visual interface for managing SSH tunnel configurations without manually editing YAML files.

![Web Panel Interface](assets/images/web-panel.png)

## Features

- **Visual Configuration Editing**: View and edit tunnel configurations through a user-friendly interface
- **Automatic Backup**: Configuration changes are automatically backed up to `config/backups/` on the autossh container
- **Real-time Updates**: Configuration changes automatically reload tunnels without container restart
- **Multi-language Support**: Supports Chinese, English, and other languages
- **Tunnel Status Monitoring**: Real-time view of each tunnel's running status
- **Individual Tunnel Control**: Start and stop each tunnel independently
- **Direct API Architecture**: Browser makes API calls directly to the autossh Config API for all operations
- **No Config Volume Required**: Web panel no longer needs access to config files - all operations go through the API

## Accessing the Web Panel

After starting the services, access in your browser:

```
http://localhost:5000
```

If you modified the web panel port, use the corresponding port number.

## Interface Overview

### Main Page

The main page displays a list of all configured tunnels in an editable table format:

| Column | Description |
|--------|-------------|
| **Controls** | Per-row action buttons: Save & Restart, Start, Restart, Stop |
| **Name** | Editable tunnel name field |
| **Status** | Status indicator icon (click to open tunnel detail page) |
| **Remote Host** | Editable remote host field |
| **Remote Port** | Editable remote port field |
| **Local Port** | Editable local port field |
| **Direction** | Dropdown to select tunnel direction |
| **Actions** | Interactive Auth toggle and Delete button |

**Status Indicators:**

- 🟢 Green check: Running
- 🔴 Red X: Dead/Error
- 🟠 Orange hourglass: Starting/Loading
- ⚪ Grey stop: Stopped

### Adding a Tunnel

1. Click the "Add" button at the bottom of the page
2. A new empty row will appear in the table
3. Fill in the tunnel configuration directly in the table:
   - **Name**: Custom name for the tunnel
   - **Remote Host**: SSH host configuration name (e.g., `user@remote-host`)
   - **Remote Port**: Port on the remote server (supports `port` or `hostname:port` format)
   - **Local Port**: Port on the local machine (supports `port` or `ip:port` format)
   - **Direction**: Choose `Remote to Local` or `Local to Remote`
4. Click the row's "Save" button (💾) or the global "Save & Restart" button

### Editing Tunnels

Tunnels can be edited directly in the table:

1. Find the tunnel to edit in the tunnel list
2. Modify the configuration fields directly in the table row
3. Click the row's "Save" button (💾) to save and restart only that tunnel
4. Or click the global "Save & Restart" button to save all changes and restart all tunnels

!!! tip "Per-Row Save"
    The per-row save button (💾) allows you to save and restart individual tunnels without affecting other tunnels. This is useful when you only need to modify one tunnel.

### Deleting Tunnels

1. Find the tunnel to delete in the tunnel list
2. Click the "Delete" button
3. Confirm the deletion

### Starting/Stopping Tunnels

Each tunnel row has control buttons:

- **Start** (▶️): Start the tunnel
- **Restart** (🔄): Stop and restart the tunnel
- **Stop** (⏹️): Stop the tunnel

!!! note "Interactive Authentication"
    Click the fingerprint icon (🫆) to toggle interactive authentication mode. When enabled (green), the tunnel requires manual authentication via command line.
    
    **Important**: Tunnels with interactive authentication enabled **cannot be started from the web interface**. You must use the CLI command:
    
    ```bash
    docker compose exec -it -u myuser autossh autossh-cli auth <hash>
    ```
    
    See [CLI Reference - Interactive Authentication](api/cli-reference.md#interactive-authentication) for details.

### Tunnel Detail Page

Click on the status indicator icon in any row to open the tunnel's detail page. The detail page provides:

- **Full Configuration View**: See all tunnel settings
- **Real-time Logs**: View tunnel logs with auto-refresh
- **Control Buttons**: Start, Restart, Stop the tunnel
- **Configuration Editing**: Modify tunnel settings directly
- **Auto-refresh**: Status and logs update automatically every 5 seconds

## Configuration Backup

The web panel automatically creates configuration backups every time you save changes:

- **Backup Location**: `config/backups/`
- **Backup Format**: `config.yaml.backup.YYYYMMDD_HHMMSS`
- **Backup Management**: Manual cleanup of old backups is needed to prevent disk space issues

### Restoring Backups

If you need to restore a previous configuration:

```bash
# View available backups
ls -la config/backups/

# Restore a specific backup
cp config/backups/config.yaml.backup.20240115_143022 config/config.yaml

# Restart the service to apply the restored configuration
docker compose restart autossh
```

## Advanced Configuration

### Specifying Bind Addresses

In the web panel, you can use the `ip:port` format to specify bind addresses:

**Bind remote port to specific IP:**
```
Remote Port: 192.168.45.130:22323
```

**Bind local port to specific IP:**
```
Local Port: 192.168.1.100:18120
```

### Using SSH Config Aliases

In the "Remote Host" field, you can use host aliases defined in `~/.ssh/config`:

```
Remote Host: myserver
```

This will use the configuration for `myserver` from the SSH config file.

## Troubleshooting

### Web Panel Not Accessible

1. Check if the container is running:
   ```bash
   docker compose ps
   ```

2. Check if the port is in use:
   ```bash
   netstat -tuln | grep 5000
   ```

3. View web panel logs:
   ```bash
   docker compose logs web
   ```

### Configuration Not Updating After Save

1. Check autossh container logs:
   ```bash
   docker compose logs autossh
   ```

2. Verify configuration file format:
   ```bash
   cat config/config.yaml
   ```

3. Manually restart autossh service:
   ```bash
   docker compose restart autossh
   ```

### Backup Directory Using Too Much Space

Periodically clean up old backups:

```bash
# Delete backups older than 7 days
find config/backups/ -name "*.backup.*" -mtime +7 -delete

# Or keep only the 10 most recent backups
cd config/backups/
ls -t | tail -n +11 | xargs rm -f
```

## Architecture

The web panel uses a **direct API architecture**:

1. **Static File Server**: The Go web server (port 5000) serves HTML, CSS, and JavaScript files
2. **Direct API Calls**: The browser makes API calls directly to the autossh API server (port 8080) for all operations:
   - **Config API**: Get, create, update, and delete tunnel configurations
   - **Control API**: Start, stop, and restart tunnels
   - **Status API**: Get tunnel status and logs

This architecture provides:

- **Better Performance**: No proxy overhead for API calls
- **Simplified Networking**: Web container doesn't require host network mode or config volume
- **Clear Separation**: Web panel is purely a static server, all logic is in the autossh container
- **Single Source of Truth**: Configuration is managed only by the autossh container

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Browser       │────▶│   Web Container │     │ autossh Container│
│   (Frontend)    │     │   (Static Only) │     │   (Config API)   │
└────────┬────────┘     └─────────────────┘     └────────▲────────┘
         │                                               │
         │  /config, /status, /start, /stop, /logs       │
         └───────────────────────────────────────────────┘
```

!!! info "Network Requirements"
    Since the browser makes direct API calls to port 8080, ensure the API server is accessible from the user's browser. When running locally, this is typically `http://localhost:8080`.

!!! tip "No Config Volume Needed"
    The web container no longer requires a config volume mount. All configuration operations are performed through the Config API on the autossh container.

## Security Recommendations

1. **Restrict Access**: By default, the web panel only listens on localhost. If remote access is needed, use SSH tunneling or VPN.

2. **Use Firewall**: Ensure the web panel port (default 5000) and API port (default 8080) are not exposed to the public internet.

3. **Enable API Authentication**: Set `API_KEY` environment variable on the autossh container to require authentication for API calls.

4. **Regular Backups**: Although the web panel backs up automatically, it's recommended to manually backup important configurations regularly.

5. **Review Changes**: Carefully check before saving configurations to avoid accidentally disrupting existing tunnels.

## Next Steps

- Learn about [CLI Commands](api/cli-reference.md) for command-line management
- Check the [HTTP API](api/http-api.md) for programmatic control
- Read the [Architecture](architecture.md) to understand how the system works