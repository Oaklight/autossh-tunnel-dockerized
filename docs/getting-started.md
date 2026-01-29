# 快速入门

本指南将帮助您快速设置和运行 SSH 隧道管理器。

## 前置要求

- 本地机器上已安装 Docker 和 Docker Compose
- 已设置用于访问远程主机的 SSH 密钥
- 基本的 SSH 和 Docker 知识

## 安装步骤

### 1. 下载所需文件

对于大多数用户，您只需要下载 Docker Compose 文件。

**选项 A：直接下载文件**

创建新目录并下载所需文件：

```bash
mkdir autossh-tunnel
cd autossh-tunnel

# 下载 docker-compose.yaml（包含 autossh 隧道和网页面板两个服务）
curl -O https://oaklight.github.io/autossh-tunnel-dockerized/compose.yaml

# 创建 config 目录
mkdir config

# 方式1：下载示例配置（如果您想手动配置）
curl -o config/config.yaml.sample https://oaklight.github.io/autossh-tunnel-dockerized/config/config.yaml.sample
cp config/config.yaml.sample config/config.yaml

# 方式2：创建空配置文件（如果您想使用网页面板进行配置）
touch config/config.yaml
```

!!! note "关于 compose.yaml"
    `compose.yaml` 文件包含了 autossh 隧道服务和网页面板服务两个部分。网页面板是可选的 - 如果您更喜欢手动配置，可以在 compose 文件中注释掉 `web` 服务部分来禁用它。

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

!!! warning "重要提示"
    本项目严重依赖 `~/.ssh/config` 文件进行 SSH 连接配置。SSH 配置文件允许您为每个远程主机定义连接参数，如主机名、用户名、端口和密钥文件。如果没有正确的 SSH 配置设置，隧道可能无法建立连接。

有关详细的 SSH 配置文件设置说明，请参阅：[SSH 配置指南](ssh-config.md)

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

!!! tip "网页面板提示"
    - 网页面板每次保存更改时会自动将配置备份到 `config/backups/` 目录
    - 您可能需要手动删除过多的备份文件以防止磁盘空间问题
    - `config/config.yaml` 文件必须存在（即使为空）才能使 autossh 隧道服务正常工作

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

!!! note "向后兼容性"
    默认模式保持与现有配置的向后兼容性。如果您更喜欢 SSH 的原生术语，请选择 `ssh-standard` 模式。

## 访问服务

容器运行后：

- **本地到远程隧道**（默认模式）：通过远程服务器的指定端口访问本地服务（例如 `remote-host1:22323`）
- **远程到本地隧道**（默认模式）：通过本地端口访问远程服务（例如 `localhost:8001`）

## 下一步

- 了解 [架构说明](architecture.md) 以深入理解系统工作原理
- 查看 [Web 面板使用指南](web-panel.md) 学习如何使用可视化界面
- 阅读 [API 文档](api/index.md) 了解如何通过 CLI 或 HTTP API 控制隧道
- 遇到问题？查看 [故障排除指南](troubleshooting.md)