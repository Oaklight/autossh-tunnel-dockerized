# SSH Tunnel Manager with Docker and Autossh

[![GitHub version](https://badge.fury.io/gh/oaklight%2Fautossh-tunnel-dockerized.svg?icon=si%3Agithub)](https://badge.fury.io/gh/oaklight%2Fautossh-tunnel-dockerized)
[![Docker Hub - autossh-tunnel](https://img.shields.io/docker/v/oaklight/autossh-tunnel?sort=semver&label=autossh-tunnel&logo=docker)](https://hub.docker.com/r/oaklight/autossh-tunnel)
[![Docker Hub - autossh-tunnel-web-panel](https://img.shields.io/docker/v/oaklight/autossh-tunnel-web-panel?sort=semver&label=autossh-tunnel-web-panel&logo=docker)](https://hub.docker.com/r/oaklight/autossh-tunnel-web-panel)

[中文版](README_zh.md) | [English](README_en.md)

![Web Panel Interface](https://github.com/user-attachments/assets/bb26d0f5-14ee-4289-b809-e48381c05bc1)

This project provides a Docker-based solution to manage SSH tunnels using `autossh` and a YAML configuration file. This setup allows you to easily expose **local services to a remote server through an SSH tunnel** or **map remote services to a local port**, making it convenient to access services behind a firewall.

## Features

- **Dockerized**: Environment encapsulated with Docker, making it easy to deploy and manage.
- **Non-root User**: Run container as a non-root user to enhance security.
- **YAML Configuration**: Define multiple SSH tunnel mappings using the `config.yaml` file and support automatic service reload upon configuration changes.
- **Autossh**: Automatically maintain SSH connection to ensure tunnels remain active.
- **Dynamic UID/GID Support**: Set container user's UID and GID dynamically using `PUID` and `PGID` environment variables to match host user permissions.
- **Multi-architecture Support**: Supports all Alpine base architectures, including `linux/amd64`, `linux/arm64/v8`, `linux/arm/v7`, `linux/arm/v6`, `linux/386`, `linux/ppc64le`, `linux/s390x`, and `linux/riscv64`.
- **Flexible Direction Configuration**: Support exposing local services to a remote server (`local_to_remote`) or mapping remote services to a local port (`remote_to_local`).
- **Automatic Reload**: Detect changes in `config.yaml` and automatically reload the service configuration.
- **Web-Based Configuration**: Manage tunnels and configuration updates via a web panel.
- **CLI Tool (autossh-cli)**: Command-line interface for managing tunnels, viewing status, and controlling individual tunnels.
- **HTTP API**: RESTful API for programmatic tunnel control, enabling integration with other tools and automation.
- **Individual Tunnel Control**: Start, stop, and manage each tunnel independently without affecting others.

## Prerequisites

- Docker and Docker Compose are installed on the local machine.
- SSH keys are set up for accessing the remote host.

## Quick Links

- [Full Documentation (English)](https://oaklight.github.io/autossh-tunnel-dockerized/en/)
- [Full Documentation (中文)](https://oaklight.github.io/autossh-tunnel-dockerized/zh/)

## Releases

The packaged Docker images are available on Docker Hub:

[Docker Hub Link](https://hub.docker.com/r/oaklight/autossh-tunnel)

Feel free to use it and provide feedback!

## Quick Start

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

> **Note**: The `compose.yaml` file includes both the autossh tunnel service and the web panel service. The web panel is optional - you can disable it by commenting out the `web` service section in the compose file if you prefer manual configuration.

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

> **Important**: This project heavily relies on the `~/.ssh/config` file for SSH connection configuration. The SSH config file allows you to define connection parameters such as hostnames, usernames, ports, and key files for each remote host. Without proper SSH config setup, the tunnels may fail to establish connections.

For detailed SSH config file setup instructions, please refer to: [SSH Configuration Guide](README_ssh_config_en.md)

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

> **Tips**:
> - The web panel automatically backs up your configuration to `config/backups/` every time you save changes
> - You may need to manually delete old backup files to prevent disk space issues
> - The `config/config.yaml` file must exist (even if empty) for the autossh tunnel service to work properly

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

## Tunnel Control API

The project provides both CLI and HTTP API interfaces for advanced tunnel management.

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

For detailed API documentation, see: [Tunnel Control API Documentation](doc/tunnel-control-api_en.md)

## Security Considerations

When enabling the `-R` parameter, remote ports are by default bound to `localhost`. If you want to access the tunnel via other IP addresses on the remote server, you need to enable the `GatewayPorts` option in the remote server's `sshd_config`:

```bash
# Edit /etc/ssh/sshd_config
GatewayPorts clientspecified  # Allow clients to specify binding address
GatewayPorts yes              # Or bind to all network interfaces
```

Restart the SSH service:

```bash
sudo systemctl restart sshd
```

Enabling `GatewayPorts` may expose services to the public. Ensure to take appropriate security measures, such as configuring firewall or enabling access control.

## Troubleshooting

### SSH Key Permissions

Ensure the `.ssh` directory and its contents have the appropriate permissions:

```bash
chmod 700 .ssh
chmod 600 .ssh/*
```

### Docker Permissions

If you encounter permission issues when running Docker commands, make sure your user is in the `docker` group:

```bash
sudo usermod -aG docker $USER
```

### Logs

Check Docker container logs for any errors:

```bash
docker compose logs -f
```

For more troubleshooting tips, see the [full documentation](https://oaklight.github.io/autossh-tunnel-dockerized/en/).

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [autossh](http://www.harding.motd.ca/autossh/) for maintaining SSH connections.
- [Docker](https://www.docker.com/) for containerization.
- [Alpine Linux](https://alpinelinux.org/) for the lightweight base image.
- [Go](https://golang.org/) for the web panel backend.
- [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) for the documentation theme.

---

Contributions to the project are welcome via issues or pull requests. Happy tunneling!