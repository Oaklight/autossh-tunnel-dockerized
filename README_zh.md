# 使用 Docker 和 Autossh 管理 SSH 隧道

[中文版](README_zh.md) | [English](README_en.md)

本项目提供了一个基于 Docker 的解决方案，使用 `autossh` 和 YAML 配置文件来管理 SSH 隧道。该设置允许您轻松地将 **本地服务通过 SSH 隧道暴露到远程服务器**，或将 **远程服务映射到本地端口**，从而方便地访问位于防火墙后的服务。最新版本可监测 `config.yaml` 变化并自动重载服务。

## 目录

- [功能](#功能)
- [先决条件](#先决条件)
- [发布版本](#发布版本)
- [设置](#设置)
  - [1. 克隆仓库](#1-克隆仓库)
  - [2. 配置 SSH 密钥](#2-配置-ssh-密钥)
  - [3. 配置 YAML 文件](#3-配置-yaml-文件)
  - [4. 构建并运行 Docker 容器](#4-构建并运行-docker-容器)
  - [5. 访问服务](#5-访问服务)
- [网页配置功能](#网页配置功能)
  - [概述](#概述)
  - [使用方法](#使用方法)
- [自定义](#自定义)
  - [添加更多隧道](#添加更多隧道)
  - [修改 Dockerfile](#修改-dockerfile)
  - [修改入口点脚本](#修改入口点脚本)
- [动态 UID/GID 支持](#动态-uidgid-支持)
- [安全注意事项](#安全注意事项)
- [故障排除](#故障排除)
  - [SSH 密钥权限](#ssh-密钥权限)
  - [Docker 权限](#docker-权限)
  - [日志](#日志)
- [许可证](#许可证)
- [致谢](#致谢)

## 功能

- **Docker 化**：使用 Docker 封装环境，使其易于部署和管理。
- **非 root 用户**：以非 root 用户运行容器，增强安全性。
- **YAML 配置**：使用 `config.yaml` 文件定义多个 SSH 隧道映射，并支持配置文件变化自动重载。
- **Autossh**：自动维护 SSH 连接，确保隧道保持活动状态。
- **动态 UID/GID 支持**：通过 `PUID` 和 `PGID` 环境变量动态设置容器用户的 UID 和 GID，以匹配主机用户的权限。
- **多架构支持**：现已支持所有 Alpine 的底层架构，包括 `linux/amd64`、`linux/arm64/v8`、`linux/arm/v7`、`linux/arm/v6`、`linux/386`、`linux/ppc64le`、`linux/s390x` 和 `linux/riscv64`。
- **灵活的方向配置**：支持将本地服务暴露到远程服务器（`local_to_remote`）或将远程服务映射到本地端口（`remote_to_local`）。
- **自动重载**：检测 `config.yaml` 变化并自动重载服务。
- **网页配置功能**：通过网页界面管理隧道配置。

## 先决条件

- 本地机器上已安装 Docker 和 Docker Compose。
- 已设置用于访问远程主机的 SSH 密钥。

## 发布版本

我已将打包好的 docker image 发布到 Docker Hub。您可以通过以下链接访问该版本：

[Docker Hub 链接](https://hub.docker.com/r/oaklight/autossh-tunnel)

欢迎使用并提供反馈！

## 设置

### 1. 克隆仓库

将此仓库克隆到您的本地机器：

```sh
git clone https://github.com/Oaklight/autossh-tunnel-dockerized.git
cd autossh-tunnel-dockerized
```

### 2. 配置 SSH 密钥

确保您的 SSH 密钥位于 `~/.ssh` 目录中。该目录应包含您的私钥文件（例如 `id_ed25519` ）和任何必要的 SSH 配置文件。

### 3. 配置 YAML 文件

编辑 `config.yaml` 文件以定义您的 SSH 隧道映射。每个条目应指定远程主机、远程端口、本地端口和方向（`local_to_remote` 或 `remote_to_local`）。

示例 `config.yaml.sample` （复制到 `config.yaml` 并进行必要的更改）：

```yaml
tunnels:
  # 将本地服务暴露到远程服务器
  - remote_host: "user@remote-host1"
    remote_port: 22323
    local_port: 18120
    direction: local_to_remote
  # 将远程服务映射到本地端口
  - remote_host: "user@remote-host2"
    remote_port: 8000
    local_port: 8001
    direction: remote_to_local
  # 根据需要添加更多隧道
```

#### 高级配置：指定绑定地址

如果您希望将 **远程端口** 或 **本地服务** 绑定到特定 IP 地址，可以使用 `ip:port` 格式。

##### 1. **指定远程绑定地址**

将远程端口绑定到特定 IP 地址（例如 `192.168.45.130`）：

```yaml
tunnels:
  - remote_host: "user@remote-host1"
    remote_port: "192.168.45.130:22323" # 远程绑定到 192.168.45.130
    local_port: 18120 # 本地服务端口
    direction: local_to_remote
```

##### 2. **指定本地绑定地址**

将本地服务绑定到特定 IP 地址（例如 `192.168.1.100`）：

```yaml
tunnels:
  - remote_host: "user@remote-host1"
    remote_port: 22323 # 远程端口
    local_port: "192.168.1.100:18120" # 本地绑定到 192.168.1.100
    direction: local_to_remote
```

##### 3. **同时指定远程和本地绑定地址**

```yaml
tunnels:
  - remote_host: "user@remote-host1"
    remote_port: "192.168.45.130:22323" # 远程绑定到 192.168.45.130
    local_port: "192.168.1.100:18120" # 本地绑定到 192.168.1.100
    direction: local_to_remote
```

通过这种方式，您可以灵活地控制隧道绑定的 IP 地址，从而满足不同的网络环境和安全需求。

### 4. 构建并运行 Docker 容器

#### 使用 Dockerhub 发布版本

```sh
docker compose up -d
```

#### 本地构建并运行容器

```sh
# build
docker compose -f compose.dev.yaml build
# run
docker compose -f compose.dev.yaml up -d
```

### 5. 访问服务

容器运行后，您可以通过远程服务器的指定端口（例如 `remote-host1:22323`）访问本地服务，或通过本地端口（例如 `localhost:8001`）访问远程服务。

## 网页配置功能

### 概述

本项目新增了 **网页配置功能**，允许用户通过网页界面管理 SSH 隧道配置。网页界面提供以下功能：

- 可视化编辑 `config.yaml` 文件。
- 自动备份配置更改。
- 实时更新隧道配置，无需重启容器。

### 使用方法

1. **启动网页服务**：
   确保在 `docker-compose.yaml` 文件中启动 `web` 服务：

   ```yaml
   services:
     web:
       image: oaklight/autossh-tunnel-web-panel:latest
       ports:
         - "5000:5000"
       volumes:
         - ./config:/home/myuser/config:z
       environment:
         - PUID=${PUID:-1000}
         - PGID=${PGID:-1000}
         - TZ=Asia/Shanghai
       restart: always
   ```

2. **访问网页界面**：
   打开浏览器并导航到 `http://localhost:5000`。您将看到管理隧道的网页界面。

3. **编辑配置**：

   - 使用网页界面查看和修改 `config.yaml` 文件。
   - 保存更改，系统将自动备份先前的配置并应用新的配置。

4. **验证更改**：
   - 检查 `config` 目录，确保新配置已保存，并且备份文件保存在 `backups` 子目录中。

## 自定义

### 添加更多隧道

要添加更多 SSH 隧道，只需在 `config.yaml` 文件中添加更多条目。每个条目应遵循以下格式：

```yaml
- remote_host: "user@remote-host"
  remote_port: <remote_port>
  local_port: <local_port>
  direction: <local_to_remote 或 remote_to_local> (如不填写则默认: remote_to_local)
```

### 修改 Dockerfile

如果需要自定义 Docker 环境，可以修改 `Dockerfile` 。例如，您可以安装其他软件包或更改基础镜像。

### 修改入口点脚本

`entrypoint.sh` 脚本负责读取 `config.yaml` 文件并启动 SSH 隧道。如果需要添加其他功能或更改隧道的管理方式，可以修改此脚本。

## 动态 UID/GID 支持

为了确保容器中的用户权限与主机用户权限匹配，您可以通过 `compose.yaml` 文件中的 `PUID` 和 `PGID` 环境变量动态设置容器用户的 UID 和 GID。例如：

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

或者使用 `docker run` 命令并设置环境变量：

```bash
docker run --net host -v ~/.ssh:/home/myuser/.ssh:ro -v ./config:/etc/autossh/config:ro -e PUID=1000 -e PGID=1000 -e AUTOSSH_GATETIME=0 --restart always oaklight/autossh-tunnel:latest
```

您可以根据主机用户的 UID 和 GID 调整 `PUID` 和 `PGID` 的值，以确保容器能够正确访问主机的 `.ssh` 目录。

## 安全注意事项

在启用 `-R` 参数时，远程端口默认绑定到 `localhost`。如果希望通过远程服务器的其他 IP 地址访问隧道，需在远程服务器的 `sshd_config` 中启用 `GatewayPorts` 选项：

```bash
# 编辑 /etc/ssh/sshd_config
GatewayPorts clientspecified  # 允许客户端指定绑定地址
GatewayPorts yes              # 或绑定到所有网络接口
```

重启 SSH 服务：

```bash
sudo systemctl restart sshd
```

启用 `GatewayPorts` 可能会暴露服务到公网，请确保采取适当的安全措施，例如配置防火墙或启用访问控制。

## 故障排除

### SSH 密钥权限

确保 `.ssh` 目录及其内容具有适当的权限：

```sh
chmod 700 .ssh
chmod 600 .ssh/*
```

### Docker 权限

如果在运行 Docker 命令时遇到权限问题，请确保您的用户在 `docker` 组中：

```sh
sudo usermod -aG docker $USER
```

### 日志

检查 Docker 容器日志以查找任何错误：

```sh
docker compose logs -f
```

## 许可证

本项目基于 MIT 许可证。有关详细信息，请参阅 [LICENSE](LICENSE) 文件。

## 致谢

- [autossh](http://www.harding.motd.ca/autossh/) 用于维护 SSH 连接。
- [yq](https://github.com/mikefarah/yq) 用于解析 YAML 配置文件。
- [Docker](https://www.docker.com/) 用于容器化。

---

欢迎通过提交问题或拉取请求来为该项目做出贡献。祝您隧道愉快！
