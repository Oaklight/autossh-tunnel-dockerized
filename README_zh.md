# 使用 Docker 和 Autossh 管理 SSH 隧道

[中文版](README_zh.md) | [English](README_en.md)

本项目提供了一个基于 Docker 的解决方案，使用 `autossh` 和 YAML 配置文件来管理 SSH 隧道。该设置允许您轻松地将 **本地服务通过 SSH 隧道暴露到远程服务器**，或将 **远程服务映射到本地端口**，从而方便地访问位于防火墙后的服务。最新版本可监测 `config.yaml` 变化并自动重载服务。

![网页面板界面](https://github.com/user-attachments/assets/bb26d0f5-14ee-4289-b809-e48381c05bc1)

## 目录

- [功能](#功能)
- [先决条件](#先决条件)
- [发布版本](#发布版本)
- [设置](#设置)
  - [1. 下载所需文件](#1-下载所需文件)
  - [2. 配置 SSH 密钥](#2-配置-ssh-密钥)
  - [3. 配置 YAML 文件](#3-配置-yaml-文件)
  - [4. 配置用户权限 (PUID/PGID)](#4-配置用户权限-puidpgid)
  - [5. 构建并运行 Docker 容器](#5-构建并运行-docker-容器)
  - [6. 访问服务](#6-访问服务)
- [SSH 配置文件配置指南](README_ssh_config_zh.md)
- [网页配置功能](#网页配置功能)
- [隧道控制 API](#隧道控制-api)
- [自定义](#自定义)
  - [添加更多隧道](#添加更多隧道)
  - [修改 Dockerfile](#修改-dockerfile)
  - [修改入口点脚本](#修改入口点脚本)
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
- **CLI 工具 (autossh-cli)**：命令行界面，用于管理隧道、查看状态和控制单个隧道。
- **HTTP API**：RESTful API 用于程序化隧道控制，支持与其他工具和自动化集成。
- **单个隧道控制**：独立启动、停止和管理每个隧道，互不影响。

## 先决条件

- 本地机器上已安装 Docker 和 Docker Compose。
- 已设置用于访问远程主机的 SSH 密钥。

## 发布版本

我已将打包好的 docker image 发布到 Docker Hub。您可以通过以下链接访问该版本：

[Docker Hub 链接](https://hub.docker.com/r/oaklight/autossh-tunnel)

欢迎使用并提供反馈！

## 设置

### 1. 下载所需文件

对于大多数用户，您只需要下载 Docker Compose 文件。您可以选择：

**选项 A：直接下载文件**

创建新目录并下载所需文件：

```sh
mkdir autossh-tunnel
cd autossh-tunnel

# 下载 docker-compose.yaml（包含 autossh 隧道和网页面板两个服务）
# 使用 GitHub 原始链接
curl -O https://oaklight.github.io/autossh-tunnel-dockerized/compose.yaml

# 或者使用 jsDelivr CDN（国内用户推荐）
# curl -O https://cdn.jsdelivr.net/gh/Oaklight/autossh-tunnel-dockerized@master/compose.yaml

# 创建 config 目录
mkdir config

# 方式1：下载示例配置（如果您想手动配置）
curl -o config/config.yaml.sample https://oaklight.github.io/autossh-tunnel-dockerized/config/config.yaml.sample
# 或使用 jsDelivr CDN
# curl -o config/config.yaml.sample https://cdn.jsdelivr.net/gh/Oaklight/autossh-tunnel-dockerized@master/config/config.yaml.sample
cp config/config.yaml.sample config/config.yaml

# 方式2：创建空配置文件（如果您想使用网页面板进行配置）
touch config/config.yaml
```

**注意**：`compose.yaml` 文件包含了 autossh 隧道服务和网页面板服务两个部分。网页面板是可选的 - 如果您更喜欢手动配置，可以在 compose 文件中注释掉 `web` 服务部分来禁用它。

**选项 B：克隆仓库（开发者使用）**

如果您想修改源代码或本地构建：

```sh
git clone https://github.com/Oaklight/autossh-tunnel-dockerized.git
cd autossh-tunnel-dockerized
```

### 2. 配置 SSH 密钥

确保您的 SSH 密钥位于 `~/.ssh` 目录中。该目录应包含您的私钥文件（例如 `id_ed25519` ）和任何必要的 SSH 配置文件。

**重要提示**：本项目严重依赖 `~/.ssh/config` 文件进行 SSH 连接配置。SSH 配置文件允许您为每个远程主机定义连接参数，如主机名、用户名、端口和密钥文件。如果没有正确的 SSH 配置设置，隧道可能无法建立连接。

有关详细的 SSH 配置文件设置说明，请参阅：[SSH 配置文件配置指南](README_ssh_config_zh.md)

### 3. 配置 YAML 文件

您有两种配置 SSH 隧道的方式：

#### 方式 A：手动配置

编辑 `config.yaml` 文件以定义您的 SSH 隧道映射。每个条目应指定远程主机、远程端口、本地端口和方向（`local_to_remote` 或 `remote_to_local`）。

示例配置：

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

#### 方式 B：网页面板配置

如果您使用网页面板（包含在 `compose.yaml` 中），您可以：

- 从空的 `config/config.yaml` 文件开始
- 访问网页界面：`http://localhost:5000`
- 通过可视化界面配置隧道

**网页面板用户重要提示：**

- 网页面板每次保存更改时会自动将配置备份到 `config/backups/` 目录
- 您可能需要手动删除过多的备份文件以防止磁盘空间问题
- `config/config.yaml` 文件必须存在（即使为空）才能使 autossh 隧道服务正常工作

#### 高级配置：指定绑定地址

如果您希望将 **远程端口** 或 **本地服务** 绑定到特定 IP 地址，可以使用 `ip:port` 格式。

##### 1. **指定远程绑定地址**

将远程端口绑定到特定 IP 地址（例如 `192.168.45.130`）：

设置这些值的方法有两种：

1. **设置环境变量**：

   ```sh
   export PUID=$(id -u)
   export PGID=$(id -g)
   ```

2. **直接编辑 compose.yaml 文件**：

   ```yaml
   environment:
     - PUID=1000
     - PGID=1000
   ```

### 5. 构建并运行 Docker 容器

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

### 4. 配置用户权限 (PUID/PGID)

**重要提示**：在运行容器之前，请确保在环境变量或 `compose.yaml` 文件中设置正确的 `PUID` 和 `PGID` 值，以匹配您主机用户的 UID 和 GID。这确保了 SSH 密钥和配置文件的正确文件权限。

您可以使用以下命令查看您的用户 UID 和 GID：

```sh
id
```

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

### 6. 访问服务

容器运行后，您可以通过远程服务器的指定端口（例如 `remote-host1:22323`）访问本地服务，或通过本地端口（例如 `localhost:8001`）访问远程服务。

## 网页配置功能

本项目包含可选的 **网页配置面板**，便于隧道管理。网页面板包含在默认的 `compose.yaml` 文件中，但如果不需要可以禁用。

### 功能特性

- 可视化界面查看和编辑 `config.yaml` 文件
- 自动备份配置更改到 `config/backups/` 目录
- 实时更新隧道配置，无需重启容器
- 可以从空配置文件开始

### 访问方式

容器运行后，访问网页面板：`http://localhost:5000`

### 备份管理

网页面板每次保存更改时会自动在 `config/backups/` 目录创建备份。您可能需要手动清理旧的备份文件以防止磁盘空间问题。

## 隧道控制 API

本项目提供 CLI 和 HTTP API 两种接口用于高级隧道管理。

### CLI 命令

```bash
# 列出所有配置的隧道
autossh-cli list

# 查看隧道运行状态
autossh-cli status

# 启动特定隧道
autossh-cli start-tunnel <hash>

# 停止特定隧道
autossh-cli stop-tunnel <hash>

# 启动所有隧道
autossh-cli start

# 停止所有隧道
autossh-cli stop
```

### HTTP API 端点

| 方法 | 端点            | 描述                   |
| ---- | --------------- | ---------------------- |
| GET  | `/list`         | 获取所有配置的隧道列表 |
| GET  | `/status`       | 获取所有隧道的运行状态 |
| POST | `/start`        | 启动所有隧道           |
| POST | `/stop`         | 停止所有隧道           |
| POST | `/start/<hash>` | 启动指定的隧道         |
| POST | `/stop/<hash>`  | 停止指定的隧道         |

详细 API 文档请参阅：[隧道控制 API 文档](doc/tunnel-control-api_zh.md)

---

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
- [Docker](https://www.docker.com/) 用于容器化。
- [Alpine Linux](https://alpinelinux.org/) 提供轻量级基础镜像。
- [Go](https://golang.org/) 用于 Web 面板后端。

---

欢迎通过提交问题或拉取请求来为该项目做出贡献。祝您隧道愉快！
