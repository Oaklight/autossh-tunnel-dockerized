# SSH Tunnel Manager with Docker and Autossh

[中文版](README.md) | [English](README_en.md)

This project provides a Docker-based solution to manage SSH tunnels using `autossh` and a YAML configuration file. This setup allows you to easily expose **local services to a remote server through an SSH tunnel** or **map remote services to a local port**, making it convenient to access services behind a firewall.

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Releases](#releases)
- [Setup](#setup)
  - [1. Clone the Repository](#1-clone-the-repository)
  - [2. Configure SSH Keys](#2-configure-ssh-keys)
  - [3. Configure YAML File](#3-configure-yaml-file)
  - [4. Build and Run the Docker Container](#4-build-and-run-the-docker-container)
  - [5. Access Services](#5-access-services)
- [Customization](#customization)
  - [Add More Tunnels](#add-more-tunnels)
  - [Modify Dockerfile](#modify-dockerfile)
  - [Modify Entrypoint Script](#modify-entrypoint-script)
- [Dynamic UID/GID Support](#dynamic-uidgid-support)
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
- **YAML Configuration**: Define multiple SSH tunnel mappings using the `config.yaml` file.
- **Autossh**: Automatically maintain SSH connection to ensure tunnels remain active.
- **Dynamic UID/GID Support**: Set container user's UID and GID dynamically using `PUID` and `PGID` environment variables to match host user permissions.
- **Multi-architecture Support**: Supports all Alpine base architectures, including `linux/amd64`, `linux/arm64/v8`, `linux/arm/v7`, `linux/arm/v6`, `linux/386`, `linux/ppc64le`, `linux/s390x`, and `linux/riscv64`.
- **Flexible Direction Configuration**: Support exposing local services to a remote server (`local_to_remote`) or mapping remote services to a local port (`remote_to_local`).

## Prerequisites

- Docker and Docker Compose are installed on the local machine.
- SSH keys are set up for accessing the remote host.

## Releases

The packaged Docker images are available on Docker Hub. You can access them via the following link:

[Docker Hub Link](https://hub.docker.com/r/oaklight/autossh-tunnel)

Feel free to use it and provide feedback!

## Setup

### 1. Clone the Repository

Clone this repository to your local machine:

```sh
git clone https://github.com/Oaklight/autossh-tunnel-dockerized.git
cd autossh-tunnel-dockerized
```

### 2. Configure SSH Keys

Ensure your SSH keys are located in the `~/.ssh` directory. This directory should contain your private key files (e.g., `id_ed25519`) and any necessary SSH configuration files.

### 3. Configure YAML File

Edit the `config.yaml` file to define your SSH tunnel mappings. Each entry should specify the remote host, remote port, local port, and direction (`local_to_remote` or `remote_to_local`).

Sample `config.yaml.sample` (copy it to `config.yaml` and make necessary changes):

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

### 4. Build and Run the Docker Container

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

### 5. Access Services

Once the container is running, you can access the local service via the specified port on the remote server (e.g., `remote-host1:22323`) or access the remote service through the local port (e.g., `localhost:8001`).

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

## Dynamic UID/GID Support

To ensure that the permissions of the user inside the container match the host user permissions, you can dynamically set the UID and GID of the container user using the `PUID` and `PGID` environment variables in the `compose.yaml` file. For example:

```yaml
services:
  autossh:
    image: oaklight/autossh-tunnel:latest
    volumes:
      - ~/.ssh:/home/myuser/.ssh:ro
      - ./config:/etc/autossh/config:ro
    environment:
      - PUID=1000
      - PGID=1000
      - AUTOSSH_GATETIME=0
    network_mode: "host"
    restart: always
```

Or use the `docker run` command with environment variables:

```bash
docker run --net host -v ~/.ssh:/home/myuser/.ssh:ro -v ./config:/etc/autossh/config:ro -e PUID=1000 -e PGID=1000 -e AUTOSSH_GATETIME=0 --restart always oaklight/autossh-tunnel:latest
```

Adjust the `PUID` and `PGID` values according to the UID and GID of the host user to ensure that the container can correctly access the host's `.ssh` directory.

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

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [autossh](http://www.harding.motd.ca/autossh/) for maintaining SSH connections.
- [yq](https://github.com/mikefarah/yq) for parsing YAML configuration files.
- [Docker](https://www.docker.com/) for containerization.

---

Contributions to the project are welcome via issues or pull requests. Happy tunneling!
