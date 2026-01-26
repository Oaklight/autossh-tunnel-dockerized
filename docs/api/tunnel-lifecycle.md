# 隧道生命周期管理

本文档描述了 SSH 隧道在整个生命周期中的管理方式，包括启动、关闭和状态管理。

## 隧道状态

每个隧道可以处于以下状态之一：

| 状态 | 描述 |
|------|------|
| **RUNNING** | 隧道处于活动状态并已连接 |
| **STOPPED** | 隧道未运行 |
| **STARTING** | 隧道正在启动过程中 |
| **DEAD** | 隧道进程异常终止 |
| **INTERACTIVE** | 隧道需要手动输入密码 |

## 生命周期阶段

### 1. 容器启动

当容器启动时：

- **清理旧状态**：删除 `/tmp/autossh_tunnels.state` 确保状态准确
- **创建基础设施**：
  - 创建状态文件（权限 666）
  - 创建日志目录 `/tmp/autossh-logs`（权限 777）
  - 设置正确的所有权（myuser:mygroup）

### 2. 启动单个隧道

```bash
autossh-cli start-tunnel <哈希值>
# 或
curl -X POST http://localhost:8080/start/<哈希值>
```

处理流程：

1. 检查隧道是否已运行
2. 启动 autossh 进程
3. **写入状态文件**：记录 PID 和配置信息
4. **创建日志文件**：`/tmp/autossh-logs/tunnel-<哈希值>.log`

### 3. 停止单个隧道

```bash
autossh-cli stop-tunnel <哈希值>
# 或
curl -X POST http://localhost:8080/stop/<哈希值>
```

处理流程：

1. 停止进程（先 SIGTERM，后 SIGKILL）
2. **删除状态条目**：从状态文件中移除该隧道记录
3. **删除日志文件**：清理对应的日志文件

### 4. 停止所有隧道

```bash
autossh-cli stop
# 或
curl -X POST http://localhost:8080/stop
```

处理流程：

1. 停止所有隧道进程
2. **清空状态文件**：删除所有记录
3. **删除所有日志**：清理整个日志目录

## 文件管理

### 状态文件

位置：`/tmp/autossh_tunnels.state`

格式：
```
remote_host<TAB>remote_port<TAB>local_port<TAB>direction<TAB>name<TAB>hash<TAB>pid
```

示例：
```
cloud.usa2	127.0.0.1:33000	0.0.0.0:33001	remote_to_local	done-hub	7b840f8344679dff5df893eefd245043	186
```

### 日志文件

位置：`/tmp/autossh-logs/tunnel-<哈希值>.log`

每个隧道都有自己的日志文件，便于隔离调试。

### 文件管理策略

| 操作 | 状态文件 | 日志文件 |
|------|----------|----------|
| 容器启动 | 清空（重新创建） | 保留目录结构 |
| 启动隧道 | 添加条目 | 创建新日志 |
| 停止隧道 | 删除对应条目 | 删除对应日志 |
| 停止服务 | 清空整个文件 | 删除所有日志 |

## 权限

| 文件/目录 | 权限 |
|-----------|------|
| 状态文件 | 666 (rw-rw-rw-) |
| 日志目录 | 777 (rwxrwxrwx) |
| 日志文件 | 由进程所有者创建 |

## 智能重启

当配置文件更新时，系统会：

1. 检测配置变化
2. 停止已删除的隧道
3. 启动新增的隧道
4. 保持未变化的隧道继续运行

这确保了对现有连接的最小干扰。

## 交互式隧道

在配置中标记为 `interactive: true` 的隧道：

- 需要手动输入密码
- 不会自动启动
- 在列表中显示为 `INTERACTIVE` 状态
- 必须在提供凭据后手动启动

## 清理规则

1. **单个隧道停止**：仅清理该隧道的资源
2. **服务停止**：清理所有资源
3. **容器重启**：以空状态重新开始
4. **死进程清理**：删除孤立的条目和日志

使用 `autossh-cli cleanup` 手动清理死进程。

## 监控

### 检查隧道健康状态

```bash
# 查看所有隧道状态
autossh-cli status

# 查看特定隧道日志
autossh-cli logs <哈希值>

# 查看统计信息
autossh-cli stats
```

### 常见问题

#### 隧道持续重启

可能原因：

- 网络不稳定
- SSH 服务器配置问题
- 认证失败

查看日志获取详细信息：

```bash
autossh-cli logs <哈希值>
```

#### 状态不同步

如果状态显示不正确：

```bash
autossh-cli cleanup
```

这将删除孤立的条目并将状态文件与实际运行的进程同步。
