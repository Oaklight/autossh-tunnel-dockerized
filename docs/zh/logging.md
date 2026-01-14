# SSH 隧道日志系统

本项目为每个 SSH 隧道连接创建独立的日志文件，便于监控和调试。

## 日志功能特性

- **独立日志文件**：每个隧道配置都有自己的日志文件
- **基于内容的日志 ID**：使用配置内容的 MD5 哈希值（前 8 位）作为日志文件标识
- **持久化存储**：日志文件存储在主机的 `./logs` 目录中
- **详细信息**：每个日志文件包含隧道配置详情和运行时输出

## 日志文件命名规则

日志文件命名格式：`tunnel_<log_id>.log`

其中 `<log_id>` 是基于以下配置内容生成的 MD5 哈希值（前 8 位）：

- `remote_host`
- `remote_port`
- `local_port`
- `direction`

### 示例

对于以下配置：

```yaml
tunnels:
  - remote_host: "user@remote-host1"
    remote_port: 8000
    local_port: 8001
    direction: remote_to_local
```

生成的日志 ID 可能是：`a1b2c3d4`，对应的日志文件为：`tunnel_a1b2c3d4.log`

## 日志文件位置

- **容器内路径**：`/var/log/autossh/`
- **主机路径**：`./logs/`（项目根目录下）

## 日志文件内容

每个日志文件包含：

1. **头部信息**：

   - 日志 ID
   - 启动时间
   - 完整的隧道配置信息

2. **运行时日志**：
   - SSH 连接状态
   - autossh 输出
   - 错误信息（如果有）

### 日志文件示例

```
=========================================
Tunnel Log ID: a1b2c3d4
Started at: 2026-01-14 14:30:00
Configuration:
  Remote Host: user@remote-host1
  Remote Port: 8000
  Local Port: 8001
  Direction: remote_to_local
=========================================
[2026-01-14 14:30:00] Starting tunnel (remote to local): localhost:8001 <- user@remote-host1:8000
```

## 查看日志

### 方法 1：直接查看日志文件

```bash
# 列出所有日志文件
ls -lh ./logs/

# 查看特定日志文件
cat ./logs/tunnel_a1b2c3d4.log

# 实时监控日志
tail -f ./logs/tunnel_a1b2c3d4.log
```

### 方法 2：使用 Docker 命令

```bash
# 进入容器查看日志
docker compose exec autossh sh
ls -lh /var/log/autossh/
cat /var/log/autossh/tunnel_a1b2c3d4.log
```

### 方法 3：查看所有隧道日志

```bash
# 查看所有日志文件的最新内容
tail -n 20 ./logs/*.log

# 实时监控所有日志
tail -f ./logs/*.log
```

## 日志管理

### 清理旧日志

日志文件会持续增长，建议定期清理：

```bash
# 清空所有日志内容但保留文件
truncate -s 0 ./logs/*.log

# 删除所有日志文件
rm ./logs/*.log

# 删除7天前的日志
find ./logs -name "tunnel_*.log" -mtime +7 -delete
```

### 日志轮转

如果需要自动日志轮转，可以考虑：

1. 使用 `logrotate` 工具
2. 编写定时任务清理旧日志
3. 使用日志收集系统（如 ELK、Loki 等）

## 故障排除

### 找不到日志文件

1. 确认 `./logs` 目录存在：

   ```bash
   mkdir -p ./logs
   ```

2. 检查 Docker 卷挂载：

   ```bash
   docker compose config | grep -A 5 volumes
   ```

3. 检查目录权限：
   ```bash
   ls -ld ./logs
   # 应该允许容器用户（PUID/PGID）写入
   ```

### 日志文件为空

1. 检查隧道是否成功启动：

   ```bash
   docker compose logs autossh
   ```

2. 验证配置文件格式：

   ```bash
   cat config/config.yaml
   ```

3. 检查容器内的日志目录权限：
   ```bash
   docker compose exec autossh ls -ld /var/log/autossh
   ```

### 确定日志 ID

如果需要手动计算某个配置的日志 ID：

```bash
# 示例配置
remote_host="user@remote-host1"
remote_port="8000"
local_port="8001"
direction="remote_to_local"

# 计算日志ID
echo -n "${remote_host}:${remote_port}:${local_port}:${direction}" | md5sum | cut -c1-8
```

## 最佳实践

1. **定期检查日志**：监控隧道连接状态
2. **设置日志轮转**：避免日志文件过大
3. **备份重要日志**：在删除前备份可能需要的日志
4. **使用日志 ID**：通过日志 ID 快速定位特定隧道的问题
5. **监控磁盘空间**：确保日志目录有足够的空间

## 与配置变更的关系

- 当配置内容改变时，会生成新的日志 ID 和新的日志文件
- 旧的日志文件会保留，不会自动删除
- 这样可以追踪配置变更历史

## 集成到监控系统

日志文件可以轻松集成到各种监控系统：

- **Prometheus + Loki**：收集和查询日志
- **ELK Stack**：Elasticsearch + Logstash + Kibana
- **Grafana**：可视化日志和指标
- **简单脚本**：使用 `grep`、`awk` 等工具分析日志
