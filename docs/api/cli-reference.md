# CLI 参考

`autossh-cli` 命令行工具提供全面的隧道管理功能。

!!! important "仅限 Docker 容器内使用"
    `autossh-cli` 工具设计为在 **Docker 容器内**运行。它不是可以安装在宿主机系统上的独立软件包。所有 CLI 命令都应使用 `docker exec` 执行。

## 使用 CLI

所有命令都应以 `docker exec` 为前缀：

```bash
docker exec -it <容器名称> autossh-cli <命令>
```

例如：
```bash
docker exec -it autotunnel-autossh-1 autossh-cli list
```

## 基本命令

### 列出隧道

列出所有配置的隧道及其详细信息：

```bash
autossh-cli list
```

**示例输出：**

```
Configured Tunnels
  done-hub             NORMAL       0.0.0.0:33001 -> cloud.usa2:127.0.0.1:33000 (7b840f8344679dff5df893eefd245043)
  argo-proxy           INTERACTIVE  44498 -> lambda5:44497 (f55793c77944b6e0cd3a46889422487e)
  dockge@tempest       NORMAL       55001 -> oaklight.tempest:5001 (2ea730e749b28910932f2b141638ade8)
```

### 查看状态

查看所有隧道的运行状态：

```bash
autossh-cli status
```

**示例输出：**

```
Tunnel Status
Managed tunnels:
  done-hub             RUNNING    0.0.0.0:33001 -> cloud.usa2:127.0.0.1:33000 (7b840f8344679dff5df893eefd245043)
  dockge@tempest       RUNNING    55001 -> oaklight.tempest:5001 (2ea730e749b28910932f2b141638ade8)
```

### 显示隧道详情

显示特定隧道的详细信息：

```bash
autossh-cli show-tunnel <哈希值>
```

**示例：**

```bash
autossh-cli show-tunnel 7b840f8344679dff5df893eefd245043
```

## 哈希前缀支持

!!! tip "短哈希前缀"
    所有接受隧道哈希的命令都支持 **短哈希前缀**（最少 8 个字符），类似于 Git 短提交。这使得指定隧道时无需输入完整的 32 字符哈希。

**示例：**

```bash
# 使用 8 字符前缀代替完整哈希
autossh-cli logs 7b840f83
autossh-cli start-tunnel 99acb12f
autossh-cli stop-tunnel fc3cce10
autossh-cli show-tunnel 2ea730e7

# 完整哈希仍然有效
autossh-cli logs 7b840f8344679dff5df893eefd245043
```

**错误处理：**

- **前缀过短**：如果提供少于 8 个字符，将显示错误消息
- **无匹配**：如果没有隧道匹配该前缀，将显示错误并列出可用的日志文件
- **歧义匹配**：如果多个隧道匹配该前缀，将列出所有匹配的哈希并要求使用更多字符

## 隧道控制命令

### 交互式认证

启动需要手动认证（2FA/密码）的交互式隧道：

```bash
autossh-cli auth <哈希值>
```

!!! important "需要用户上下文"
    `auth` 命令必须以 `myuser` 用户身份运行，以正确访问 SSH 配置文件。使用 `docker exec` 时需要添加 `-u myuser` 参数：
    
    ```bash
    docker exec -it -u myuser <容器名称> autossh-cli auth <哈希值>
    ```

**示例：**

```bash
# 启动隧道的交互式认证
$ docker exec -it -u myuser autotunnel-autossh-1 autossh-cli auth c5ed76f1

Interactive Authentication
[2026-02-03 16:44:21] [INFO] [INTERACTIVE] Initializing interactive tunnel: test-2fa-tunnel (c5ed76f1dfccb8959815fbfdc69d582d)

[2026-02-03 16:44:21] [INFO] [INTERACTIVE] Starting SSH session for: test-2fa-tunnel
[2026-02-03 16:44:21] [INFO] [INTERACTIVE] You may be prompted for password or 2FA.
[2026-02-03 16:44:21] [INFO] [INTERACTIVE] The session will go to background upon successful authentication.

[2026-02-03 16:44:21] [INFO] [INTERACTIVE] Direction: remote_to_local (Local Forwarding)
[2026-02-03 16:44:21] [INFO] [INTERACTIVE] Forwarding: localhost:18888 <- test-2fa-server:localhost:8888
(testuser@localhost) Verification code: ******

[2026-02-03 16:44:29] [INFO] [INTERACTIVE] Authentication successful. Tunnel running in background.
[2026-02-03 16:44:30] [INFO] [INTERACTIVE] Tunnel PID: 55085
[2026-02-03 16:44:30] [INFO] [INTERACTIVE] Tunnel registered in state file.

[2026-02-03 16:44:30] [INFO] [INTERACTIVE] Tunnel 'test-2fa-tunnel' is now running.
[2026-02-03 16:44:30] [INFO] [INTERACTIVE] Use 'autossh-cli status' to check tunnel status.
[2026-02-03 16:44:30] [INFO] [INTERACTIVE] Use 'autossh-cli stop-tunnel c5ed76f1dfccb8959815fbfdc69d582d' to stop.
SUCCESS: Interactive tunnel started successfully
```

**主要特性：**

- 使用普通 SSH 而非 autossh，避免自动重连尝试
- 支持键盘交互式认证（2FA、密码提示）
- 认证成功后隧道在后台运行
- 使用 SSH 控制套接字进行 PID 跟踪和管理

!!! note "交互式隧道"
    交互式隧道在配置文件中标记为 `interactive: true`。它们在容器启动时**不会**自动启动。您可以使用 `auth` 命令手动进行认证，或者在配置了 WebSocket 服务器的情况下，通过 Web 面板的 xterm.js 终端弹窗在浏览器中直接完成认证。详见 [Web 面板 - 浏览器内交互式认证](../web-panel.md#浏览器内交互式认证终端弹窗)。

### 启动单个隧道

通过哈希值（或 8+ 字符前缀）启动特定隧道：

```bash
autossh-cli start-tunnel <哈希值>
```

**示例：**

```bash
# 使用完整哈希
$ autossh-cli start-tunnel 7b840f8344679dff5df893eefd245043
INFO: Starting tunnel: 7b840f8344679dff5df893eefd245043
[2026-01-25 12:03:23] [INFO] [STATE] Starting tunnel: done-hub (7b840f8344679dff5df893eefd245043)
SUCCESS: Tunnel started successfully: 7b840f8344679dff5df893eefd245043

# 使用 8 字符前缀
$ autossh-cli start-tunnel 7b840f83
INFO: Starting tunnel: 7b840f83
[2026-01-25 12:03:23] [INFO] [STATE] Starting tunnel: done-hub (7b840f8344679dff5df893eefd245043)
SUCCESS: Tunnel started successfully: 7b840f83
```

### 停止单个隧道

通过哈希值（或 8+ 字符前缀）停止特定隧道：

```bash
autossh-cli stop-tunnel <哈希值>
```

**示例：**

```bash
# 使用 8 字符前缀
$ autossh-cli stop-tunnel 7b840f83
INFO: Stopping tunnel: 7b840f83
[2026-01-25 12:03:14] [INFO] [STATE] Stopping tunnel: done-hub (7b840f8344679dff5df893eefd245043, PID: 186)
```

### 启动所有隧道

启动所有非交互式隧道：

```bash
autossh-cli start
```

使用 `--full` 标志进行完全重启（先停止所有隧道，然后启动）：

```bash
autossh-cli start --full
```

### 停止所有隧道

停止所有运行中的隧道：

```bash
autossh-cli stop
```

## 实用命令

### 查看日志

查看隧道日志：

```bash
# 查看所有隧道日志
autossh-cli logs

# 查看特定隧道日志（支持 8+ 字符前缀）
autossh-cli logs <哈希值>

# 使用前缀的示例
autossh-cli logs 7b840f83
```

### 验证配置

验证配置文件：

```bash
autossh-cli validate
```

### 显示配置路径

显示配置文件路径：

```bash
autossh-cli config
```

### 解析配置

解析并显示配置文件：

```bash
autossh-cli parse
```

### 查看统计信息

显示隧道统计信息：

```bash
autossh-cli stats
```

### 清理死进程

清理孤立的隧道进程：

```bash
autossh-cli cleanup
```

## 命令示例

```bash
# 列出隧道
docker exec -it autotunnel-autossh-1 autossh-cli list

# 停止隧道
docker exec -it autotunnel-autossh-1 autossh-cli stop-tunnel <哈希值>

# 启动隧道
docker exec -it autotunnel-autossh-1 autossh-cli start-tunnel <哈希值>

# 查看状态
docker exec -it autotunnel-autossh-1 autossh-cli status

# 查看日志
docker exec -it autotunnel-autossh-1 autossh-cli logs

# 验证配置
docker exec -it autotunnel-autossh-1 autossh-cli validate
```

## 退出代码

| 代码 | 描述 |
|------|------|
| 0    | 成功 |
| 1    | 错误（一般错误、无效参数、隧道未找到等） |

## 环境变量

| 变量 | 描述 | 默认值 |
|------|------|--------|
| `AUTOSSH_CONFIG_FILE` | 配置文件路径 | `/etc/autossh/config/config.yaml` |
| `SSH_CONFIG_DIR` | SSH 配置目录 | `/home/myuser/.ssh` |
| `AUTOSSH_STATE_FILE` | 状态文件路径 | `/tmp/autossh_tunnels.state` |
| `API_ENABLE` | 启用 HTTP API 服务器 | `false` |
| `API_PORT` | HTTP API 服务器端口 | `8080` |
| `WS_PORT` | WebSocket 服务器（ws-server）监听端口 | `8022` |
| `PUID` | 文件权限的用户 ID | `1000` |
| `PGID` | 文件权限的组 ID | `1000` |
| `AUTOSSH_GATETIME` | Autossh 网关时间 | `0` |