# Configuration File Monitoring Fix

## Problem Description

In previous versions, when users manually edited the mounted `config.yaml` file outside the container, the configuration monitoring might fail to detect file changes, causing tunnel configurations not to reload automatically.

## Root Cause

The issue stems from different editors modifying files in different ways:

1. **Direct Modification Editors** (e.g., vim, nano)

   - Directly modify file content
   - Trigger `modify` event
   - Usually detected correctly

2. **Replacement Editors** (e.g., VSCode, some IDEs)

   - Create temporary file first
   - Delete original file
   - Rename temporary file to original filename
   - Trigger `delete` + `create` or `moved_to` events
   - May not trigger `modify` event

3. **Docker Volume Mount Impact**
   - inode changes may not propagate correctly to container
   - File descriptors may become invalid after file replacement

## Solution

### Changes Made

In `scripts/spinoff_monitor.sh`:

1. **Monitor Directory Instead of File**

   - Monitor `/etc/autossh/config` directory
   - Avoid monitoring failure due to file replacement

2. **Expand Monitored Event Types**

   ```bash
   inotifywait -e modify,create,move,delete,moved_to,moved_from,close_write,attrib
   ```

3. **Filter Target File**
   ```bash
   | grep -q "config.yaml"
   ```
   - Only respond to `config.yaml` changes
   - Ignore changes to other files in directory

### Technical Details

| Event         | Trigger Condition                                     | Purpose                                        |
| ------------- | ----------------------------------------------------- | ---------------------------------------------- |
| `modify`      | File content is modified                              | Capture direct edits                           |
| `create`      | A new file is created                                 | Capture the creation phase of file replacement |
| `delete`      | A file is deleted                                     | Capture the deletion phase of file replacement |
| `moved_to`    | A file is moved into the monitored directory          | Capture `mv` operations                        |
| `moved_from`  | A file is moved out of the monitored directory        | Capture `mv` operations                        |
| `close_write` | A file opened for writing is closed                   | Capture editor save operations                 |
| `attrib`      | File attributes (permissions, timestamp, etc.) change | Capture `touch` and other operations           |

### Why Monitor the Directory Instead of the File

When monitoring a file directly, if the file is deleted and recreated (like the save behavior of VSCode), the file descriptor monitored by `inotifywait` becomes invalid, and subsequent changes cannot be detected.

Monitoring the directory allows:

- Continuous monitoring of all events in the directory
- Unaffected by individual file deletion/creation
- Filtering with `grep` to process events for the target file only

### Testing Method

Use the provided test script to verify monitoring functionality:

```bash
./tests/test_config_monitor.sh
```

The test script simulates three different file modification methods:

1. Direct append (simulating vim/nano)
2. File replacement (simulating VSCode)
3. Attribute change (touch command)

### Verification Steps

1. Start container:

   ```bash
   docker compose up -d
   ```

2. View monitoring logs:

   ```bash
   docker compose logs -f autossh | grep "Configuration file"
   ```

3. Edit configuration file on host:

   ```bash
   vim config/config.yaml  # or use your preferred editor
   ```

4. After saving, you should see output similar to:
   ```
   Detected configuration file changes, analyzing differences...
   ```

## Log Management

### Log Handling When Tunnels Are Removed

When a tunnel is removed from configuration, the system automatically:

1. **Record Removal Event**: Add final entry to log file
2. **Compress Archive**: Compress log file to `.gz` format
3. **Add Timestamp**: Archive filename includes removal time in format `tunnel_<log_id>.log.removed_YYYYMMDD_HHMMSS.gz`
4. **Clean Original File**: Delete original log file

Example archive filename:

```
tunnel_a1b2c3d4.log.removed_20260116_193045.gz
```

This allows:

- Retain historical records for auditing
- Avoid log file accumulation taking up space
- Clearly identify removed tunnels

### Viewing Archived Logs

```bash
# List all archived logs
ls -lh ./logs/*.removed_*.gz

# View archived log content
zcat ./logs/tunnel_a1b2c3d4.log.removed_20260116_193045.gz

# Search archived logs
zgrep "error" ./logs/*.removed_*.gz
```

## Related Files

- [`scripts/spinoff_monitor.sh`](../../scripts/spinoff_monitor.sh) - Configuration monitoring script
- [`tests/test_config_monitor.sh`](../../tests/test_config_monitor.sh) - Test script
- [`entrypoint.sh`](../../entrypoint.sh) - Container entry script

## Version Comparison

### v1.6.2 (Working)

```bash
inotifywait -r -e modify,create,delete /etc/autossh/config
```

### Current Version (Fixed)

```bash
inotifywait -e modify,create,move,delete,moved_to,moved_from,close_write,attrib "$(dirname "$CONFIG_FILE")" 2>/dev/null | grep -q "config.yaml"
```

Main improvements:

1. Added more event types (`move`, `moved_to`, `moved_from`, `close_write`, `attrib`)
2. Added filename filtering (`grep -q "config.yaml"`)
3. Suppressed error output (`2>/dev/null`)
