# HTTP API Reference

The SSH Tunnel Manager provides a RESTful HTTP API for programmatic tunnel control.

## Base URL

The API server runs on port 8080 by default:

```
http://localhost:8080
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

```json
{
  "tunnels": [
    {
      "name": "done-hub",
      "remote_host": "cloud.usa2",
      "remote_port": "127.0.0.1:33000",
      "local_port": "0.0.0.0:33001",
      "direction": "remote_to_local",
      "hash": "7b840f8344679dff5df893eefd245043",
      "interactive": false
    },
    {
      "name": "dockge@tempest",
      "remote_host": "oaklight.tempest",
      "remote_port": "5001",
      "local_port": "55001",
      "direction": "remote_to_local",
      "hash": "2ea730e749b28910932f2b141638ade8",
      "interactive": false
    }
  ]
}
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

```json
{
  "tunnels": [
    {
      "name": "done-hub",
      "hash": "7b840f8344679dff5df893eefd245043",
      "status": "RUNNING",
      "pid": 186
    },
    {
      "name": "dockge@tempest",
      "hash": "2ea730e749b28910932f2b141638ade8",
      "status": "RUNNING",
      "pid": 192
    }
  ]
}
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
  "message": "All tunnels started"
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
  "message": "All tunnels stopped"
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

**Response (Success):**

```json
{
  "status": "success",
  "tunnel_hash": "7b840f8344679dff5df893eefd245043",
  "output": "Tunnel started successfully"
}
```

**Response (Already Running):**

```json
{
  "status": "success",
  "tunnel_hash": "7b840f8344679dff5df893eefd245043",
  "message": "Tunnel is already running"
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
  "output": "Tunnel stopped successfully"
}
```

## Error Responses

### Tunnel Not Found

```json
{
  "error": "Tunnel not found",
  "tunnel_hash": "invalid_hash"
}
```

**HTTP Status:** 404

### Missing Hash

```json
{
  "error": "Tunnel hash required"
}
```

**HTTP Status:** 400

### Internal Error

```json
{
  "error": "Failed to start tunnel",
  "details": "Error message here"
}
```

**HTTP Status:** 500

## Web Panel Proxy Endpoints

The web panel (port 5000) provides proxy endpoints to the API server:

| Web Panel Endpoint | Proxies To |
|-------------------|------------|
| `POST /api/tunnel/start` | `POST /start/<hash>` |
| `POST /api/tunnel/stop` | `POST /stop/<hash>` |
| `POST /api/tunnel/restart` | Stop then Start |

**Request Format:**

```json
{
  "hash": "tunnel_hash_here"
}
```

**Example:**

```bash
curl -X POST http://localhost:5000/api/tunnel/start \
  -H "Content-Type: application/json" \
  -d '{"hash": "7b840f8344679dff5df893eefd245043"}'
```

## Integration Examples

### Python

```python
import requests

API_BASE = "http://localhost:8080"

# Get tunnel list
response = requests.get(f"{API_BASE}/list")
tunnels = response.json()

# Start a specific tunnel
tunnel_hash = "7b840f8344679dff5df893eefd245043"
response = requests.post(f"{API_BASE}/start/{tunnel_hash}")
result = response.json()
print(result)
```

### JavaScript/Node.js

```javascript
const API_BASE = "http://localhost:8080";

// Get tunnel status
fetch(`${API_BASE}/status`)
  .then((response) => response.json())
  .then((data) => console.log(data));

// Stop a specific tunnel
const tunnelHash = "7b840f8344679dff5df893eefd245043";
fetch(`${API_BASE}/stop/${tunnelHash}`, { method: "POST" })
  .then((response) => response.json())
  .then((data) => console.log(data));
```

### Shell Script

```bash
#!/bin/bash

API_BASE="http://localhost:8080"
TUNNEL_HASH="7b840f8344679dff5df893eefd245043"

# Check status
curl -s "$API_BASE/status" | jq .

# Start tunnel
curl -s -X POST "$API_BASE/start/$TUNNEL_HASH" | jq .

# Stop tunnel
curl -s -X POST "$API_BASE/stop/$TUNNEL_HASH" | jq .