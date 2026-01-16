# 隧道端口占用问题

## 问题描述

### 场景 1：API 重启隧道时

通过 API 重启隧道时，可能会遇到端口被占用的错误，导致多次重试失败：

```
bind [127.0.0.1]:9443: Address in use
channel_setup_fwd_listener_tcpip: cannot listen to port: 9443
Could not request local forwarding.
```

同时可能伴随 API 请求超时：
```
Failed to connect to autossh API: context deadline exceeded (Client.Timeout exceeded while awaiting headers)
```

### 场景 2：容器启动时

容器重启时，即使没有手动触发重连，也可能出现端口占用：

```
[2026-01-16 11:00:30] Starting tunnel (remote to local): localhost:9443 <- cloud.kor1:9443
Connection closed by 198.18.0.81 port 38462
bind [127.0.0.1]:9443: Address in use
channel_setup_fwd_listener_tcpip: cannot listen to port: 9443
Could not request local forwarding.
```

## 根本原因

### API 重启场景

1. **多个相关进程**：autossh 会启动子 SSH 进程，仅杀死 autossh 不够
2. **端口占用未释放**：SSH 进程可能仍在监听端口，导致新连接无法绑定
3. **进程清理不彻底**：只通过 TUNNEL_ID 查找进程可能遗漏某些相关进程
4. **autossh 自动重试机制**：autossh 内置自动重连功能，连接失败时会自动重试多次
5. **HTTP 请求超时**：过长的等待时间导致 API 请求超时

### 容器启动场景

1. **旧进程未清理**：容器重启时，[`start_autossh.sh`](../../scripts/start_autossh.sh) 只是简单 `pkill`，没有等待进程终止
2. **端口未释放**：新隧道启动时，旧进程可能还在占用端口
3. **缺少端口检查**：启动前没有检查端口是否真正可用
4. **时序问题**：`pkill` 和启动新隧道之间的间隔太短（只有 0.5 秒）

## 解决方案

### 方案 1：API 重启（control_api.sh）

在 [`scripts/control_api.sh`](../../scripts/control_api.sh) 的 `restart_tunnel()` 函数中实施了更激进的清理策略：

### 1. 多层次进程清理
```bash
# 杀死 autossh 进程
pkill -9 -f "TUNNEL_ID=${log_id}"

# 杀死占用端口的所有进程
lsof -ti :${actual_local_port} | xargs kill -9

# 杀死连接到远程主机的 SSH 进程
pkill -9 -f "ssh.*${remote_host}"
```

### 2. 缩短等待时间
```bash
# 只等待 2 秒进行基本清理
sleep 2

# 端口检查最多 3 秒
local port_check=0
while [ $port_check -lt 3 ]; do
    if ! netstat -tuln | grep -q ":${actual_local_port} "; then
        break
    fi
    sleep 1
    port_check=$((port_check + 1))
done
```

### 3. 使用 lsof 精确定位
使用 `lsof` 工具直接找到占用端口的进程并强制终止，比依赖进程名更可靠。

### 方案 2：容器启动（start_autossh.sh）

在 [`scripts/start_autossh.sh`](../../scripts/start_autossh.sh) 中增强了启动前的清理逻辑：

#### 1. 彻底清理旧进程
```bash
# 强制杀死所有 autossh 进程
pkill -9 -f "autossh"

# 强制杀死所有 SSH 进程
pkill -9 -f "ssh -"

# 等待进程终止
sleep 2
```

#### 2. 验证进程已终止
```bash
# 最多等待 5 秒确认进程退出
while pgrep -f "autossh" >/dev/null 2>&1 && [ $waited -lt 5 ]; do
    sleep 1
    waited=$((waited + 1))
done
```

#### 3. 清理占用的端口
```bash
# 遍历所有配置的端口
parse_config "$CONFIG_FILE" | while read ...; do
    # 杀死占用端口的进程
    lsof -ti :${actual_port} | xargs kill -9
done
```

#### 4. 最终等待
```bash
# 确保端口完全释放
sleep 2
```

## 工作流程

### API 重启流程

1. **提取端口信息**
   - 处理 `host:port` 格式，提取实际端口号

2. **多层次进程清理**（并行执行，快速清理）
   - 强制杀死 autossh 进程（通过 TUNNEL_ID）
   - 强制杀死占用本地端口的所有进程（通过 lsof）
   - 强制杀死连接到远程主机的 SSH 进程

3. **短暂等待**
   - 等待 2 秒让系统完成清理

4. **快速端口检查**
   - 最多检查 3 秒
   - 使用 `netstat` 验证端口已释放
   - 如果端口已释放则立即继续

5. **启动新隧道**
   - 创建新的日志文件
   - 启动新的 autossh 进程

### 容器启动流程

1. **清理所有旧进程**
   - 强制杀死所有 autossh 进程
   - 强制杀死所有 SSH 进程
   - 等待 2 秒

2. **验证进程终止**
   - 检查 autossh 进程是否还在运行
   - 最多等待 5 秒

3. **清理占用端口**
   - 遍历配置文件中的所有端口
   - 使用 lsof 找到并杀死占用端口的进程

4. **最终等待**
   - 等待 2 秒确保端口释放

5. **启动所有隧道**
   - 为每个隧道创建日志文件
   - 启动 autossh 进程
   - 每个隧道之间间隔 0.5 秒

## 预期行为

修复后，重启隧道应该：
- ✅ 只启动一次新连接
- ✅ 不会出现 "Address in use" 错误
- ✅ 日志中只显示一次启动消息
- ✅ API 请求在合理时间内完成（不超时）
- ✅ 总重启时间控制在 5-6 秒内

## 相关文件

- [`scripts/control_api.sh`](../../scripts/control_api.sh) - API 控制脚本（处理重启请求）
- [`scripts/start_autossh.sh`](../../scripts/start_autossh.sh) - 容器启动脚本（初始化所有隧道）
- [`scripts/start_single_tunnel.sh`](../../scripts/start_single_tunnel.sh) - 单个隧道启动脚本
- [`scripts/tunnel_utils.sh`](../../scripts/tunnel_utils.sh) - 隧道管理工具函数（日志、进程清理）

## 监控建议

如果仍然遇到问题，可以：

1. 检查占用端口的进程：
   ```bash
   lsof -i :9443
   ```

2. 查看特定端口的状态：
   ```bash
   netstat -tuln | grep :9443
   ```

3. 检查所有 SSH 相关进程：
   ```bash
   ps aux | grep ssh
   ```

4. 查看隧道日志：
   ```bash
   tail -f /var/log/autossh/tunnel_*.log
   ```

5. 手动清理端口（如果自动清理失败）：
   ```bash
   # 找到占用端口的进程
   lsof -ti :9443 | xargs kill -9
   ```

## 关键改进点

1. **使用 lsof 而非 pgrep**：更精确地定位占用端口的进程
2. **多重清理策略**：从多个角度清理相关进程，确保彻底
3. **缩短等待时间**：避免 HTTP 请求超时，提高响应速度
4. **强制终止**：直接使用 `kill -9`，不再尝试优雅终止

## 技术细节

### 为什么需要多层清理？

autossh 的进程结构：
```
autossh (父进程)
  └── ssh (子进程，实际建立隧道)
      └── ssh 子进程可能还有其他子进程
```

单纯杀死 autossh 可能不会立即清理所有子进程，特别是当 SSH 连接处于某些特殊状态时。因此需要：
- 通过 TUNNEL_ID 杀死 autossh
- 通过端口号杀死占用端口的进程
- 通过远程主机名杀死相关 SSH 连接

### 为什么使用 kill -9？

在重启场景下，我们需要：
- **快速响应**：避免 API 超时
- **彻底清理**：确保端口释放
- **可靠性**：不依赖进程的优雅退出逻辑

`kill -9` (SIGKILL) 是不可忽略的信号，能确保进程立即终止。