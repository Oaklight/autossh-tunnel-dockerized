# 基于 Docker 和 Autossh 的 SSH 隧道管理器

[![GitHub version](https://badge.fury.io/gh/oaklight%2Fautossh-tunnel-dockerized.svg?icon=si%3Agithub)](https://badge.fury.io/gh/oaklight%2Fautossh-tunnel-dockerized)
[![Docker Hub - autossh-tunnel](https://img.shields.io/docker/v/oaklight/autossh-tunnel?sort=semver&label=autossh-tunnel&logo=docker)](https://hub.docker.com/r/oaklight/autossh-tunnel)
[![Docker Hub - autossh-tunnel-web-panel](https://img.shields.io/docker/v/oaklight/autossh-tunnel-web-panel?sort=semver&label=autossh-tunnel-web-panel&logo=docker)](https://hub.docker.com/r/oaklight/autossh-tunnel-web-panel)

[中文版](README_zh.md) | [English](README_en.md)

![网页面板界面](https://github.com/user-attachments/assets/bb26d0f5-14ee-4289-b809-e48381c05bc1)

本项目提供了一个基于 Docker 的解决方案，使用 `autossh` 和 YAML 配置文件来管理 SSH 隧道。此设置允许您轻松地**将本地服务通过 SSH 隧道暴露到远程服务器**或**将远程服务映射到本地端口**，方便访问防火墙后的服务。

## 功能特性

- **Docker 化**：使用 Docker 封装环境，易于部署和管理。
- **非 root 用户**：以非 root 用户运行容器，增强安全性。
- **YAML 配置**：使用 `config.yaml` 文件定义多个 SSH 隧道映射，支持配置变更时自动重载服务。
- **Autossh**：自动维护 SSH 连接，确保隧道保持活跃。
- **动态 UID/GID 支持**：使用 `PUID` 和 `PGID` 环境变量动态设置容器用户的 UID 和 GID，以匹配主机用户权限。
- **多架构支持**：支持所有 Alpine 基础架构，包括 `linux/amd64`、`linux/arm64/v8`、`linux/arm/v7`、`linux/arm/v6`、`linux/386`、`linux/ppc64le`、`linux/s390x` 和 `linux/riscv64`。
- **灵活的方向配置**：支持将本地服务暴露到远程服务器（`local_to_remote`）或将远程服务映射到本地端口（`remote_to_local`）。
- **自动重载**：检测 `config.yaml` 的变化并自动重载服务配置。
- **Web 配置界面**：通过 Web 面板管理隧道和配置更新。
- **CLI 工具 (autossh-cli)**：用于管理隧道、查看状态和控制单个隧道的命令行界面。
- **HTTP API**：用于程序化隧道控制的 RESTful API，支持与其他工具和自动化集成。
- **单个隧道控制**：独立启动、停止和管理每个隧道，不影响其他隧道。

## 前置要求

- 本地机器上已安装 Docker 和 Docker Compose。
- 已设置用于访问远程主机的 SSH 密钥。

## 快速链接

- [完整文档 (English)](https://oaklight.github.io/autossh-tunnel-dockerized/en/)
- [完整文档 (中文)](https://oaklight.github.io/autossh-tunnel-dockerized/zh/)

## 发布版本

打包的 Docker 镜像可在 Docker Hub 上获取：

[Docker Hub 链接](https://hub.docker.com/r/oaklight/autossh-tunnel)

欢迎使用并提供反馈！

## 快速入门

### 1. 下载所需文件

对于大多数用户，您只需要下载 Docker Compose 文件。

**选项 A：直接下载文件**

创建新目录并下载所需文件：

```bash
mkdir autossh-tunnel
cd autossh-tunnel

# 下载 docker-compose.yaml（包含 autossh 隧道和网页面板两个服务）
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

> **注意**：`compose.yaml` 文件包含了 autossh 隧道服务和网页面板服务两个部分。网页面板是可选的 - 如果您更喜欢手动配置，可以在 compose 文件中注释掉 `web` 服务部分来禁用它。

**选项 B：克隆仓库（开发者使用）**

如果您想修改源代码或本地构建：

```bash
git clone https://github.com/Oaklight/autossh-tunnel-dockerized.git
cd autossh-tunnel-dockerized
```

### 2. 配置 SSH 密钥

确保您的 SSH 密钥位于 `~/.ssh` 目录中。该目录应包含：

- 私钥文件（例如 `id_ed25519`、`id_rsa`）
- SSH 配置文件（`config`）
- 已知主机文件（`known_hosts`）

> **重要提示**：本项目严重依赖 `~/.ssh/config` 文件进行 SSH 连接配置。SSH 配置文件允许您为每个远程主机定义连接参数，如主机名、用户名、端口和密钥文件。如果没有正确的 SSH 配置设置，隧道可能无法建立连接。

有关详细的 SSH 配置文件设置说明，请参阅：[SSH 配置指南](README_ssh_config_zh.md)

### 3. 配置隧道

您有两种配置 SSH 隧道的方式：

#### 方式 A：手动配置

编辑 `config/config.yaml` 文件以定义您的 SSH 隧道映射。

**基本示例：**

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
```

**高级配置：指定绑定地址**

如果您希望将远程端口或本地服务绑定到特定 IP 地址，可以使用 `ip:port` 格式：

```yaml
tunnels:
  # 指定远程绑定地址
  - remote_host: "user@remote-host1"
    remote_port: "192.168.45.130:22323"  # 远程绑定到特定 IP
    local_port: 18120
    direction: local_to_remote
    
  # 指定本地绑定地址
  - remote_host: "user@remote-host1"
    remote_port: 22323
    local_port: "192.168.1.100:18120"  # 本地绑定到特定 IP
    direction: local_to_remote
    
  # 同时指定远程和本地绑定地址
  - remote_host: "user@remote-host1"
    remote_port: "192.168.45.130:22323"
    local_port: "192.168.1.100:18120"
    direction: local_to_remote
```

#### 方式 B：网页面板配置

如果您使用网页面板（包含在 `compose.yaml` 中）：

1. 从空的 `config/config.yaml` 文件开始
2. 启动服务后访问 `http://localhost:5000`
3. 通过可视化界面配置隧道

> **提示**：
> - 网页面板每次保存更改时会自动将配置备份到 `config/backups/` 目录
> - 您可能需要手动删除过多的备份文件以防止磁盘空间问题
> - `config/config.yaml` 文件必须存在（即使为空）才能使 autossh 隧道服务正常工作

### 4. 配置用户权限 (PUID/PGID)

在运行容器之前，请确保设置正确的 `PUID` 和 `PGID` 值，以匹配您主机用户的 UID 和 GID。

查看您的用户 UID 和 GID：

```bash
id
```

设置方法：

**方法 1：设置环境变量**

```bash
export PUID=$(id -u)
export PGID=$(id -g)
```

**方法 2：直接编辑 compose.yaml 文件**

```yaml
environment:
  - PUID=1000
  - PGID=1000
```

### 5. 启动服务

#### 使用 Docker Hub 镜像

```bash
docker compose up -d
```

#### 本地构建并运行

```bash
# 构建
docker compose -f compose.dev.yaml build

# 运行
docker compose -f compose.dev.yaml up -d
```

### 6. 验证服务

检查容器状态：

```bash
docker compose ps
```

查看日志：

```bash
docker compose logs -f
```

访问 Web 面板（如果启用）：

```
http://localhost:5000
```

## 隧道方向模式

本项目支持两种隧道方向配置的解释模式：

### 默认模式（服务导向）

默认模式从**服务暴露方向**的角度解释方向配置：

- `local_to_remote`：将**本地**服务暴露**到远程**（使用 SSH `-R`，远程监听）
- `remote_to_local`：将**远程**服务映射**到本地**（使用 SSH `-L`，本地监听）

### SSH 标准模式

SSH 标准模式与 **SSH 原生术语**保持一致：

- `local_to_remote`：SSH 本地转发（使用 SSH `-L`，本地监听）
- `remote_to_local`：SSH 远程转发（使用 SSH `-R`，远程监听）

### 切换模式

在 `compose.yaml` 中设置 `TUNNEL_DIRECTION_MODE` 环境变量：

```yaml
environment:
  - TUNNEL_DIRECTION_MODE=default        # 默认模式（当前行为）
  # - TUNNEL_DIRECTION_MODE=ssh-standard # SSH 标准模式
```

> **注意**：默认模式保持与现有配置的向后兼容性。如果您更喜欢 SSH 的原生术语，请选择 `ssh-standard` 模式。

## 访问服务

容器运行后：

- **本地到远程隧道**（默认模式）：通过远程服务器的指定端口访问本地服务（例如 `remote-host1:22323`）
- **远程到本地隧道**（默认模式）：通过本地端口访问远程服务（例如 `localhost:8001`）

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

详细 API 文档请参阅：[隧道控制 API 文档](https://oaklight.github.io/autossh-tunnel-dockerized/zh/api/http-api/)

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

```bash
chmod 700 .ssh
chmod 600 .ssh/*
```

### Docker 权限

如果在运行 Docker 命令时遇到权限问题，请确保您的用户在 `docker` 组中：

```bash
sudo usermod -aG docker $USER
```

### 日志

检查 Docker 容器日志以查找任何错误：

```bash
docker compose logs -f
```

更多故障排除技巧，请参阅[完整文档](https://oaklight.github.io/autossh-tunnel-dockerized/zh/)。

## 许可证

本项目基于 MIT 许可证。有关详细信息，请参阅 [LICENSE](LICENSE) 文件。

## 致谢

- [autossh](http://www.harding.motd.ca/autossh/) 用于维护 SSH 连接。
- [Docker](https://www.docker.com/) 用于容器化。
- [Alpine Linux](https://alpinelinux.org/) 提供轻量级基础镜像。
- [Go](https://golang.org/) 用于 Web 面板后端。
- [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) 提供文档主题。

---

欢迎通过提交问题或拉取请求来为该项目做出贡献。祝您隧道愉快！