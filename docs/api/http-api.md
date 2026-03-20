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

通过哈希值启动特定隧道。支持使用哈希前缀（最少 8 个字符）。

**请求：**

```http
POST /start/<隧道哈希>
```

**示例：**

```bash
# 使用完整哈希
curl -X POST http://localhost:8080/start/7b840f8344679dff5df893eefd245043

# 使用哈希前缀（最少 8 个字符）
curl -X POST http://localhost:8080/start/7b840f83
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

通过哈希值停止特定隧道。支持使用哈希前缀（最少 8 个字符）。

**请求：**

```http
POST /stop/<隧道哈希>
```

**示例：**

```bash
# 使用完整哈希
curl -X POST http://localhost:8080/stop/7b840f8344679dff5df893eefd245043

# 使用哈希前缀（最少 8 个字符）
curl -X POST http://localhost:8080/stop/7b840f83
```

**响应：**

```json
{
  "status": "success",
  "tunnel_hash": "7b840f8344679dff5df893eefd245043",
  "output": "INFO: Stopping tunnel: 7b840f8344679dff5df893eefd245043\n..."
}
```

### 添加或更新隧道配置

添加新隧道或更新现有隧道配置。

**请求：**

```http
POST /edit
Content-Type: application/json
```

**请求体参数：**

| 参数        | 类型    | 必需 | 描述                                           |
| ----------- | ------- | ---- | ---------------------------------------------- |
| hash        | string  | 否   | 要更新的隧道哈希值（不提供则添加新隧道）       |
| name        | string  | 否   | 隧道名称（默认：unnamed）                      |
| remote_host | string  | 是   | 远程主机（格式：user@host）                    |
| remote_port | string  | 是   | 远程端口                                       |
| local_port  | string  | 是   | 本地端口                                       |
| direction   | string  | 否   | 隧道方向（默认：remote_to_local）              |
| interactive | boolean | 否   | 是否需要交互式认证（默认：false）              |

**示例 - 添加新隧道：**

```bash
curl -X POST http://localhost:8080/edit \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-new-tunnel",
    "remote_host": "user@server.example.com",
    "remote_port": "8080",
    "local_port": "18080",
    "direction": "remote_to_local",
    "interactive": false
  }'
```

**响应（201 Created）：**

```json
{
  "status": "success",
  "action": "added",
  "hash": "abc123def456..."
}
```

**示例 - 更新现有隧道：**

```bash
curl -X POST http://localhost:8080/edit \
  -H "Content-Type: application/json" \
  -d '{
    "hash": "7b840f8344679dff5df893eefd245043",
    "name": "updated-tunnel",
    "remote_host": "user@new-server.example.com",
    "remote_port": "9090",
    "local_port": "19090"
  }'
```

**响应（200 OK）：**

```json
{
  "status": "success",
  "action": "updated",
  "old_hash": "7b840f8344679dff5df893eefd245043",
  "new_hash": "abc123def456..."
}
```

!!! note "更新行为"
    更新隧道时，系统会：
    
    1. 停止正在运行的隧道（如果有）
    2. 删除旧配置
    3. 添加新配置
    4. 返回新的哈希值

### 删除隧道

通过哈希值删除特定隧道配置。

**请求：**

```http
DELETE /delete/<隧道哈希>
```

**示例：**

```bash
curl -X DELETE http://localhost:8080/delete/7b840f8344679dff5df893eefd245043
```

**响应：**

```json
{
  "status": "success",
  "action": "deleted",
  "hash": "7b840f8344679dff5df893eefd245043"
}
```

!!! note "POST 方法支持"
    此端点也支持 `POST` 方法，以兼容不支持 DELETE 方法的客户端：
    ```bash
    curl -X POST http://localhost:8080/delete/7b840f8344679dff5df893eefd245043
    ```

!!! warning "删除行为"
    删除隧道时：
    
    1. 如果隧道正在运行，会先停止
    2. 配置将从配置文件中移除
    3. 相关日志文件会保留直到清理

## 配置管理 API

配置管理 API 提供直接管理隧道配置的端点。所有配置更改都会在修改前自动备份。

!!! info "自动备份"
    在任何配置修改之前，系统会自动在 `/etc/autossh/config/backups/` 目录下创建带时间戳的备份。

### 获取全部配置

获取所有隧道配置。

**请求：**

```http
GET /config
```

**示例：**

```bash
curl -X GET http://localhost:8080/config
```

**响应：**

```json
{
  "tunnels": [
    {
      "name": "my-tunnel",
      "remote_host": "user@server.example.com",
      "remote_port": "8080",
      "local_port": "18080",
      "direction": "remote_to_local",
      "interactive": false,
      "hash": "7b840f8344679dff5df893eefd245043"
    },
    {
      "name": "another-tunnel",
      "remote_host": "user@other.example.com",
      "remote_port": "3306",
      "local_port": "13306",
      "direction": "remote_to_local",
      "interactive": false,
      "hash": "abc123def456789012345678901234ab"
    }
  ]
}
```

### 获取单个隧道配置

通过哈希值（或 8+ 字符前缀）获取特定隧道的配置详情。

**请求：**

```http
GET /config/<隧道哈希>
```

!!! tip "哈希前缀支持"
    可以使用短哈希前缀（最少 8 个字符）代替完整的 32 字符哈希：
    ```bash
    curl -X GET http://localhost:8080/config/7b840f83
    ```

**示例：**

```bash
curl -X GET http://localhost:8080/config/7b840f8344679dff5df893eefd245043
```

**响应：**

```json
{
  "name": "my-tunnel",
  "remote_host": "user@server.example.com",
  "remote_port": "8080",
  "local_port": "18080",
  "direction": "remote_to_local",
  "interactive": false,
  "hash": "7b840f8344679dff5df893eefd245043"
}
```

### 全部替换配置

用新的隧道配置替换整个配置文件。

**请求：**

```http
POST /config
Content-Type: application/json
```

或

```http
PUT /config
Content-Type: application/json
```

**请求体：**

```json
{
  "tunnels": [
    {
      "name": "tunnel-1",
      "remote_host": "user@server1.example.com",
      "remote_port": "8080",
      "local_port": "18080",
      "direction": "remote_to_local",
      "interactive": false
    },
    {
      "name": "tunnel-2",
      "remote_host": "user@server2.example.com",
      "remote_port": "3306",
      "local_port": "13306"
    }
  ]
}
```

**示例：**

```bash
curl -X POST http://localhost:8080/config \
  -H "Content-Type: application/json" \
  -d '{
    "tunnels": [
      {
        "name": "my-tunnel",
        "remote_host": "user@server.example.com",
        "remote_port": "8080",
        "local_port": "18080"
      }
    ]
  }'
```

**响应（200 OK）：**

```json
{
  "status": "success",
  "message": "Configuration saved"
}
```

!!! warning "完全替换"
    此端点会替换整个配置。请求中未包含的隧道将被删除。

### 新增隧道

添加新的隧道配置。

**请求：**

```http
POST /config/new
Content-Type: application/json
```

**请求体参数：**

| 参数        | 类型    | 必需 | 描述                                           |
| ----------- | ------- | ---- | ---------------------------------------------- |
| name        | string  | 是   | 隧道名称                                       |
| remote_host | string  | 是   | 远程主机（格式：user@host）                    |
| remote_port | string  | 是   | 远程端口                                       |
| local_port  | string  | 是   | 本地端口                                       |
| direction   | string  | 否   | 隧道方向（默认：remote_to_local）              |
| interactive | boolean | 否   | 是否需要交互式认证（默认：false）              |

**示例：**

```bash
curl -X POST http://localhost:8080/config/new \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-new-tunnel",
    "remote_host": "user@server.example.com",
    "remote_port": "8080",
    "local_port": "18080",
    "direction": "remote_to_local",
    "interactive": false
  }'
```

**响应（201 Created）：**

```json
{
  "name": "my-new-tunnel",
  "remote_host": "user@server.example.com",
  "remote_port": "8080",
  "local_port": "18080",
  "direction": "remote_to_local",
  "interactive": false,
  "hash": "abc123def456789012345678901234ab"
}
```

### 更新单个隧道

通过哈希值（或 8+ 字符前缀）更新现有隧道配置。

**请求：**

```http
POST /config/<隧道哈希>
Content-Type: application/json
```

或

```http
PUT /config/<隧道哈希>
Content-Type: application/json
```

**请求体参数：**

| 参数        | 类型    | 必需 | 描述                                           |
| ----------- | ------- | ---- | ---------------------------------------------- |
| name        | string  | 是   | 隧道名称                                       |
| remote_host | string  | 是   | 远程主机（格式：user@host）                    |
| remote_port | string  | 是   | 远程端口                                       |
| local_port  | string  | 是   | 本地端口                                       |
| direction   | string  | 否   | 隧道方向（默认：remote_to_local）              |
| interactive | boolean | 否   | 是否需要交互式认证（默认：false）              |

**示例：**

```bash
curl -X POST http://localhost:8080/config/7b840f83 \
  -H "Content-Type: application/json" \
  -d '{
    "name": "updated-tunnel",
    "remote_host": "user@new-server.example.com",
    "remote_port": "9090",
    "local_port": "19090"
  }'
```

**响应（200 OK）：**

```json
{
  "name": "updated-tunnel",
  "remote_host": "user@new-server.example.com",
  "remote_port": "9090",
  "local_port": "19090",
  "direction": "remote_to_local",
  "interactive": false,
  "hash": "def456abc789012345678901234567cd"
}
```

!!! note "哈希值变更"
    更新隧道配置时，哈希值会改变，因为它是根据隧道参数计算的。

### 删除隧道（RESTful）

使用 RESTful DELETE 方法删除隧道配置。

**请求：**

```http
DELETE /config/<隧道哈希>
```

**示例：**

```bash
curl -X DELETE http://localhost:8080/config/7b840f8344679dff5df893eefd245043
```

**响应（200 OK）：**

```json
{
  "status": "success",
  "message": "Tunnel deleted"
}
```

### 删除隧道（POST）

使用 POST 方法删除隧道配置（适用于不支持 DELETE 的客户端）。

**请求：**

```http
POST /config/<隧道哈希>/delete
```

**示例：**

```bash
curl -X POST http://localhost:8080/config/7b840f83/delete
```

**响应（200 OK）：**

```json
{
  "status": "success",
  "message": "Tunnel deleted"
}
```

## 日志 API

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

支持使用哈希前缀（最少 8 个字符）。

```http
GET /logs/<隧道哈希>
```

**示例：**

```bash
# 使用完整哈希
curl -X GET http://localhost:8080/logs/7b840f8344679dff5df893eefd245043

# 使用哈希前缀（最少 8 个字符）
curl -X GET http://localhost:8080/logs/7b840f83
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

### 哈希前缀相关错误

**前缀过短（少于 8 个字符）：**

```json
{
  "error": "Hash prefix too short (minimum 8 characters)"
}
```

**HTTP 状态：** 400

**无匹配隧道：**

```json
{
  "error": "No tunnel found matching prefix: <前缀>"
}
```

**HTTP 状态：** 404

**前缀匹配多个隧道（歧义）：**

```json
{
  "error": "Ambiguous prefix '<前缀>' matches multiple tunnels"
}
```

**HTTP 状态：** 400

## Web 面板

Web 面板运行在 5000 端口（可通过 `PORT` 环境变量自定义），提供隧道管理的图形界面。所有 API 调用都直接从浏览器发送到 API 服务器（8080 端口）。交互式隧道还可通过 WebSocket（默认 8022 端口）在浏览器中完成认证。

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
      - WS_BASE_URL=ws://localhost:8022   # 可选：启用浏览器内交互式认证
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