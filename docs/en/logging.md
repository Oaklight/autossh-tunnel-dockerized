# SSH Tunnel Logging System

This project creates separate log files for each SSH tunnel connection, making it easy to monitor and debug.

## Logging Features

- **Separate Log Files**: Each tunnel configuration has its own log file
- **Content-Based Log ID**: Uses MD5 hash (first 8 characters) of configuration content as log file identifier
- **Persistent Storage**: Log files are stored in the host's `./logs` directory
- **Detailed Information**: Each log file contains tunnel configuration details and runtime output
- **Automatic Compression**: Automatically compresses log files when they exceed a specified size, preserving the header block

## Log File Naming Convention

Log file naming format: `tunnel_<log_id>.log`

Where `<log_id>` is an MD5 hash (first 8 characters) generated from the following configuration content:

- `remote_host`
- `remote_port`
- `local_port`
- `direction`

### Example

For the following configuration:

```yaml
tunnels:
  - remote_host: "user@remote-host1"
    remote_port: 8000
    local_port: 8001
    direction: remote_to_local
```

The generated log ID might be: `a1b2c3d4`, corresponding to log file: `tunnel_a1b2c3d4.log`

## Log File Location

- **Container Path**: `/var/log/autossh/`
- **Host Path**: `./logs/` (in project root directory)

## Log File Content

Each log file contains:

1. **Header Information**:

   - Log ID
   - Start time
   - Complete tunnel configuration information

2. **Runtime Logs**:
   - SSH connection status
   - autossh output
   - Error messages (if any)

### Log File Example

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

## Viewing Logs

### Method 1: Direct Log File Access

```bash
# List all log files
ls -lh ./logs/

# View specific log file
cat ./logs/tunnel_a1b2c3d4.log

# Monitor logs in real-time
tail -f ./logs/tunnel_a1b2c3d4.log
```

### Method 2: Using Docker Commands

```bash
# Enter container to view logs
docker compose exec autossh sh
ls -lh /var/log/autossh/
cat /var/log/autossh/tunnel_a1b2c3d4.log
```

### Method 3: View All Tunnel Logs

```bash
# View latest content from all log files
tail -n 20 ./logs/*.log

# Monitor all logs in real-time
tail -f ./logs/*.log
```

## Log Compression

### Automatic Compression Feature

The system automatically monitors log file sizes and compresses them when they exceed the threshold:

- **Default Threshold**: 100KB (102400 bytes) - Suitable for keeping recent status for web monitoring
- **Compression Format**: gzip (.gz)
- **Header Preservation**: The original configuration header block is preserved after compression
- **Naming Convention**: `tunnel_<log_id>_<timestamp>.log.gz`

**Note**: 100KB can hold approximately 600-800 recent log entries, sufficient for status monitoring and troubleshooting. Historical logs are compressed and saved.

### Configuring Compression Threshold

You can customize the compression threshold using the `LOG_SIZE` environment variable:

```yaml
# Set in compose.yaml
services:
  autossh:
    environment:
      - LOG_SIZE=204800  # 200KB
```

Or when starting the container:

```bash
docker compose run -e LOG_SIZE=204800 autossh  # 200KB
```

**Recommended Values**:
- **100KB (default)**: Suitable for status monitoring, keeps recent 600-800 entries
- **200KB**: When more history is needed
- **500KB**: For debugging scenarios requiring detailed logs

### Compressed Log Files

Example of compressed log file:

```
tunnel_a1b2c3d4_20260114_143000.log.gz
```

Where:
- `a1b2c3d4`: Log ID
- `20260114_143000`: Compression timestamp (YYYYMMDD_HHMMSS)

### Viewing Compressed Logs

```bash
# View compressed log content
zcat ./logs/tunnel_a1b2c3d4_20260114_143000.log.gz

# Search within compressed logs
zgrep "error" ./logs/tunnel_a1b2c3d4_20260114_143000.log.gz

# Decompress log file
gunzip ./logs/tunnel_a1b2c3d4_20260114_143000.log.gz
```

### Active Log After Compression

After compression, the original log file is reset and contains only:
1. Original configuration header block
2. Compression notification
3. Subsequent new log entries

Example:

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

## Log Management

### Cleaning Old Logs

Log files will grow continuously, regular cleanup is recommended:

```bash
# Clear all log content but keep files
truncate -s 0 ./logs/*.log

# Delete all log files
rm ./logs/*.log

# Delete logs older than 7 days
find ./logs -name "tunnel_*.log" -mtime +7 -delete

# Clean compressed logs (keep last 7 days)
find ./logs -name "tunnel_*_*.log.gz" -mtime +7 -delete

# Clean all compressed logs
rm ./logs/tunnel_*_*.log.gz
```

### Log Rotation

The system has built-in automatic log compression that triggers when files exceed the threshold. For additional log management, consider:

1. Using `logrotate` tool to manage compressed files
2. Writing scheduled tasks to clean old compressed logs
3. Using log collection systems (such as ELK, Loki, etc.)

## Troubleshooting

### Log Files Not Found

1. Confirm `./logs` directory exists:

   ```bash
   mkdir -p ./logs
   ```

2. Check Docker volume mounts:

   ```bash
   docker compose config | grep -A 5 volumes
   ```

3. Check directory permissions:
   ```bash
   ls -ld ./logs
   # Should allow container user (PUID/PGID) to write
   ```

### Empty Log Files

1. Check if tunnels started successfully:

   ```bash
   docker compose logs autossh
   ```

2. Verify configuration file format:

   ```bash
   cat config/config.yaml
   ```

3. Check log directory permissions inside container:
   ```bash
   docker compose exec autossh ls -ld /var/log/autossh
   ```

### Determining Log ID

To manually calculate the log ID for a configuration:

```bash
# Example configuration
remote_host="user@remote-host1"
remote_port="8000"
local_port="8001"
direction="remote_to_local"

# Calculate log ID
echo -n "${remote_host}:${remote_port}:${local_port}:${direction}" | md5sum | cut -c1-8
```

## Best Practices

1. **Regular Log Checks**: Monitor tunnel connection status
2. **Set Appropriate Compression Threshold**: Adjust `LOG_SIZE` based on actual needs, balancing disk space and log integrity
3. **Regular Cleanup of Compressed Logs**: Delete old compressed files that are no longer needed
4. **Backup Important Logs**: Backup compressed logs that might be needed before deletion
5. **Use Log IDs**: Quickly locate specific tunnel issues through log IDs
6. **Monitor Disk Space**: Ensure log directory has sufficient space for active logs and compressed files

## Relationship with Configuration Changes

- When configuration content changes, a new log ID and new log file will be generated
- Old log files are retained and not automatically deleted
- This allows tracking of configuration change history

## Integration with Monitoring Systems

Log files can be easily integrated into various monitoring systems:

- **Prometheus + Loki**: Collect and query logs
- **ELK Stack**: Elasticsearch + Logstash + Kibana
- **Grafana**: Visualize logs and metrics
- **Simple Scripts**: Analyze logs using `grep`, `awk`, and other tools
