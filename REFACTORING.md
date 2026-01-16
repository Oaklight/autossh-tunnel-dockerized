# Architecture Refactoring Summary

## Overview

This document summarizes the major architecture refactoring completed on 2026-01-16.

## Goals

1. **Unified tunnel startup logic** - Single script for starting tunnels, reused everywhere
2. **Centralized monitoring** - Dedicated daemon for status monitoring
3. **API consolidation** - Move status/logs APIs to autossh container
4. **Simplified web container** - Web container only handles UI, calls autossh APIs

## Changes Made

### 1. New Files Created

#### `scripts/start_single_tunnel.sh`

- **Purpose**: Unified script to start a single SSH tunnel
- **Features**:
  - Uses `setsid` and `nohup` to ensure process survives parent exit
  - Handles both local-to-remote and remote-to-local tunnels
  - Generates unique log IDs
  - Reused by both initial startup and restart operations

#### `scripts/monitor_daemon.sh`

- **Purpose**: Continuous monitoring daemon
- **Features**:
  - Runs in background, checks tunnel status every 5 seconds
  - Parses log files to determine tunnel status
  - Writes status to `/tmp/tunnel_status.json`
  - Provides real-time status information for API

### 2. Modified Files

#### `scripts/start_autossh.sh`

- **Before**: Contained all tunnel startup logic inline
- **After**:
  - Simplified to use `start_single_tunnel.sh`
  - Only handles initialization (log headers, cleanup)
  - Calls unified script for each tunnel
  - Still maintains container keepalive loop

#### `scripts/control_api.sh`

- **Added endpoints**:
  - `GET /status` - Returns tunnel status from monitor daemon
  - `GET /logs/{log_id}` - Returns log content for specific tunnel
  - `POST /restart/{log_id}` - Restarts specific tunnel (existing)
  - `GET /health` - Health check (existing)
- **Changes**:
  - Now uses `start_single_tunnel.sh` for restarts
  - Reads status from monitor daemon's JSON file
  - Serves log content directly

#### `entrypoint.sh`

- **Added**: Start `monitor_daemon.sh` in background
- **Order**:
  1. control_api.sh (API server)
  2. monitor_daemon.sh (status monitoring)
  3. spinoff_monitor.sh (config file monitoring)
  4. start_autossh.sh (main process)

#### `web/main.go`

- **Simplified**:
  - `getStatusHandler()` - Now proxies to autossh `/status` API
  - `getLogsAPIHandler()` - Now proxies to autossh `/logs/{id}` API
  - Removed log file parsing logic
  - Removed direct log file access

#### `compose.yaml`

- **Removed**: `./logs:/home/myuser/logs:ro` volume mount from web container
- **Reason**: Web container no longer needs direct log access

### 3. Deleted Files

#### `scripts/restart_single_tunnel.sh`

- **Reason**: Replaced by unified `start_single_tunnel.sh`

## Architecture Comparison

### Before Refactoring

```
autossh container:
  ├── start_autossh.sh (monolithic startup)
  ├── restart_single_tunnel.sh (separate restart logic)
  ├── control_api.sh (only /restart endpoint)
  └── spinoff_monitor.sh (config monitoring)

web container:
  ├── Reads log files directly
  ├── Parses logs for status
  ├── Provides /api/status endpoint
  └── Provides /api/logs endpoint
```

### After Refactoring

```
autossh container:
  ├── start_single_tunnel.sh (unified tunnel starter) ⭐ NEW
  ├── start_autossh.sh (simplified, uses unified script)
  ├── monitor_daemon.sh (status monitoring) ⭐ NEW
  ├── control_api.sh (provides /status, /logs, /restart) ⭐ ENHANCED
  └── spinoff_monitor.sh (config monitoring)

web container:
  ├── Proxies to autossh /status API ⭐ SIMPLIFIED
  ├── Proxies to autossh /logs API ⭐ SIMPLIFIED
  └── Only handles UI rendering
```

## Benefits

### 1. Code Reusability

- ✅ Single source of truth for tunnel startup logic
- ✅ No code duplication between startup and restart
- ✅ Easier to maintain and update

### 2. Separation of Concerns

- ✅ autossh container: Tunnel management + monitoring
- ✅ web container: UI only
- ✅ Clear API boundaries

### 3. Better Monitoring

- ✅ Dedicated daemon for continuous status monitoring
- ✅ Real-time status updates every 5 seconds
- ✅ Centralized status information

### 4. Simplified Web Container

- ✅ No direct log file access needed
- ✅ Lighter weight
- ✅ Easier to deploy independently

### 5. Process Management

- ✅ Proper use of `setsid`/`nohup` for background processes
- ✅ Processes survive parent script exit
- ✅ Consistent behavior across startup and restart

## API Endpoints

### autossh container (port 5002)

| Method | Endpoint            | Description                         |
| ------ | ------------------- | ----------------------------------- |
| GET    | `/status`           | Get status of all tunnels           |
| GET    | `/logs/{log_id}`    | Get log content for specific tunnel |
| POST   | `/restart/{log_id}` | Restart specific tunnel             |
| GET    | `/health`           | Health check                        |

### web container (port 5000)

| Method | Endpoint                  | Description                          |
| ------ | ------------------------- | ------------------------------------ |
| GET    | `/`                       | Web UI home page                     |
| GET    | `/logs?id={log_id}`       | Log viewing page                     |
| GET    | `/api/config`             | Get tunnel configuration             |
| POST   | `/api/config`             | Update tunnel configuration          |
| GET    | `/api/status`             | Proxy to autossh `/status`           |
| GET    | `/api/logs/{log_id}`      | Proxy to autossh `/logs/{log_id}`    |
| POST   | `/api/reconnect/{log_id}` | Proxy to autossh `/restart/{log_id}` |

## Testing Checklist

- [ ] Build and start containers: `docker compose up -d --build`
- [ ] Verify all tunnels start successfully
- [ ] Check status API: `curl http://localhost:5002/status`
- [ ] Check web UI status display
- [ ] Test tunnel restart via web UI
- [ ] Verify logs display correctly
- [ ] Test configuration file changes trigger restart
- [ ] Verify monitor daemon is running
- [ ] Check that restarted tunnels continue running

## Migration Notes

For existing deployments:

1. **Backup**: Backup your `config/config.yaml` and `logs/` directory
2. **Rebuild**: Run `docker compose up -d --build` to rebuild with new scripts
3. **Verify**: Check that all tunnels are running correctly
4. **Monitor**: Watch logs for any issues during first few minutes

## Future Improvements

Potential enhancements for future consideration:

1. Add tunnel health checks (ping/port check)
2. Implement automatic restart on failure
3. Add metrics/statistics collection
4. Support for tunnel groups/categories
5. Email/webhook notifications on status changes
