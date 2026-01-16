# Process Cleanup Function Refactoring

## Refactoring Date
2026-01-16

## Refactoring Goals
Consolidate process cleanup logic scattered across multiple scripts into shared utility functions to improve code maintainability and consistency.

## Background

While fixing tunnel port occupation issues, we found process cleanup logic scattered across multiple files:
- `scripts/control_api.sh` - Cleanup during API restart
- `scripts/start_autossh.sh` - Cleanup during container startup

This led to:
1. Code duplication
2. Maintenance difficulties (need to synchronize changes in multiple places)
3. Risk of logic inconsistency

## Refactoring Content

### 1. File Renaming

**Original filename**: `scripts/log_utils.sh`  
**New filename**: `scripts/tunnel_utils.sh`

**Reason**: The file now contains not only log management functions but also process cleanup functions, requiring a more generic name.

### 2. New Public Functions

Added two new functions in `scripts/tunnel_utils.sh`:

#### cleanup_tunnel_processes()
Used to clean up processes and ports for a specific tunnel.

**Parameters**:
- `log_id` - Tunnel log ID (optional)
- `local_port` - Local port (optional)
- `remote_host` - Remote host (optional)

**Functionality**:
1. Kill autossh process by TUNNEL_ID
2. Kill processes occupying port (using lsof)
3. Kill SSH processes connected to remote host
4. Wait and verify port release

**Use case**: API restart of single tunnel

#### cleanup_all_autossh_processes()
Used to clean up all autossh-related processes.

**Functionality**:
1. Force kill all autossh processes
2. Force kill all SSH processes
3. Wait and verify process termination

**Use case**: Initialization cleanup during container startup

### 3. Update Callers

#### scripts/control_api.sh
**Before**:
```bash
# Large amount of duplicate process cleanup code (~30 lines)
pkill -9 -f "TUNNEL_ID=${log_id}"
lsof -ti :${actual_local_port} | xargs kill -9
pkill -9 -f "ssh.*${remote_host}"
# ... wait and verification logic
```

**After**:
```bash
# Use shared function (1 line)
cleanup_tunnel_processes "$log_id" "$local_port" "$remote_host"
```

#### scripts/start_autossh.sh
**Before**:
```bash
# Large amount of duplicate process cleanup code (~40 lines)
pkill -9 -f "autossh"
pkill -9 -f "ssh -"
# ... wait and verification logic
```

**After**:
```bash
# Use shared function (1 line)
cleanup_all_autossh_processes
```

### 4. Update All References

Updated references to `log_utils.sh` in the following files:
- `scripts/control_api.sh`
- `scripts/start_autossh.sh`
- `scripts/start_single_tunnel.sh`
- `scripts/spinoff_monitor.sh`

## Refactoring Results

### Code Line Reduction
- `control_api.sh`: Reduced by ~30 lines
- `start_autossh.sh`: Reduced by ~40 lines
- Total reduction of ~70 lines of duplicate code

### Maintainability Improvement
- ✅ Single responsibility: Process cleanup logic centralized in one place
- ✅ Easy to modify: Only need to modify `tunnel_utils.sh`
- ✅ Consistency: All scripts use the same cleanup logic
- ✅ Testable: Independent functions easier to test

### Functionality Enhancement
- ✅ More reliable process cleanup
- ✅ More complete port release verification
- ✅ Unified error handling

## Backward Compatibility

This refactoring maintains full backward compatibility:
- All existing functionality remains unchanged
- API interface unchanged
- Configuration file format unchanged

## Testing Recommendations

After refactoring, test the following scenarios:

1. **API Restart Tunnel**
   ```bash
   curl -X POST http://localhost:5002/restart/{log_id}
   ```

2. **Container Restart**
   ```bash
   docker-compose restart
   ```

3. **Multiple Tunnels Running Simultaneously**
   - Verify no port conflicts
   - Verify processes cleaned up correctly

4. **Abnormal Situations**
   - Port occupied by other processes
   - Network connection interrupted
   - Rapid consecutive restarts

## Related Documentation

- [Port Occupation Issue](restart_issue.md)
- [Scripts Documentation](../../scripts/README.md)

## Future Improvement Directions

1. **Add Unit Tests**
   - Add tests for `cleanup_tunnel_processes()`
   - Add tests for `cleanup_all_autossh_processes()`

2. **Enhanced Error Handling**
   - Add retry mechanism for cleanup failures
   - Log detailed cleanup process

3. **Performance Optimization**
   - Parallel cleanup of multiple ports
   - Reduce unnecessary wait times

4. **Monitoring and Alerting**
   - Record cleanup duration
   - Send alerts on cleanup failures