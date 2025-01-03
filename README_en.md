# SSH Tunnel Manager with Docker and Autossh

[中文版](README.md) | [English](README_en.md)

This project provides a Docker-based solution to manage SSH tunnels using `autossh` and a YAML configuration file. The setup allows you to easily map remote ports to local ports, making it convenient to access services on remote machines behind firewalls.

## Table of Contents

* [Features](#features)
* [Prerequisites](#prerequisites)
* [Release](#release)
* [Setup](#setup)
  + [1. Clone the Repository](#1-clone-the-repository)
  + [2. Configure SSH Keys](#2-configure-ssh-keys)
  + [3. Configure the YAML File](#3-configure-the-yaml-file)
  + [4. Build and Run the Docker Container](#4-build-and-run-the-docker-container)
  + [5. Access the Services](#5-access-the-services)
* [Customization](#customization)
  + [Adding More Tunnels](#adding-more-tunnels)
  + [Modifying the Dockerfile](#modifying-the-dockerfile)
  + [Modifying the Entrypoint Script](#modifying-the-entrypoint-script)
* [Using `compose.custom.yaml` and `Dockerfile.custom`](#using-composecustomyaml-and-dockerfilecustom)
  + [Steps to Use](#steps-to-use)
  + [Why Are These Files Needed?](#why-are-these-files-needed)
* [Troubleshooting](#troubleshooting)
  + [SSH Key Permissions](#ssh-key-permissions)
  + [Docker Permissions](#docker-permissions)
  + [Logs](#logs)
* [License](#license)
* [Acknowledgments](#acknowledgments)

## Features

* **Dockerized**: Uses Docker to encapsulate the environment, making it easy to deploy and manage.
* **Non-Root User**: Runs the container as a non-root user for enhanced security.
* **YAML Configuration**: Uses a `config.yaml` file to define multiple SSH tunnel mappings.
* **Autossh**: Automatically maintains SSH connections, ensuring tunnels stay active.

## Prerequisites

* Docker and Docker Compose installed on your local machine.
* SSH keys set up for accessing remote hosts.

## Release

I have released the first version to Docker Hub. You can access the version via the following link:

[Docker Hub Link](https://hub.docker.com/r/oaklight/autossh-tunnel)

Feel free to use it and provide feedback!

## Setup

### 1. Clone the Repository

Clone this repository to your local machine:

```sh
git clone https://github.com/yourusername/ssh-tunnel-manager.git
cd ssh-tunnel-manager
```

### 2. Configure SSH Keys

Ensure your SSH keys are located in the `~/.ssh` directory. The directory should contain your private key files (e.g., `id_ed25519` ) and any necessary SSH configuration files.

### 3. Configure the YAML File

Edit the `config.yaml` file to define your SSH tunnel mappings. Each entry should specify the remote host, remote port, and local port.

Example `config.yaml.sample` (copy it to `config.yaml` and make necessary changes) :

```yaml
tunnels:
  - remote_host: "user@remote-host1"
    remote_port: 8000
    local_port: 8001
  - remote_host: "user@remote-host2"
    remote_port: 9000
    local_port: 9001
  # Add more tunnels as needed
```

### 4. Build and Run the Docker Container

#### Use dockerhub release image

```sh
docker compose up -d
```

#### Build and run the container by yourself

```sh
# build
docker compose build -f compose.dev.yaml
# run
docker compose up -f compose.dev.yaml -d
```

### 5. Access the Services

Once the container is running, you can access the services on your local machine using the specified local ports. For example, if you mapped `remote-host1:8000` to `localhost:8001` , you can access the service at `http://localhost:8001` .

## Customization

### Adding More Tunnels

To add more SSH tunnels, simply update the `config.yaml` file with additional entries. Each entry should follow the format:

```yaml
- remote_host: "user@remote-host"
  remote_port: <remote_port>
  local_port: <local_port>
```

### Modifying the Dockerfile

If you need to customize the Docker environment, you can modify the `Dockerfile` . For example, you can install additional packages or change the base image.

### Modifying the Entrypoint Script

The `entrypoint.sh` script is responsible for reading the `config.yaml` file and starting the SSH tunnels. You can modify this script if you need to add additional functionality or change how the tunnels are managed.

## Using `compose.custom.yaml` and `Dockerfile.custom`

In some cases, you may need to customize the container's user ID (UID) and group ID (GID) to match the host user's permissions. For example, if the host's `.ssh` folder has a different UID and GID than the default user in the container, it may cause permission issues.

To address this, we provide `compose.custom.yaml` and `Dockerfile.custom` files. These files allow you to dynamically set the container's UID and GID to match the host user's UID and GID.

### Steps to Use

1. Ensure you have cloned the repository and configured the `config.yaml` file.
2. Run the following command to build and start the container using `compose.custom.yaml`:

   

```bash
   HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose -f compose.custom.yaml up -d --build
   ```

### Why Are These Files Needed?

* **UID/GID Mismatch Issue**: By default, the `myuser` in the container uses UID 1000 and GID 1000. If the host's `.ssh` folder has a different UID and GID, the container will not be able to access it.
* **Dynamic UID/GID Setting**: `compose.custom.yaml` and `Dockerfile.custom` allow you to dynamically set the container's UID and GID to match the host user's UID and GID, resolving permission issues.

## Troubleshooting

### SSH Key Permissions

Ensure that the `.ssh` directory and its contents have the appropriate permissions:

```sh
chmod 700 .ssh
chmod 600 .ssh/*
```

### Docker Permissions

If you encounter permission issues when running Docker commands, ensure your user is in the `docker` group:

```sh
sudo usermod -aG docker $USER
```

### Logs

Check the Docker container logs for any errors:

```sh
docker compose logs -f
```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

* [autossh](http://www.harding.motd.ca/autossh/) for maintaining SSH connections.
* [yq](https://github.com/mikefarah/yq) for parsing YAML configuration files.
* [Docker](https://www.docker.com/) for containerization.

---

Feel free to contribute to this project by submitting issues or pull requests. Happy tunneling!
