# SSH 隧道日志系统

本项目为每个 SSH 隧道连接创建独立的日志文件，便于监控和调试。

## 日志功能特性

- **独立日志文件**：每个隧道配置都有自己的日志文件
- **基于内容的日志 ID**：使用配置内容的 MD5 哈希值（前 8 位）作为日志文件标识
- **持久化存储**：日志文件存储在主机的 `./logs` 目录中
- **详细信息**：每个日志文件包含隧道配置详情和运行时输出
- **自动压缩**：当日志文件超过指定大小时自动压缩，保留头部标记块

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

## 日志压缩

### 自动压缩功能

系统会自动监控日志文件大小，当文件超过设定阈值时自动进行压缩：

- **默认阈值**：100KB (102400 字节) - 适合保留最近状态用于网页监控
- **压缩格式**：gzip (.gz)
- **头部保留**：压缩后会保留原始的配置头部信息块
- **命名规则**：`tunnel_<log_id>_<timestamp>.log.gz`

**注意**：100KB 大约可以保留 600-800 条最近的日志记录，足够用于状态监控和问题排查。历史日志会被压缩保存。

### 配置压缩阈值

可以通过环境变量 `LOG_SIZE` 自定义压缩阈值：

```yaml
# 在 compose.yaml 中设置
services:
  autossh:
    environment:
      - LOG_SIZE=204800 # 200KB
```

或在启动容器时设置：

```bash
docker compose run -e LOG_SIZE=204800 autossh  # 200KB
```

**推荐值**：

- **100KB (默认)**：适合状态监控，保留最近 600-800 条记录
- **200KB**：需要更多历史记录时
- **500KB**：调试场景，需要详细日志

### 压缩后的日志文件

压缩后的日志文件示例：

```
tunnel_a1b2c3d4_20260114_143000.log.gz
```

其中：

- `a1b2c3d4`：日志 ID
- `20260114_143000`：压缩时间戳（年月日\_时分秒）

### 查看压缩日志

```bash
# 查看压缩日志内容
zcat ./logs/tunnel_a1b2c3d4_20260114_143000.log.gz

# 搜索压缩日志中的内容
zgrep "error" ./logs/tunnel_a1b2c3d4_20260114_143000.log.gz

# 解压缩日志文件
gunzip ./logs/tunnel_a1b2c3d4_20260114_143000.log.gz
```

### 压缩后的活动日志

压缩后，原日志文件会被重置，仅保留：

1. 原始配置头部信息块
2. 压缩通知信息
3. 后续新的日志条目

示例：

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
[2026-01-14 15:45:00] Previous log compressed to: tunnel_a1b2c3d4_20260114_154500.log.gz
[2026-01-14 15:45:00] Log rotation performed due to size threshold (102400 bytes)
=========================================
[2026-01-14 15:45:01] Starting tunnel (remote to local): localhost:8001 <- user@remote-host1:8000
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

# 清理压缩日志（保留最近7天）
find ./logs -name "tunnel_*_*.log.gz" -mtime +7 -delete

# 清理所有压缩日志
rm ./logs/tunnel_*_*.log.gz
```

### 日志轮转

系统已内置自动日志压缩功能，当日志文件超过阈值时会自动压缩。如需额外的日志管理，可以考虑：

1. 使用 `logrotate` 工具管理压缩后的文件
2. 编写定时任务清理旧的压缩日志
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
2. **合理设置压缩阈值**：根据实际需求调整 `LOG_SIZE`，平衡磁盘空间和日志完整性
3. **定期清理压缩日志**：删除不再需要的旧压缩文件
4. **备份重要日志**：在删除前备份可能需要的压缩日志
5. **使用日志 ID**：通过日志 ID 快速定位特定隧道的问题
6. **监控磁盘空间**：确保日志目录有足够的空间存储活动日志和压缩文件

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
