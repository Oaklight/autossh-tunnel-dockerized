# Getting Started

This guide will help you quickly set up and run SSH Tunnel Manager.

## Download Required Files

For most users, you only need to download the Docker Compose file. You can either:

### Option A: Download files directly

Create a new directory and download the required files:

```sh
mkdir autossh-tunnel
cd autossh-tunnel

# Download docker-compose.yaml (includes both autossh tunnel and web panel services)
curl -O https://oaklight.github.io/autossh-tunnel-dockerized/compose.yaml

# Create config directory
mkdir config

# Option 1: Download sample config (if you want to configure manually)
curl -o config/config.yaml.sample https://oaklight.github.io/autossh-tunnel-dockerized/config/config.yaml.sample
cp config/config.yaml.sample config/config.yaml

# Option 2: Create empty config (if you want to use web panel for configuration)
touch config/config.yaml
```

!!! note
    The `compose.yaml` file includes both the autossh tunnel service and the web panel service. The web panel is optional - you can disable it by commenting out the `web` service section in the compose file if you prefer manual configuration.

### Option B: Clone the repository (for developers)

If you want to modify the source code or build locally:

```sh
git clone https://github.com/Oaklight/autossh-tunnel-dockerized.git
cd autossh-tunnel-dockerized
```

## Configure SSH Keys

Ensure your SSH keys are located in the `~/.ssh` directory. This directory should contain your private key files (e.g., `id_ed25519`) and any necessary SSH configuration files.

!!! important
    This project heavily relies on the `~/.ssh/config` file for SSH connection configuration. The SSH config file allows you to define connection parameters such as hostnames, usernames, ports, and key files for each remote host. Without proper SSH config setup, the tunnels may fail to establish connections.

For detailed SSH config file setup instructions, please refer to: [SSH Configuration Guide](ssh-config.md)

## Configure YAML File

You have two options for configuring your SSH tunnels:

### Option A: Manual Configuration

Edit the `config.yaml` file to define your SSH tunnel mappings. Each entry should specify the remote host, remote port, local port, and direction (`local_to_remote` or `remote_to_local`).

Sample configuration:

```yaml
tunnels:
  # Expose local service to a remote server
  - remote_host: "user@remote-host1"
    remote_port: 22323
    local_port: 18120
    direction: local_to_remote
  # Map remote service to a local port
  - remote_host: "user@remote-host2"
    remote_port: 8000
    local_port: 8001
    direction: remote_to_local
  # Add more tunnels as needed
```

### Option B: Web Panel Configuration

If you're using the web panel (included in `compose.yaml`), you can:

- Start with an empty `config/config.yaml` file
- Access the web interface at `http://localhost:5000`
- Configure tunnels through the visual interface

!!! warning "Important Notes for Web Panel Users"
    - The web panel automatically backs up your configuration to `config/backups/` every time you save changes
    - You may need to manually delete old backup files to prevent disk space issues
    - The `config/config.yaml` file must exist (even if empty) for the autossh tunnel service to work properly

## Configure User Permissions (PUID/PGID)

!!! important
    Before running the containers, make sure to set the correct `PUID` and `PGID` values in your environment or `compose.yaml` file to match your host user's UID and GID. This ensures proper file permissions for the SSH keys and configuration files.

You can check your user's UID and GID with:

```sh
id
```

To set the values, you can either:

1. **Set environment variables**:

   ```sh
   export PUID=$(id -u)
   export PGID=$(id -g)
   ```

2. **Edit the compose.yaml file directly**:

   ```yaml
   environment:
     - PUID=1000
     - PGID=1000
   ```

## Build and Run the Docker Container

### Use Dockerhub Release Image

```sh
docker compose up -d
```

### Build and Run Container Locally

```sh
# build
docker compose -f compose.dev.yaml build
# run
docker compose -f compose.dev.yaml up -d
```

## Access Services

Once the container is running, you can:

- Access the local service via the specified port on the remote server (e.g., `remote-host1:22323`)
- Access the remote service through the local port (e.g., `localhost:8001`)
- Access the web panel at `http://localhost:5000`

## Next Steps

- [SSH Configuration](ssh-config.md) - Learn how to configure SSH for your tunnels
- [Web Panel](web-panel.md) - Learn how to use the web-based management interface
- [Tunnel Control API](api/index.md) - Learn about CLI and HTTP API for tunnel management