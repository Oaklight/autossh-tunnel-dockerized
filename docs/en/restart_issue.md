# Tunnel Port Occupation Issue

## Problem Description

### Scenario 1: API Restart Tunnel

When restarting tunnels via API, you may encounter port occupation errors, causing multiple retry failures:

```
bind [127.0.0.1]:9443: Address in use
channel_setup_fwd_listener_tcpip: cannot listen to port: 9443
Could not request local forwarding.
```

This may be accompanied by API request timeout:
```
Failed to connect to autossh API: context deadline exceeded (Client.Timeout exceeded while awaiting headers)
```

### Scenario 2: Container Startup

When container restarts, even without manually triggering reconnection, port occupation may occur:

```
[2026-01-16 11:00:30] Starting tunnel (remote to local): localhost:9443 <- cloud.kor1:9443
Connection closed by 198.18.0.81 port 38462
bind [127.0.0.1]:9443: Address in use
channel_setup_fwd_listener_tcpip: cannot listen to port: 9443
Could not request local forwarding.
```

## Root Cause

### API Restart Scenario

1. **Multiple Related Processes**: autossh spawns child SSH processes, killing only autossh is insufficient
2. **Port Not Released**: SSH process may still be listening on port, preventing new connection from binding
3. **Incomplete Process Cleanup**: Finding processes only by TUNNEL_ID may miss some related processes
4. **autossh Auto-retry Mechanism**: autossh has built-in auto-reconnect, retrying multiple times on connection failure
5. **HTTP Request Timeout**: Excessive wait time causes API request timeout

### Container Startup Scenario

1. **Old Processes Not Cleaned**: On container restart, `start_autossh.sh` only does simple `pkill`, doesn't wait for process termination
2. **Port Not Released**: New tunnel starts while old process may still occupy port
3. **Missing Port Check**: No check if port is actually available before startup
4. **Timing Issue**: Interval between `pkill` and starting new tunnel too short (only 0.5 seconds)

## Solution

### Solution 1: API Restart (control_api.sh)

Implemented more aggressive cleanup strategy in `scripts/control_api.sh`'s `restart_tunnel()` function:

#### 1. Multi-level Process Cleanup
```bash
# Kill autossh process
pkill -9 -f "TUNNEL_ID=${log_id}"

# Kill all processes occupying port
lsof -ti :${actual_local_port} | xargs kill -9

# Kill SSH processes connected to remote host
pkill -9 -f "ssh.*${remote_host}"
```

#### 2. Shortened Wait Time
```bash
# Only wait 2 seconds for basic cleanup
sleep 2

# Port check maximum 3 seconds
local port_check=0
while [ $port_check -lt 3 ]; do
    if ! netstat -tuln | grep -q ":${actual_local_port} "; then
        break
    fi
    sleep 1
    port_check=$((port_check + 1))
done
```

#### 3. Use lsof for Precise Targeting
Using `lsof` tool to directly find and forcefully terminate processes occupying ports is more reliable than relying on process names.

### Solution 2: Container Startup (start_autossh.sh)

Enhanced pre-startup cleanup logic in `scripts/start_autossh.sh`:

#### 1. Thorough Old Process Cleanup
```bash
# Force kill all autossh processes
pkill -9 -f "autossh"

# Force kill all SSH processes
pkill -9 -f "ssh -"

# Wait for process termination
sleep 2
```

#### 2. Verify Process Termination
```bash
# Wait maximum 5 seconds to confirm process exit
while pgrep -f "autossh" >/dev/null 2>&1 && [ $waited -lt 5 ]; do
    sleep 1
    waited=$((waited + 1))
done
```

#### 3. Clean Occupied Ports
```bash
# Iterate through all configured ports
parse_config "$CONFIG_FILE" | while read ...; do
    # Kill processes occupying port
    lsof -ti :${actual_port} | xargs kill -9
done
```

#### 4. Final Wait
```bash
# Ensure ports fully released
sleep 2
```

## Expected Behavior

After fix, restarting tunnel should:
- ✅ Only start new connection once
- ✅ No "Address in use" errors
- ✅ Logs show only one startup message
- ✅ API request completes within reasonable time (no timeout)
- ✅ Total restart time controlled within 5-6 seconds

## Related Files

- `scripts/control_api.sh` - API control script (handles restart requests)
- `scripts/start_autossh.sh` - Container startup script (initializes all tunnels)
- `scripts/start_single_tunnel.sh` - Single tunnel startup script
- `scripts/tunnel_utils.sh` - Tunnel management utility functions (logging, process cleanup)

## Monitoring Recommendations

If still encountering issues, you can:

1. Check processes occupying port:
   ```bash
   lsof -i :9443
   ```

2. View specific port status:
   ```bash
   netstat -tuln | grep :9443
   ```

3. Check all SSH-related processes:
   ```bash
   ps aux | grep ssh
   ```

4. View tunnel logs:
   ```bash
   tail -f /var/log/autossh/tunnel_*.log
   ```

5. Manually clean port (if automatic cleanup fails):
   ```bash
   # Find process occupying port
   lsof -ti :9443 | xargs kill -9
   ```

## Key Improvements

1. **Use lsof instead of pgrep**: More precisely locate processes occupying ports
2. **Multiple Cleanup Strategies**: Clean related processes from multiple angles, ensure thoroughness
3. **Shortened Wait Time**: Avoid HTTP request timeout, improve response speed
4. **Force Termination**: Directly use `kill -9`, no longer attempt graceful termination

## Technical Details

### Why Multi-level Cleanup Needed?

autossh process structure:
```
autossh (parent process)
  └── ssh (child process, actually establishes tunnel)
      └── ssh child process may have other children
```

Simply killing autossh may not immediately clean all child processes, especially when SSH connection is in certain special states. Therefore need:
- Kill autossh via TUNNEL_ID
- Kill processes occupying port via port number
- Kill related SSH connections via remote hostname

### Why Use kill -9?

In restart scenarios, we need:
- **Quick Response**: Avoid API timeout
- **Thorough Cleanup**: Ensure port release
- **Reliability**: Don't rely on process's graceful exit logic

`kill -9` (SIGKILL) is an ignorable signal that ensures immediate process termination.