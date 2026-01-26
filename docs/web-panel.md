# Web Panel User Guide

The web panel provides a visual interface for managing SSH tunnel configurations without manually editing YAML files.

![Web Panel Interface](assets/images/web-panel.png)

## Features

- **Visual Configuration Editing**: View and edit the `config.yaml` file through a user-friendly interface
- **Automatic Backup**: Configuration changes are automatically backed up to `config/backups/`
- **Real-time Updates**: Configuration changes automatically reload tunnels without container restart
- **Multi-language Support**: Supports Chinese, English, and other languages
- **Tunnel Status Monitoring**: Real-time view of each tunnel's running status
- **Individual Tunnel Control**: Start and stop each tunnel independently

## Accessing the Web Panel

After starting the services, access in your browser:

```
http://localhost:5000
```

If you modified the web panel port, use the corresponding port number.

## Interface Overview

### Main Page

The main page displays a list of all configured tunnels, including:

- **Tunnel Name**: Custom tunnel identifier
- **Remote Host**: Target host for SSH connection
- **Port Mapping**: Mapping between local and remote ports
- **Direction**: Tunnel direction (local to remote / remote to local)
- **Status**: Running / Stopped
- **Action Buttons**: Start, Stop, Edit, Delete

### Adding a Tunnel

1. Click the "Add Tunnel" button
2. Fill in the tunnel configuration:
   - **Name**: Custom name for the tunnel (optional)
   - **Remote Host**: SSH host configuration name (e.g., `user@remote-host`)
   - **Remote Port**: Port on the remote server
   - **Local Port**: Port on the local machine
   - **Direction**: Choose `local_to_remote` or `remote_to_local`
   - **Interactive Mode**: Whether interactive SSH session is needed (usually select false)
3. Click "Save"

### Editing Tunnels

1. Find the tunnel to edit in the tunnel list
2. Click the "Edit" button
3. Modify the configuration
4. Click "Save"

### Deleting Tunnels

1. Find the tunnel to delete in the tunnel list
2. Click the "Delete" button
3. Confirm the deletion

### Starting/Stopping Tunnels

- **Start Single Tunnel**: Click the "Start" button next to the tunnel
- **Stop Single Tunnel**: Click the "Stop" button next to the tunnel
- **Start All Tunnels**: Click the "Start All" button at the top of the page
- **Stop All Tunnels**: Click the "Stop All" button at the top of the page

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

## Security Recommendations

1. **Restrict Access**: By default, the web panel only listens on localhost. If remote access is needed, use SSH tunneling or VPN.

2. **Use Firewall**: Ensure the web panel port (default 5000) is not exposed to the public internet.

3. **Regular Backups**: Although the web panel backs up automatically, it's recommended to manually backup important configurations regularly.

4. **Review Changes**: Carefully check before saving configurations to avoid accidentally disrupting existing tunnels.

## Next Steps

- Learn about [CLI Commands](api/cli-reference.md) for command-line management
- Check the [HTTP API](api/http-api.md) for programmatic control
- Read the [Architecture](architecture.md) to understand how the system works