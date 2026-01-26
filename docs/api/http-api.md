# HTTP API Reference

The SSH Tunnel Manager provides a RESTful HTTP API for programmatic tunnel control.

## Base URL

The API server runs on port 8080 by default:

```
http://localhost:8080
```

## Authentication

The API supports optional Bearer token authentication. When enabled, all API requests must include an `Authorization` header with a valid Bearer token.

### Enabling Authentication

Set the `API_KEY` environment variable in your Docker Compose configuration:

```yaml
services:
  autossh:
    environment:
      # Single API key
      - API_KEY=your-secret-key
      
      # Or multiple keys (comma-separated)
      - API_KEY=key1,key2,key3
```

### Using Authentication

When `API_KEY` is set, include the Bearer token in your requests:

```bash
# With authentication
curl -H "Authorization: Bearer your-secret-key" http://localhost:8080/status

# Without authentication (when API_KEY is not set)
curl http://localhost:8080/status
```

### Unauthorized Response

If authentication fails, the API returns a `401 Unauthorized` response:

```json
{
  "error": "Unauthorized",
  "message": "Valid Bearer token required"
}
```

## Endpoints

### Get Tunnel List

Retrieve a list of all configured tunnels.

**Request:**

```http
GET /list
```

**Example:**

```bash
curl -X GET http://localhost:8080/list
```

**Response:**

Returns a JSON array of tunnel objects:

```json
[
  {
    "name": "done-hub",
    "status": "NORMAL",
    "local_port": "33001",
    "remote_host": "cloud.usa2",
    "remote_port": "33000",
    "hash": "7b840f8344679dff5df893eefd245043"
  },
  {
    "name": "dockge@tempest",
    "status": "NORMAL",
    "local_port": "55001",
    "remote_host": "oaklight.tempest",
    "remote_port": "5001",
    "hash": "2ea730e749b28910932f2b141638ade8"
  }
]
```

### Get Tunnel Status

Retrieve the running status of all tunnels.

**Request:**

```http
GET /status
```

**Example:**

```bash
curl -X GET http://localhost:8080/status
```

**Response:**

Returns a JSON array of tunnel status objects:

```json
[
  {
    "name": "done-hub",
    "status": "RUNNING",
    "local_port": "33001",
    "remote_host": "cloud.usa2",
    "remote_port": "33000",
    "hash": "7b840f8344679dff5df893eefd245043"
  },
  {
    "name": "dockge@tempest",
    "status": "RUNNING",
    "local_port": "55001",
    "remote_host": "oaklight.tempest",
    "remote_port": "5001",
    "hash": "2ea730e749b28910932f2b141638ade8"
  }
]
```

### Start All Tunnels

Start all non-interactive tunnels.

**Request:**

```http
POST /start
```

**Example:**

```bash
curl -X POST http://localhost:8080/start
```

**Response:**

```json
{
  "status": "success",
  "output": "INFO: Starting tunnels...\n[2026-01-25 12:00:00] [INFO] ..."
}
```

### Stop All Tunnels

Stop all running tunnels.

**Request:**

```http
POST /stop
```

**Example:**

```bash
curl -X POST http://localhost:8080/stop
```

**Response:**

```json
{
  "status": "success",
  "output": "INFO: Stopping all managed tunnels...\n..."
}
```

### Start a Specific Tunnel

Start a specific tunnel by its hash.

**Request:**

```http
POST /start/<tunnel_hash>
```

**Example:**

```bash
curl -X POST http://localhost:8080/start/7b840f8344679dff5df893eefd245043
```

**Response:**

```json
{
  "status": "success",
  "tunnel_hash": "7b840f8344679dff5df893eefd245043",
  "output": "INFO: Starting tunnel: 7b840f8344679dff5df893eefd245043\n..."
}
```

### Stop a Specific Tunnel

Stop a specific tunnel by its hash.

**Request:**

```http
POST /stop/<tunnel_hash>
```

**Example:**

```bash
curl -X POST http://localhost:8080/stop/7b840f8344679dff5df893eefd245043
```

**Response:**

```json
{
  "status": "success",
  "tunnel_hash": "7b840f8344679dff5df893eefd245043",
  "output": "INFO: Stopping tunnel: 7b840f8344679dff5df893eefd245043\n..."
}
```

### Get Tunnel Logs

Get logs for a specific tunnel or list all available log files.

**List all log files:**

```http
GET /logs
```

**Response:**

```json
[
  {
    "hash": "7b840f8344679dff5df893eefd245043",
    "filename": "tunnel-7b840f8344679dff5df893eefd245043.log",
    "size": "4.0K",
    "modified": "2026-01-25 12:00:00"
  }
]
```

**Get specific tunnel logs:**

```http
GET /logs/<tunnel_hash>
```

**Response:**

```json
{
  "status": "success",
  "tunnel_hash": "7b840f8344679dff5df893eefd245043",
  "log": "Log content here..."
}
```

## Error Responses

### Missing Hash

```json
{
  "error": "Tunnel hash required"
}
```

**HTTP Status:** 400

### Log File Not Found

```json
{
  "error": "Log file not found for tunnel: <hash>"
}
```

**HTTP Status:** 404

### Not Found

```json
{
  "error": "Not Found"
}
```

**HTTP Status:** 404

### Method Not Allowed

```json
{
  "error": "Method not allowed"
}
```

**HTTP Status:** 405

### Unauthorized

```json
{
  "error": "Unauthorized",
  "message": "Valid Bearer token required"
}
```

**HTTP Status:** 401

## Web Panel

The web panel runs on port 5000 and provides a graphical interface for tunnel management. All API calls are made directly from the browser to the API server (port 8080).

!!! note "Network Configuration"
    The web panel no longer requires host network mode. It uses bridge networking with port mapping, and all API calls are made directly from the browser.

### Configuration

```yaml
services:
  web:
    ports:
      - "5000:5000"
    environment:
      - API_BASE_URL=http://localhost:8080
      - API_KEY=your-secret-key  # Must match autossh API_KEY
```

## Integration Examples

### Python

```python
import requests

API_BASE = "http://localhost:8080"
API_KEY = "your-secret-key"  # Optional

headers = {}
if API_KEY:
    headers["Authorization"] = f"Bearer {API_KEY}"

# Get tunnel list
response = requests.get(f"{API_BASE}/list", headers=headers)
tunnels = response.json()

# Start a specific tunnel
tunnel_hash = "7b840f8344679dff5df893eefd245043"
response = requests.post(f"{API_BASE}/start/{tunnel_hash}", headers=headers)
result = response.json()
print(result)
```

### JavaScript/Node.js

```javascript
const API_BASE = "http://localhost:8080";
const API_KEY = "your-secret-key"; // Optional

const headers = API_KEY ? { Authorization: `Bearer ${API_KEY}` } : {};

// Get tunnel status
fetch(`${API_BASE}/status`, { headers })
  .then((response) => response.json())
  .then((data) => console.log(data));

// Stop a specific tunnel
const tunnelHash = "7b840f8344679dff5df893eefd245043";
fetch(`${API_BASE}/stop/${tunnelHash}`, { method: "POST", headers })
  .then((response) => response.json())
  .then((data) => console.log(data));
```

### Shell Script

```bash
#!/bin/bash

API_BASE="http://localhost:8080"
API_KEY="your-secret-key"  # Optional
TUNNEL_HASH="7b840f8344679dff5df893eefd245043"

# Build auth header if API_KEY is set
AUTH_HEADER=""
if [ -n "$API_KEY" ]; then
    AUTH_HEADER="-H \"Authorization: Bearer $API_KEY\""
fi

# Check status
eval curl -s $AUTH_HEADER "$API_BASE/status" | jq .

# Start tunnel
eval curl -s -X POST $AUTH_HEADER "$API_BASE/start/$TUNNEL_HASH" | jq .

# Stop tunnel
eval curl -s -X POST $AUTH_HEADER "$API_BASE/stop/$TUNNEL_HASH" | jq .