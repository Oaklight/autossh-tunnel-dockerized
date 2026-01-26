# Getting Started

This guide will help you quickly set up and run SSH Tunnel Manager.

## Prerequisites

- Docker and Docker Compose installed on your local machine
- SSH keys set up for accessing remote hosts
- Basic knowledge of SSH and Docker

## Installation Steps

### 1. Download Required Files

For most users, you only need to download the Docker Compose file.

**Option A: Download files directly**

Create a new directory and download the required files:

```bash
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

!!! note "About compose.yaml"
    The `compose.yaml` file includes both the autossh tunnel service and the web panel service. The web panel is optional - you can disable it by commenting out the `web` service section in the compose file if you prefer manual configuration.

**Option B: Clone the repository (for developers)**

If you want to modify the source code or build locally:

```bash
git clone https://github.com/Oaklight/autossh-tunnel-dockerized.git
cd autossh-tunnel-dockerized
```

### 2. Configure SSH Keys

Ensure your SSH keys are located in the `~/.ssh` directory. This directory should contain:

- Private key files (e.g., `id_ed25519`, `id_rsa`)
- SSH configuration file (`config`)
- Known hosts file (`known_hosts`)

!!! warning "Important"
    This project heavily relies on the `~/.ssh/config` file for SSH connection configuration. The SSH config file allows you to define connection parameters such as hostnames, usernames, ports, and key files for each remote host. Without proper SSH config setup, the tunnels may fail to establish connections.

For detailed SSH config file setup instructions, please refer to: [SSH Configuration Guide](ssh-config.md)

### 3. Configure Tunnels

You have two options for configuring your SSH tunnels:

#### Option A: Manual Configuration

Edit the `config/config.yaml` file to define your SSH tunnel mappings.

**Basic Example:**

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
```

**Advanced Configuration: Specifying Bind Addresses**

If you want to bind the remote port or local service to a specific IP address, you can use the `ip:port` format:

```yaml
tunnels:
  # Specify remote bind address
  - remote_host: "user@remote-host1"
    remote_port: "192.168.45.130:22323"  # Bind to specific IP on remote
    local_port: 18120
    direction: local_to_remote
    
  # Specify local bind address
  - remote_host: "user@remote-host1"
    remote_port: 22323
    local_port: "192.168.1.100:18120"  # Bind to specific IP locally
    direction: local_to_remote
    
  # Specify both remote and local bind addresses
  - remote_host: "user@remote-host1"
    remote_port: "192.168.45.130:22323"
    local_port: "192.168.1.100:18120"
    direction: local_to_remote
```

#### Option B: Web Panel Configuration

If you're using the web panel (included in `compose.yaml`):

1. Start with an empty `config/config.yaml` file
2. Access the web interface at `http://localhost:5000` after starting the services
3. Configure tunnels through the visual interface

!!! tip "Web Panel Tips"
    - The web panel automatically backs up your configuration to `config/backups/` every time you save changes
    - You may need to manually delete old backup files to prevent disk space issues
    - The `config/config.yaml` file must exist (even if empty) for the autossh tunnel service to work properly

### 4. Configure User Permissions (PUID/PGID)

Before running the containers, make sure to set the correct `PUID` and `PGID` values to match your host user's UID and GID.

Check your user's UID and GID:

```bash
id
```

Setting methods:

**Method 1: Set environment variables**

```bash
export PUID=$(id -u)
export PGID=$(id -g)
```

**Method 2: Edit the compose.yaml file directly**

```yaml
environment:
  - PUID=1000
  - PGID=1000
```

### 5. Start Services

#### Using Docker Hub Image

```bash
docker compose up -d
```

#### Build and Run Locally

```bash
# Build
docker compose -f compose.dev.yaml build

# Run
docker compose -f compose.dev.yaml up -d
```

### 6. Verify Services

Check container status:

```bash
docker compose ps
```

View logs:

```bash
docker compose logs -f
```

Access the Web panel (if enabled):

```
http://localhost:5000
```

## Access Services

Once the containers are running:

- **Local to Remote tunnels**: Access local services via the specified port on the remote server (e.g., `remote-host1:22323`)
- **Remote to Local tunnels**: Access remote services through the local port (e.g., `localhost:8001`)

## Next Steps

- Learn about [Architecture](architecture.md) to understand how the system works
- Check the [Web Panel Guide](web-panel.md) to learn how to use the visual interface
- Read the [API Documentation](api/index.md) to learn how to control tunnels via CLI or HTTP API
- Having issues? Check the [Troubleshooting Guide](troubleshooting.md)