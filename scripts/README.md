# 脚本目录 / Scripts Directory

这个目录包含 autossh 隧道项目的核心运行脚本。

## 脚本说明

### start_autossh.sh

主启动脚本，负责：
- 解析配置文件 (`/etc/autossh/config/config.yaml`)
- 为每个隧道配置启动 autossh 进程
- 生成唯一的日志 ID
- 创建日志文件并写入配置头部信息
- **自动检查并压缩超过阈值的日志文件**

**自动压缩功能**：
- 每次启动隧道前自动检查日志文件大小
- 如果超过 `LOG_SIZE` 阈值（默认 100KB），自动压缩
- 保留配置头部信息块
- 压缩文件命名：`tunnel_<log_id>_<timestamp>.log.gz`

**环境变量**：
- `LOG_SIZE`: 日志压缩阈值（字节），默认 102400 (100KB)

### spinoff_monitor.sh

配置文件监控脚本，负责：
- 监控 `/etc/autossh/config/` 目录的变化
- 检测到配置文件修改、创建或删除时自动重启 autossh
- 使用 `inotifywait` 实现实时监控

### compress_logs.sh

独立的日志压缩工具脚本，可以：
- 手动运行以压缩所有超过阈值的日志文件
- 扫描 `/var/log/autossh/` 目录下的所有活动日志

**注意**：通常不需要手动运行此脚本，因为 `start_autossh.sh` 会在每次启动隧道时自动检查并压缩日志。

**使用方法**：
```bash
# 在容器内手动运行
/scripts/compress_logs.sh

# 或从主机运行
docker compose exec autossh /scripts/compress_logs.sh

# 使用自定义阈值
docker compose exec autossh sh -c "LOG_SIZE=204800 /scripts/compress_logs.sh"
```

## 脚本位置

在容器内，所有脚本位于 `/scripts/` 目录：
- `/scripts/start_autossh.sh`
- `/scripts/spinoff_monitor.sh`
- `/scripts/compress_logs.sh`

## 相关目录

- `/var/log/autossh/` - 日志文件存储位置
- `/etc/autossh/config/` - 配置文件位置

---

# Scripts Directory

This directory contains the core runtime scripts for the autossh tunnel project.

## Script Descriptions

### start_autossh.sh

Main startup script responsible for:
- Parsing configuration file (`/etc/autossh/config/config.yaml`)
- Starting autossh processes for each tunnel configuration
- Generating unique log IDs
- Creating log files with configuration headers
- **Automatically checking and compressing logs exceeding threshold**

**Auto-compression feature**:
- Automatically checks log file size before starting each tunnel
- Compresses if exceeds `LOG_SIZE` threshold (default 100KB)
- Preserves configuration header block
- Compressed file naming: `tunnel_<log_id>_<timestamp>.log.gz`

**Environment Variables**:
- `LOG_SIZE`: Log compression threshold (bytes), default 102400 (100KB)

### spinoff_monitor.sh

Configuration file monitoring script responsible for:
- Monitoring changes in `/etc/autossh/config/` directory
- Automatically restarting autossh when configuration files are modified, created, or deleted
- Using `inotifywait` for real-time monitoring

### compress_logs.sh

Standalone log compression utility script that can:
- Be run manually to compress all logs exceeding threshold
- Scan all active logs in `/var/log/autossh/` directory

**Note**: You typically don't need to run this script manually, as `start_autossh.sh` automatically checks and compresses logs when starting tunnels.

**Usage**:
```bash
# Run manually inside container
/scripts/compress_logs.sh

# Or run from host
docker compose exec autossh /scripts/compress_logs.sh

# Use custom threshold
docker compose exec autossh sh -c "LOG_SIZE=204800 /scripts/compress_logs.sh"
```

## Script Locations

Inside the container, all scripts are located in `/scripts/`:
- `/scripts/start_autossh.sh`
- `/scripts/spinoff_monitor.sh`
- `/scripts/compress_logs.sh`

## Related Directories

- `/var/log/autossh/` - Log file storage location
- `/etc/autossh/config/` - Configuration file location

## Development

For testing and development, see the `tests/` directory in the project root (not included in Docker image).