# SSH隧道生命周期管理 / SSH Tunnel Lifecycle Management

## 中文

### 隧道生命周期

#### 1. 容器启动

- **清理旧状态**：删除 `/tmp/autossh_tunnels.state` 确保状态准确
- **创建基础设施**：
  - 创建状态文件（权限666）
  - 创建日志目录 `/tmp/autossh-logs`（权限777）
  - 设置正确的所有权（myuser:mygroup）

#### 2. 启动单个隧道

```bash
autossh-cli start-tunnel <hash>
# 或
curl -X POST http://localhost:8080/start/<hash>
```

- 检查隧道是否已运行
- 启动autossh进程
- **写入状态文件**：记录PID和配置信息
- **创建日志文件**：`/tmp/autossh-logs/tunnel-<hash>.log`

#### 3. 停止单个隧道

```bash
autossh-cli stop-tunnel <hash>
# 或
curl -X POST http://localhost:8080/stop/<hash>
```

- 停止进程（先SIGTERM，后SIGKILL）
- **删除状态entry**：从状态文件中移除该隧道记录
- **删除日志文件**：清理对应的日志文件

#### 4. 停止所有隧道

```bash
autossh-cli stop
# 或
curl -X POST http://localhost:8080/stop
```

- 停止所有隧道进程
- **清空状态文件**：删除所有记录
- **删除所有日志**：清理整个日志目录

### 文件管理策略

| 操作     | 状态文件         | 日志文件     |
| -------- | ---------------- | ------------ |
| 容器启动 | 清空（重新创建） | 保留目录结构 |
| 启动隧道 | 添加entry        | 创建新日志   |
| 停止隧道 | 删除对应entry    | 删除对应日志 |
| 停止服务 | 清空整个文件     | 删除所有日志 |

---

## English

### Tunnel Lifecycle

#### 1. Container Startup

- **Clean old state**: Remove `/tmp/autossh_tunnels.state` to ensure accuracy
- **Create infrastructure**:
  - Create state file (permission 666)
  - Create log directory `/tmp/autossh-logs` (permission 777)
  - Set correct ownership (myuser:mygroup)

#### 2. Start Single Tunnel

```bash
autossh-cli start-tunnel <hash>
# or
curl -X POST http://localhost:8080/start/<hash>
```

- Check if tunnel is already running
- Start autossh process
- **Write to state file**: Record PID and configuration
- **Create log file**: `/tmp/autossh-logs/tunnel-<hash>.log`

#### 3. Stop Single Tunnel

```bash
autossh-cli stop-tunnel <hash>
# or
curl -X POST http://localhost:8080/stop/<hash>
```

- Stop process (SIGTERM first, then SIGKILL)
- **Remove state entry**: Remove tunnel record from state file
- **Delete log file**: Clean up corresponding log file

#### 4. Stop All Tunnels

```bash
autossh-cli stop
# or
curl -X POST http://localhost:8080/stop
```

- Stop all tunnel processes
- **Clear state file**: Remove all records
- **Delete all logs**: Clean up entire log directory

### File Management Strategy

| Operation       | State File        | Log Files                |
| --------------- | ----------------- | ------------------------ |
| Container Start | Clear (recreate)  | Keep directory structure |
| Start Tunnel    | Add entry         | Create new log           |
| Stop Tunnel     | Remove entry      | Delete corresponding log |
| Stop Service    | Clear entire file | Delete all logs          |

---

## 技术细节 / Technical Details

### State File Format

```
remote_host<TAB>remote_port<TAB>local_port<TAB>direction<TAB>name<TAB>hash<TAB>pid
```

### Log File Naming

```
/tmp/autossh-logs/tunnel-<hash>.log
```

### Permissions

- State file: 666 (rw-rw-rw-)
- Log directory: 777 (rwxrwxrwx)
- Log files: Created by process owner

### Cleanup Rules

1. **Individual tunnel stop**: Clean only that tunnel's resources
2. **Service stop**: Clean all resources
3. **Container restart**: Start fresh with empty state
4. **Dead process cleanup**: Remove orphaned entries and logs
