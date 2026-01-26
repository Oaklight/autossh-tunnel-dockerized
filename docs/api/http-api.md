# HTTP API 参考

SSH 隧道管理器提供 RESTful HTTP API 用于程序化隧道控制。

## 基础 URL

API 服务器默认运行在 8080 端口：

```
http://localhost:8080
```

## 认证

API 支持可选的 Bearer Token 认证。启用后，所有 API 请求必须在请求头中包含有效的 Bearer Token。

### 启用认证

在 Docker Compose 配置中设置 `API_KEY` 环境变量：

```yaml
services:
  autossh:
    environment:
      # 单个 API 密钥
      - API_KEY=your-secret-key
      
      # 或多个密钥（逗号分隔）
      - API_KEY=key1,key2,key3
```

### 使用认证

当设置了 `API_KEY` 时，在请求中包含 Bearer Token：

```bash
# 带认证
curl -H "Authorization: Bearer your-secret-key" http://localhost:8080/status

# 不带认证（未设置 API_KEY 时）
curl http://localhost:8080/status
```

### 未授权响应

如果认证失败，API 返回 `401 Unauthorized` 响应：

```json
{
  "error": "Unauthorized",
  "message": "Valid Bearer token required"
}
```

## 端点

### 获取隧道列表

检索所有配置的隧道列表。

**请求：**

```http
GET /list
```

**示例：**

```bash
curl -X GET http://localhost:8080/list
```

**响应：**

返回隧道对象的 JSON 数组：

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

### 获取隧道状态

检索所有隧道的运行状态。

**请求：**

```http
GET /status
```

**示例：**

```bash
curl -X GET http://localhost:8080/status
```

**响应：**

返回隧道状态对象的 JSON 数组：

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

### 启动所有隧道

启动所有非交互式隧道。

**请求：**

```http
POST /start
```

**示例：**

```bash
curl -X POST http://localhost:8080/start
```

**响应：**

```json
{
  "status": "success",
  "output": "INFO: Starting tunnels...\n[2026-01-25 12:00:00] [INFO] ..."
}
```

### 停止所有隧道

停止所有运行中的隧道。

**请求：**

```http
POST /stop
```

**示例：**

```bash
curl -X POST http://localhost:8080/stop
```

**响应：**

```json
{
  "status": "success",
  "output": "INFO: Stopping all managed tunnels...\n..."
}
```

### 启动特定隧道

通过哈希值启动特定隧道。

**请求：**

```http
POST /start/<隧道哈希>
```

**示例：**

```bash
curl -X POST http://localhost:8080/start/7b840f8344679dff5df893eefd245043
```

**响应：**

```json
{
  "status": "success",
  "tunnel_hash": "7b840f8344679dff5df893eefd245043",
  "output": "INFO: Starting tunnel: 7b840f8344679dff5df893eefd245043\n..."
}
```

### 停止特定隧道

通过哈希值停止特定隧道。

**请求：**

```http
POST /stop/<隧道哈希>
```

**示例：**

```bash
curl -X POST http://localhost:8080/stop/7b840f8344679dff5df893eefd245043
```

**响应：**

```json
{
  "status": "success",
  "tunnel_hash": "7b840f8344679dff5df893eefd245043",
  "output": "INFO: Stopping tunnel: 7b840f8344679dff5df893eefd245043\n..."
}
```

### 获取隧道日志

获取特定隧道的日志或列出所有可用的日志文件。

**列出所有日志文件：**

```http
GET /logs
```

**响应：**

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

**获取特定隧道日志：**

```http
GET /logs/<隧道哈希>
```

**响应：**

```json
{
  "status": "success",
  "tunnel_hash": "7b840f8344679dff5df893eefd245043",
  "log": "日志内容..."
}
```

## 错误响应

### 缺少哈希值

```json
{
  "error": "Tunnel hash required"
}
```

**HTTP 状态：** 400

### 日志文件未找到

```json
{
  "error": "Log file not found for tunnel: <哈希>"
}
```

**HTTP 状态：** 404

### 未找到

```json
{
  "error": "Not Found"
}
```

**HTTP 状态：** 404

### 方法不允许

```json
{
  "error": "Method not allowed"
}
```

**HTTP 状态：** 405

### 未授权

```json
{
  "error": "Unauthorized",
  "message": "Valid Bearer token required"
}
```

**HTTP 状态：** 401

## Web 面板

Web 面板运行在 5000 端口，提供隧道管理的图形界面。所有 API 调用都直接从浏览器发送到 API 服务器（8080 端口）。

!!! note "网络配置"
    Web 面板不再需要 host 网络模式。它使用 bridge 网络和端口映射，所有 API 调用都直接从浏览器发起。

### 配置

```yaml
services:
  web:
    ports:
      - "5000:5000"
    environment:
      - API_BASE_URL=http://localhost:8080
      - API_KEY=your-secret-key  # 必须与 autossh 的 API_KEY 匹配
```

## 集成示例

### Python

```python
import requests

API_BASE = "http://localhost:8080"
API_KEY = "your-secret-key"  # 可选

headers = {}
if API_KEY:
    headers["Authorization"] = f"Bearer {API_KEY}"

# 获取隧道列表
response = requests.get(f"{API_BASE}/list", headers=headers)
tunnels = response.json()

# 启动特定隧道
tunnel_hash = "7b840f8344679dff5df893eefd245043"
response = requests.post(f"{API_BASE}/start/{tunnel_hash}", headers=headers)
result = response.json()
print(result)
```

### JavaScript/Node.js

```javascript
const API_BASE = "http://localhost:8080";
const API_KEY = "your-secret-key"; // 可选

const headers = API_KEY ? { Authorization: `Bearer ${API_KEY}` } : {};

// 获取隧道状态
fetch(`${API_BASE}/status`, { headers })
  .then((response) => response.json())
  .then((data) => console.log(data));

// 停止特定隧道
const tunnelHash = "7b840f8344679dff5df893eefd245043";
fetch(`${API_BASE}/stop/${tunnelHash}`, { method: "POST", headers })
  .then((response) => response.json())
  .then((data) => console.log(data));
```

### Shell 脚本

```bash
#!/bin/bash

API_BASE="http://localhost:8080"
API_KEY="your-secret-key"  # 可选
TUNNEL_HASH="7b840f8344679dff5df893eefd245043"

# 如果设置了 API_KEY，构建认证头
AUTH_HEADER=""
if [ -n "$API_KEY" ]; then
    AUTH_HEADER="-H \"Authorization: Bearer $API_KEY\""
fi

# 检查状态
eval curl -s $AUTH_HEADER "$API_BASE/status" | jq .

# 启动隧道
eval curl -s -X POST $AUTH_HEADER "$API_BASE/start/$TUNNEL_HASH" | jq .

# 停止隧道
eval curl -s -X POST $AUTH_HEADER "$API_BASE/stop/$TUNNEL_HASH" | jq .