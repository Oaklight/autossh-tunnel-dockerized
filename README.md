# 使用 Docker 和 Autossh 管理 SSH 隧道

[中文版](README.md) | [English](README_en.md)

本项目提供了一个基于 Docker 的解决方案，使用 `autossh` 和 YAML 配置文件来管理 SSH 隧道。该设置允许您轻松地将远程端口映射到本地端口，从而方便地访问位于防火墙后的远程机器上的服务。

## 目录

* [功能](#功能)
* [先决条件](#先决条件)
* [发布版本](#发布版本)
* [设置](#设置)
  + [1. 克隆仓库](#1-克隆仓库)
  + [2. 配置 SSH 密钥](#2-配置-ssh-密钥)
  + [3. 配置 YAML 文件](#3-配置-yaml-文件)
  + [4. 构建并运行 Docker 容器](#4-构建并运行-docker-容器)
  + [5. 访问服务](#5-访问服务)
* [自定义](#自定义)
  + [添加更多隧道](#添加更多隧道)
  + [修改 Dockerfile](#修改-dockerfile)
  + [修改入口点脚本](#修改入口点脚本)
* [使用 `compose.custom.yaml` 和 `Dockerfile.custom`](#使用-composecustomyaml-和-dockerfilecustom)
  + [使用步骤](#使用步骤)
  + [为什么需要这些文件？](#为什么需要这些文件)
* [故障排除](#故障排除)
  + [SSH 密钥权限](#ssh-密钥权限)
  + [Docker 权限](#docker-权限)
  + [日志](#日志)
* [许可证](#许可证)
* [致谢](#致谢)

## 功能

* **Docker 化**：使用 Docker 封装环境，使其易于部署和管理。
* **非 root 用户**：以非 root 用户运行容器，增强安全性。
* **YAML 配置**：使用 `config.yaml` 文件定义多个 SSH 隧道映射。
* **Autossh**：自动维护 SSH 连接，确保隧道保持活动状态。

## 先决条件

* 本地机器上已安装 Docker 和 Docker Compose。
* 已设置用于访问远程主机的 SSH 密钥。

## 发布版本

我已将第一个版本发布到 Docker Hub。您可以通过以下链接访问该版本：

[Docker Hub 链接](https://hub.docker.com/r/oaklight/autossh-tunnel)

欢迎使用并提供反馈！

## 设置

### 1. 克隆仓库

将此仓库克隆到您的本地机器：

```sh
git clone https://github.com/yourusername/ssh-tunnel-manager.git
cd ssh-tunnel-manager
```

### 2. 配置 SSH 密钥

确保您的 SSH 密钥位于 `~/.ssh` 目录中。该目录应包含您的私钥文件（例如 `id_ed25519` ）和任何必要的 SSH 配置文件。

### 3. 配置 YAML 文件

编辑 `config.yaml` 文件以定义您的 SSH 隧道映射。每个条目应指定远程主机、远程端口和本地端口。

示例 `config.yaml.sample` （复制到 `config.yaml` 并进行必要的更改）：

```yaml
tunnels:
  - remote_host: "user@remote-host1"
    remote_port: 8000
    local_port: 8001
  - remote_host: "user@remote-host2"
    remote_port: 9000
    local_port: 9001
  # 根据需要添加更多隧道
```

### 4. 构建并运行 Docker 容器

#### 使用 Dockerhub 发布版本

```sh
docker compose up -d
```

#### 本地构建并运行容器

```sh
# build
docker compose build -f compose.dev.yaml
# run
docker compose up -f compose.dev.yaml -d
```

### 5. 访问服务

容器运行后，您可以使用指定的本地端口访问本地机器上的服务。例如，如果您将 `remote-host1:8000` 映射到 `localhost:8001` ，则可以通过 `http://localhost:8001` 访问服务。

## 自定义

### 添加更多隧道

要添加更多 SSH 隧道，只需在 `config.yaml` 文件中添加更多条目。每个条目应遵循以下格式：

```yaml
- remote_host: "user@remote-host"
  remote_port: <remote_port>
  local_port: <local_port>
```

### 修改 Dockerfile

如果需要自定义 Docker 环境，可以修改 `Dockerfile` 。例如，您可以安装其他软件包或更改基础镜像。

### 修改入口点脚本

`entrypoint.sh` 脚本负责读取 `config.yaml` 文件并启动 SSH 隧道。如果需要添加其他功能或更改隧道的管理方式，可以修改此脚本。

## 使用 `compose.custom.yaml` 和 `Dockerfile.custom`

在某些情况下，您可能需要自定义容器的用户 ID（UID）和组 ID（GID），以匹配主机上的用户权限。例如，如果主机的 `.ssh` 文件夹的 UID 和 GID 与容器中的默认用户不匹配，可能会导致权限问题。

为此，我们提供了 `compose.custom.yaml` 和 `Dockerfile.custom` 文件。这些文件允许您动态地设置容器的 UID 和 GID，以匹配主机用户的 UID 和 GID。

### 使用步骤

1. 确保您已克隆仓库并配置了 `config.yaml` 文件。
2. 运行以下命令，使用 `compose.custom.yaml` 构建和启动容器：

   

```bash
   HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose -f compose.custom.yaml up -d --build
   ```

### 为什么需要这些文件？

* **UID/GID 不匹配问题**：默认情况下，容器中的用户 `myuser` 使用 UID 1000 和 GID 1000。如果主机上的 `.ssh` 文件夹的 UID 和 GID 不同，容器将无法访问 `.ssh` 文件夹。
* **动态 UID/GID 设置**：`compose.custom.yaml` 和 `Dockerfile.custom` 允许您动态地将容器的 UID 和 GID 设置为主机用户的 UID 和 GID，从而解决权限问题。

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

* [autossh](http://www.harding.motd.ca/autossh/) 用于维护 SSH 连接。
* [yq](https://github.com/mikefarah/yq) 用于解析 YAML 配置文件。
* [Docker](https://www.docker.com/) 用于容器化。

---

欢迎通过提交问题或拉取请求来为该项目做出贡献。祝您隧道愉快！
