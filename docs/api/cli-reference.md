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

## 隧道控制命令

### 启动单个隧道

通过哈希值启动特定隧道：

```bash
autossh-cli start-tunnel <哈希值>
```

**示例：**

```bash
$ autossh-cli start-tunnel 7b840f8344679dff5df893eefd245043
INFO: Starting tunnel: 7b840f8344679dff5df893eefd245043
[2026-01-25 12:03:23] [INFO] [STATE] Starting tunnel: done-hub (7b840f8344679dff5df893eefd245043)
SUCCESS: Tunnel started successfully: 7b840f8344679dff5df893eefd245043
```

### 停止单个隧道

通过哈希值停止特定隧道：

```bash
autossh-cli stop-tunnel <哈希值>
```

**示例：**

```bash
$ autossh-cli stop-tunnel 7b840f8344679dff5df893eefd245043
INFO: Stopping tunnel: 7b840f8344679dff5df893eefd245043
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

# 查看特定隧道日志
autossh-cli logs <哈希值>
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
| `PUID` | 文件权限的用户 ID | `1000` |
| `PGID` | 文件权限的组 ID | `1000` |
| `AUTOSSH_GATETIME` | Autossh 网关时间 | `0` |