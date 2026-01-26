# Web-Based Configuration Panel

The SSH Tunnel Manager includes an optional **web-based configuration panel** for easier tunnel management. The web panel is included in the default `compose.yaml` file but can be disabled if not needed.

![Web Panel Interface](https://github.com/user-attachments/assets/bb26d0f5-14ee-4289-b809-e48381c05bc1)

## Features

- **Visual Interface**: View and edit the `config.yaml` file through a user-friendly web interface
- **Automatic Backup**: Configuration changes are automatically backed up to `config/backups/`
- **Real-time Updates**: Tunneling configuration updates without container restart
- **Empty Config Support**: Can start with an empty configuration file
- **Multi-language Support**: Interface available in multiple languages
- **Individual Tunnel Control**: Start, stop, and restart individual tunnels directly from the interface

## Access

Once the containers are running, access the web panel at:

```
http://localhost:5000
```

## Interface Overview

### Main Dashboard

The main dashboard displays:

- **Tunnel List**: All configured tunnels with their current status
- **Status Indicators**: Visual indicators showing whether each tunnel is running, stopped, or has errors
- **Quick Actions**: Buttons to start, stop, or restart individual tunnels
- **Configuration Editor**: Add, edit, or remove tunnel configurations

### Tunnel Configuration

Each tunnel entry shows:

| Field | Description |
|-------|-------------|
| Name | Optional friendly name for the tunnel |
| Remote Host | SSH host reference (from `~/.ssh/config`) |
| Remote Port | Port on the remote server |
| Local Port | Port on the local machine |
| Direction | `local_to_remote` or `remote_to_local` |
| Status | Current running status |

### Adding a New Tunnel

1. Click the **Add** button
2. Fill in the tunnel configuration:
   - **Name**: Optional descriptive name
   - **Remote Host**: SSH host alias from your SSH config
   - **Remote Port**: Target port on remote server
   - **Local Port**: Local port to bind
   - **Direction**: Choose tunnel direction
3. Click **Save & Restart** to apply changes

### Editing Tunnels

1. Modify any field directly in the table
2. Click **Save & Restart** to apply changes

### Deleting Tunnels

1. Click the delete button (trash icon) next to the tunnel
2. Confirm the deletion
3. Click **Save & Restart** to apply changes

## Individual Tunnel Control

Each tunnel has dedicated control buttons:

- **Start** (▶): Start a stopped tunnel
- **Stop** (■): Stop a running tunnel
- **Restart** (↻): Restart a tunnel

These controls allow you to manage individual tunnels without affecting others.

## Backup Management

The web panel automatically creates backups in `config/backups/` every time you save changes.

!!! warning "Disk Space"
    You may need to manually clean up old backup files to prevent disk space issues. Backups are named with timestamps for easy identification.

### Backup Location

```
config/
├── config.yaml          # Current configuration
└── backups/
    ├── config.yaml.2024-01-15_10-30-00
    ├── config.yaml.2024-01-15_11-45-00
    └── ...
```

## Language Settings

The web panel supports multiple languages:

- English
- 简体中文 (Simplified Chinese)
- 繁體中文 (Traditional Chinese)
- 日本語 (Japanese)
- 한국어 (Korean)
- Español (Spanish)
- Français (French)
- Русский (Russian)
- العربية (Arabic)

Click the language toggle button (🌐) in the top-right corner to switch languages.

## Disabling the Web Panel

If you prefer manual configuration and don't need the web panel, you can disable it by commenting out the `web` service section in `compose.yaml`:

```yaml
services:
  autossh:
    # ... autossh configuration ...

  # Comment out or remove the web service
  # web:
  #   image: oaklight/autossh-tunnel-web:latest
  #   ports:
  #     - "5000:5000"
  #   volumes:
  #     - ./config:/config
  #   depends_on:
  #     - autossh
```

## Troubleshooting

### Web Panel Not Accessible

1. Check if the container is running:
   ```bash
   docker compose ps
   ```

2. Check container logs:
   ```bash
   docker compose logs web
   ```

3. Verify port 5000 is not in use by another application

### Changes Not Taking Effect

1. Ensure you clicked **Save & Restart** after making changes
2. Check the autossh container logs for errors:
   ```bash
   docker compose logs autossh
   ```

### Tunnel Status Not Updating

1. Refresh the page
2. Check if the API server is running:
   ```bash
   docker exec -it <container_name> autossh-cli status