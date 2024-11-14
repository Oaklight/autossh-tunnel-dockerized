# SSH Tunnel Manager with Docker and Autossh

[中文版](README.md) | [English](README_en.md)

This project provides a Docker-based solution to manage SSH tunnels using `autossh` and a YAML configuration file. The setup allows you to easily map remote ports to local ports, making it convenient to access services on remote machines behind firewalls.

## Features

* **Dockerized**: Uses Docker to encapsulate the environment, making it easy to deploy and manage.
* **Non-Root User**: Runs the container as a non-root user for enhanced security.
* **YAML Configuration**: Uses a `config.yaml` file to define multiple SSH tunnel mappings.
* **Autossh**: Automatically maintains SSH connections, ensuring tunnels stay active.

## Prerequisites

* Docker and Docker Compose installed on your local machine.
* SSH keys set up for accessing remote hosts.

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

Use Docker Compose to build and run the container:

```sh
# build
docker compose build
# run
docker compose up -d
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
docker-compose logs -f
```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

* [autossh](http://www.harding.motd.ca/autossh/) for maintaining SSH connections.
* [yq](https://github.com/mikefarah/yq) for parsing YAML configuration files.
* [Docker](https://www.docker.com/) for containerization.

---

Feel free to contribute to this project by submitting issues or pull requests. Happy tunneling!
