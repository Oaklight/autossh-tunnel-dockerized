# 单个隧道控制 API 文档

## 概述

本文档介绍了 autossh-tunnel-dockerized 项目中新增的单个隧道控制功能，允许您独立启动、停止和管理各个 SSH 隧道，而不影响其他正在运行的隧道。

## 功能特性

- **独立控制**：可以单独启动或停止任何隧道
- **智能检测**：启动前自动检查隧道是否已在运行
- **状态管理**：实时跟踪每个隧道的运行状态
- **多种接口**：支持 CLI 命令和 HTTP API
- **日志隔离**：每个隧道有独立的日志文件

## CLI 命令

### 基本命令

```bash
# 列出所有配置的隧道
autossh-cli list

# 查看隧道运行状态
autossh-cli status

# 显示特定隧道的详细信息
autossh-cli show-tunnel <hash>

# 启动单个隧道
autossh-cli start-tunnel <hash>

# 停止单个隧道
autossh-cli stop-tunnel <hash>
```

### 使用示例

```bash
# 1. 查看可用的隧道配置
$ autossh-cli list
Configured Tunnels
  done-hub             NORMAL       0.0.0.0:33001 -> cloud.usa2:127.0.0.1:33000 (7b840f8344679dff5df893eefd245043)
  argo-proxy           INTERACTIVE  44498 -> lambda5:44497 (f55793c77944b6e0cd3a46889422487e)
  dockge@tempest       NORMAL       55001 -> oaklight.tempest:5001 (2ea730e749b28910932f2b141638ade8)

# 2. 停止特定隧道
$ autossh-cli stop-tunnel 7b840f8344679dff5df893eefd245043
INFO: Stopping tunnel: 7b840f8344679dff5df893eefd245043
[2026-01-25 12:03:14] [INFO] [STATE] Stopping tunnel: done-hub (7b840f8344679dff5df893eefd245043, PID: 186)

# 3. 启动特定隧道
$ autossh-cli start-tunnel 7b840f8344679dff5df893eefd245043
INFO: Starting tunnel: 7b840f8344679dff5df893eefd245043
[2026-01-25 12:03:23] [INFO] [STATE] Starting tunnel: done-hub (7b840f8344679dff5df893eefd245043)
SUCCESS: Tunnel started successfully: 7b840f8344679dff5df893eefd245043

# 4. 检查状态
$ autossh-cli status
Tunnel Status
Managed tunnels:
  done-hub             RUNNING    0.0.0.0:33001 -> cloud.usa2:127.0.0.1:33000 (7b840f8344679dff5df893eefd245043)
  dockge@tempest       RUNNING    55001 -> oaklight.tempest:5001 (2ea730e749b28910932f2b141638ade8)
```

### Docker 容器中使用

如果您的 autossh 运行在 Docker 容器中：

```bash
# 列出隧道
docker exec -it autotunnel-autossh-1 autossh-cli list

# 停止隧道
docker exec -it autotunnel-autossh-1 autossh-cli stop-tunnel <hash>

# 启动隧道
docker exec -it autotunnel-autossh-1 autossh-cli start-tunnel <hash>

# 查看状态
docker exec -it autotunnel-autossh-1 autossh-cli status
```

## HTTP API 接口

### API 端点列表

| 方法 | 端点            | 描述                   |
| ---- | --------------- | ---------------------- |
| GET  | `/list`         | 获取所有配置的隧道列表 |
| GET  | `/status`       | 获取所有隧道的运行状态 |
| POST | `/start`        | 启动所有隧道           |
| POST | `/stop`         | 停止所有隧道           |
| POST | `/start/<hash>` | 启动指定的隧道         |
| POST | `/stop/<hash>`  | 停止指定的隧道         |

### API 使用示例

```bash
# 获取隧道列表
curl -X GET http://localhost:8080/list

# 获取隧道状态
curl -X GET http://localhost:8080/status

# 启动特定隧道
curl -X POST http://localhost:8080/start/7b840f8344679dff5df893eefd245043

# 停止特定隧道
curl -X POST http://localhost:8080/stop/7b840f8344679dff5df893eefd245043

# 停止所有隧道
curl -X POST http://localhost:8080/stop

# 启动所有隧道
curl -X POST http://localhost:8080/start
```

### API 响应格式

#### 成功响应

```json
{
  "status": "success",
  "tunnel_hash": "7b840f8344679dff5df893eefd245043",
  "output": "Tunnel started successfully"
}
```

#### 错误响应

```json
{
  "error": "Tunnel hash required"
}
```

## 隧道哈希值

每个隧道都有一个唯一的哈希值（MD5），用于标识和控制。哈希值基于以下参数计算：

- 隧道名称
- 远程主机
- 远程端口
- 本地端口
- 隧道方向
- 交互模式

您可以通过 `autossh-cli list` 命令查看每个隧道的哈希值。

## 状态管理

### 隧道状态

- **RUNNING**：隧道正在运行
- **STOPPED**：隧道已停止
- **STARTING**：隧道正在启动
- **DEAD**：隧道进程异常终止

### 状态文件

隧道状态保存在 `/tmp/autossh_tunnels.state` 文件中，包含：

- 隧道配置信息
- 进程 ID (PID)
- 运行状态

### 日志文件

每个隧道的日志保存在独立文件中：

```
/tmp/autossh-logs/tunnel-<hash>.log
```

查看特定隧道的日志：

```bash
# 查看所有隧道日志
autossh-cli logs

# 查看特定隧道日志
autossh-cli logs <hash>
```

## 高级功能

### 智能重启

当配置文件更新时，系统会：

1. 检测配置变化
2. 停止已删除的隧道
3. 启动新增的隧道
4. 保持未变化的隧道继续运行

### 交互式隧道

标记为 `interactive: true` 的隧道需要手动输入密码，不会自动启动。这些隧道在列表中显示为 `INTERACTIVE` 状态。

### 批量操作

```bash
# 启动所有非交互式隧道
autossh-cli start

# 使用完全重启模式（停止所有隧道后重新启动）
autossh-cli start --full

# 停止所有隧道
autossh-cli stop
```

## 故障排除

### 常见问题

#### 1. 隧道无法启动

检查：

- SSH 配置文件 `~/.ssh/config` 是否正确
- SSH 密钥权限是否正确（600）
- 远程主机是否可访问
- 端口是否被占用

#### 2. 隧道自动停止

可能原因：

- 网络连接不稳定
- SSH 服务器配置问题
- 认证失败

查看日志获取详细信息：

```bash
autossh-cli logs <hash>
```

#### 3. 状态不同步

如果状态显示不正确，可以清理死进程：

```bash
autossh-cli cleanup
```

### 调试命令

```bash
# 验证配置文件
autossh-cli validate

# 显示配置路径
autossh-cli config

# 解析配置文件
autossh-cli parse

# 查看统计信息
autossh-cli stats
```

## 配置示例

### config.yaml

```yaml
tunnels:
  # 远程到本地隧道
  - name: "database"
    remote_host: "user@db-server"
    remote_port: "3306"
    local_port: "13306"
    direction: "remote_to_local"
    interactive: false

  # 本地到远程隧道
  - name: "web-service"
    remote_host: "user@gateway"
    remote_port: "8080"
    local_port: "3000"
    direction: "local_to_remote"
    interactive: false

  # 需要交互认证的隧道
  - name: "secure-tunnel"
    remote_host: "admin@secure-host"
    remote_port: "22"
    local_port: "2222"
    direction: "remote_to_local"
    interactive: true
```

## 安全建议

1. **使用 SSH 密钥认证**：避免使用密码认证
2. **限制端口绑定**：使用具体的 IP 地址而不是 0.0.0.0
3. **定期更新**：保持 SSH 客户端和服务器更新
4. **监控日志**：定期检查隧道日志发现异常
5. **最小权限原则**：只开放必要的端口和服务

## 相关链接

- [项目主页](https://github.com/Oaklight/autossh-tunnel-dockerized)
- [Docker Hub](https://hub.docker.com/r/oaklight/autossh-tunnel)
- [SSH 配置指南](../ssh-config.md)
