# SSH Tunnel Manager with Docker and Autossh

[中文版](README_zh.md) | [English](README_en.md)

This project provides a Docker-based solution to manage SSH tunnels using `autossh` and a YAML configuration file. This setup allows you to easily expose **local services to a remote server through an SSH tunnel** or **map remote services to a local port**, making it convenient to access services behind a firewall. Additionally, it detects changes in `config.yaml` and automatically reloads the service configuration.

![Web Panel Interface](https://github.com/user-attachments/assets/a9d7255e-77c1-4f3e-b63e-4a0e67ff4460)

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Releases](#releases)
- [Setup](#setup)
  - [1. Download Required Files](#1-download-required-files)
  - [2. Configure SSH Keys](#2-configure-ssh-keys)
  - [3. Configure YAML File](#3-configure-yaml-file)
  - [4. Configure User Permissions (PUID/PGID)](#4-configure-user-permissions-puidpgid)
  - [5. Build and Run the Docker Container](#5-build-and-run-the-docker-container)
  - [6. Access Services](#6-access-services)
- [SSH Config Configuration Guide](README_ssh_config_en.md)
- [Logging System](docs/en/logging.md)
- [Web-Based Configuration](#web-based-configuration)
- [Customization](#customization)
  - [Add More Tunnels](#add-more-tunnels)
  - [Modify Dockerfile](#modify-dockerfile)
  - [Modify Entrypoint Script](#modify-entrypoint-script)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)
  - [SSH Key Permissions](#ssh-key-permissions)
  - [Docker Permissions](#docker-permissions)
  - [Logs](#logs)
- [License](#license)
- [Acknowledgments](#acknowledgments)

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
- **Separate Logging System**: Creates separate log files for each tunnel connection with unique log IDs based on configuration content. See [Logging System Documentation](docs/en/logging.md).

## Prerequisites

- Docker and Docker Compose are installed on the local machine.
- SSH keys are set up for accessing the remote host.

## Releases

The packaged Docker images are available on Docker Hub. You can access them via the following link:

[Docker Hub Link](https://hub.docker.com/r/oaklight/autossh-tunnel)

Feel free to use it and provide feedback!

## Setup

### 1. Download Required Files

For most users, you only need to download the Docker Compose file. You can either:

**Option A: Download files directly**

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

# Create logs directory
mkdir logs
```

**Note**: The `compose.yaml` file includes both the autossh tunnel service and the web panel service. The web panel is optional - you can disable it by commenting out the `web` service section in the compose file if you prefer manual configuration.

**Option B: Clone the repository (for developers)**

If you want to modify the source code or build locally:

```sh
git clone https://github.com/Oaklight/autossh-tunnel-dockerized.git
cd autossh-tunnel-dockerized
```

### 2. Configure SSH Keys

Ensure your SSH keys are located in the `~/.ssh` directory. This directory should contain your private key files (e.g., `id_ed25519`) and any necessary SSH configuration files.

**Important**: This project heavily relies on the `~/.ssh/config` file for SSH connection configuration. The SSH config file allows you to define connection parameters such as hostnames, usernames, ports, and key files for each remote host. Without proper SSH config setup, the tunnels may fail to establish connections.

For detailed SSH config file setup instructions, please refer to: [SSH Config Configuration Guide](README_ssh_config_en.md)

### 3. Configure YAML File

You have two options for configuring your SSH tunnels:

#### Option A: Manual Configuration

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

#### Option B: Web Panel Configuration

If you're using the web panel (included in `compose.yaml`), you can:

- Start with an empty `config/config.yaml` file
- Access the web interface at `http://localhost:5000`
- Configure tunnels through the visual interface

**Important Notes for Web Panel Users:**

- The web panel automatically backs up your configuration to `config/backups/` every time you save changes
- You may need to manually delete old backup files to prevent disk space issues
- The `config/config.yaml` file must exist (even if empty) for the autossh tunnel service to work properly

#### Advanced Configuration: Specify Bind Addresses

If you want to bind **remote port** or **local service** to a specific IP address, use the `ip:port` format.

##### 1. **Specify Remote Bind Address**

Bind the remote port to a specific IP address (e.g., `192.168.45.130`):

```yaml
tunnels:
  - remote_host: "user@remote-host1"
    remote_port: "192.168.45.130:22323" # Bind remote to 192.168.45.130
    local_port: 18120 # Local service port
    direction: local_to_remote
```

##### 2. **Specify Local Bind Address**

Bind the local service to a specific IP address (e.g., `192.168.1.100`):

```yaml
tunnels:
  - remote_host: "user@remote-host1"
    remote_port: 22323 # Remote port
    local_port: "192.168.1.100:18120" # Bind local to 192.168.1.100
    direction: local_to_remote
```

##### 3. **Specify Both Remote and Local Bind Addresses**

```yaml
tunnels:
  - remote_host: "user@remote-host1"
    remote_port: "192.168.45.130:22323" # Bind remote to 192.168.45.130
    local_port: "192.168.1.100:18120" # Bind local to 192.168.1.100
    direction: local_to_remote
```

This allows you to flexibly control the IP addresses to which tunnels bind, meeting different network environments and security needs.

### 4. Configure User Permissions (PUID/PGID)

**Important**: Before running the containers, make sure to set the correct `PUID` and `PGID` values in your environment or `compose.yaml` file to match your host user's UID and GID. This ensures proper file permissions for the SSH keys and configuration files.

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

### 5. Build and Run the Docker Container

#### Use Dockerhub Release Image

```sh
docker compose up -d
```

#### Build and Run Container Locally

```sh
# build
docker compose -f compose.dev.yaml build
# run
docker compose -f compose.dev.yaml up -d
```

### 6. Access Services

Once the container is running, you can access the local service via the specified port on the remote server (e.g., `remote-host1:22323`) or access the remote service through the local port (e.g., `localhost:8001`).

## Web-Based Configuration

The project includes an optional **web-based configuration panel** for easier tunnel management. The web panel is included in the default `compose.yaml` file but can be disabled if not needed.

### Features

- Visual interface to view and edit the `config.yaml` file
- Automatic backup of configuration changes to `config/backups/`
- Real-time updates to tunneling configuration without container restart
- Can start with an empty configuration file

### Access

Once the containers are running, access the web panel at: `http://localhost:5000`

### Backup Management

The web panel automatically creates backups in `config/backups/` every time you save changes. You may need to manually clean up old backup files to prevent disk space issues.

---

## Customization

### Add More Tunnels

To add more SSH tunnels, simply add more entries to the `config.yaml` file. Each entry should follow this format:

```yaml
- remote_host: "user@remote-host"
  remote_port: <remote_port>
  local_port: <local_port>
  direction: <local_to_remote or remote_to_local> (default: remote_to_local)
```

### Modify Dockerfile

If you need to customize the Docker environment, you can modify the `Dockerfile`. For example, you can install additional packages or change the base image.

### Modify Entrypoint Script

The `entrypoint.sh` script is responsible for reading the `config.yaml` file and starting SSH tunnels. If you need to add extra functionality or change how tunnels are managed, you can modify this script.

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

```sh
chmod 700 .ssh
chmod 600 .ssh/*
```

### Docker Permissions

If you encounter permission issues when running Docker commands, make sure your user is in the `docker` group:

```sh
sudo usermod -aG docker $USER
```

### Logs

Check Docker container logs for any errors:

```sh
docker compose logs -f
```

View specific tunnel log files:

```bash
# List all tunnel logs
ls -lh ./logs/

# View specific log file
cat ./logs/tunnel_<log_id>.log

# Monitor logs in real-time
tail -f ./logs/tunnel_<log_id>.log
```

For more information about logging, please refer to the [Logging System Documentation](docs/en/logging.md).

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [autossh](http://www.harding.motd.ca/autossh/) for maintaining SSH connections.
- [yq](https://github.com/mikefarah/yq) for parsing YAML configuration files.
- [Docker](https://www.docker.com/) for containerization.

---

Contributions to the project are welcome via issues or pull requests. Happy tunneling!
