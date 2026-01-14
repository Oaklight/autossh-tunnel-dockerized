# SSH Tunnel Logging System

This project creates separate log files for each SSH tunnel connection, making it easy to monitor and debug.

## Logging Features

- **Separate Log Files**: Each tunnel configuration has its own log file
- **Content-Based Log ID**: Uses MD5 hash (first 8 characters) of configuration content as log file identifier
- **Persistent Storage**: Log files are stored in the host's `./logs` directory
- **Detailed Information**: Each log file contains tunnel configuration details and runtime output

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
```

### Log Rotation

If automatic log rotation is needed, consider:

1. Using `logrotate` tool
2. Writing scheduled tasks to clean old logs
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
2. **Set Up Log Rotation**: Avoid log files becoming too large
3. **Backup Important Logs**: Backup logs that might be needed before deletion
4. **Use Log IDs**: Quickly locate specific tunnel issues through log IDs
5. **Monitor Disk Space**: Ensure log directory has sufficient space

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
