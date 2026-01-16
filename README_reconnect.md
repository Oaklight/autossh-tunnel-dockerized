# Tunnel Reconnect Feature

## Architecture

The reconnect feature uses a two-container architecture with API communication:

```
┌─────────────────┐         HTTP POST          ┌──────────────────┐
│   Web Container │  ───────────────────────>  │ Autossh Container│
│   (Port 5000)   │  /restart/{log_id}         │   (Port 5001)    │
│                 │  <───────────────────────  │                  │
│  - Web UI       │         JSON Response      │  - Control API   │
│  - Go Backend   │                            │  - Autossh Proc  │
└─────────────────┘                            └──────────────────┘
```

## Components

### 1. Control API Server (autossh container)

- **File**: `scripts/control_api.sh`
- **Port**: 5001
- **Endpoints**:
  - `POST /restart/{log_id}` - Restart specific tunnel
  - `GET /health` - Health check
  - `OPTIONS /*` - CORS preflight

### 2. Web Backend (web container)

- **File**: `web/main.go`
- **Function**: `reconnectTunnelHandler()`
- **Role**: Proxy requests to autossh control API

### 3. Frontend (web container)

- **File**: `web/templates/logs.html`
- **Function**: `reconnectTunnel()`
- **UI**: Orange "Reconnect" button on log page

## How It Works

1. User clicks "Reconnect" button on log page
2. Frontend sends POST to `/api/reconnect/{log_id}`
3. Web backend forwards request to `http://autossh:5001/restart/{log_id}`
4. Control API in autossh container:
   - Finds tunnel config by log_id
   - Kills existing autossh process for that tunnel
   - Restarts the tunnel using `start_autossh.sh`
5. Response flows back through web backend to frontend
6. Frontend shows success message and refreshes logs

## Security Considerations

- Control API only accessible within Docker network
- No authentication needed (internal service)
- CORS enabled for web container access
- Only allows POST to /restart endpoint
- Process isolation via pkill with specific parameters

## Configuration

### Docker Compose

```yaml
autossh:
  ports:
    - "5001:5001" # Control API port
  environment:
    - API_PORT=5001
```

### Environment Variables

- `API_PORT`: Control API listen port (default: 5001)

## Testing

### Test Control API directly:

```bash
# Health check
curl http://localhost:5001/health

# Restart tunnel (replace LOG_ID with actual log ID)
curl -X POST http://localhost:5001/restart/abc12345
```

### Test through Web UI:

1. Navigate to tunnel log page
2. Click "Reconnect" button
3. Confirm the action
4. Wait for success message
5. Check logs for restart confirmation

## Troubleshooting

### API not responding

- Check if control_api.sh is running: `docker exec autossh ps | grep control_api`
- Check API logs: `docker logs autossh | grep "control API"`
- Verify port 5001 is exposed: `docker ps`

### Tunnel not restarting

- Check autossh container logs: `docker logs autossh`
- Verify tunnel config exists in config.yaml
- Check if log_id is correct
- Ensure start_autossh.sh is executable

### Connection refused from web container

- Verify both containers are on same network
- Check autossh container name in compose.yaml
- Test connectivity: `docker exec web ping autossh`

## Future Improvements

- Add authentication/API key
- Implement rate limiting
- Add tunnel status endpoint
- Support batch restart operations
- Add WebSocket for real-time status updates
