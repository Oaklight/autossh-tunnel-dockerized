# 故障排除

本指南帮助您解决使用 SSH 隧道管理器时可能遇到的常见问题。

## SSH 连接问题

### 隧道无法建立连接

**症状**：隧道启动失败或立即断开

**可能原因和解决方案**：

1. **SSH 密钥权限不正确**

   确保 `.ssh` 目录及其内容具有适当的权限：
   
   ```bash
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/id_*
   chmod 644 ~/.ssh/*.pub
   chmod 644 ~/.ssh/config
   chmod 644 ~/.ssh/known_hosts
   ```

2. **SSH 配置文件缺失或错误**

   检查 `~/.ssh/config` 文件是否存在并正确配置：
   
   ```bash
   cat ~/.ssh/config
   ```
   
   参考 [SSH 配置指南](ssh-config.md) 进行正确配置。

3. **远程主机无法访问**

   测试 SSH 连接：
   
   ```bash
   ssh user@remote-host
   ```

4. **防火墙阻止连接**

   检查本地和远程防火墙设置，确保允许 SSH 连接。

### 权限被拒绝 (Permission Denied)

**症状**：SSH 连接时提示权限被拒绝

**解决方案**：

1. 确认使用正确的 SSH 密钥：
   ```bash
   ssh -i ~/.ssh/id_ed25519 user@remote-host
   ```

2. 检查远程服务器的 `authorized_keys` 文件：
   ```bash
   cat ~/.ssh/authorized_keys  # 在远程服务器上执行
   ```

3. 确保公钥已添加到远程服务器：
   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519.pub user@remote-host
   ```

## Docker 相关问题

### 容器无法启动

**症状**：`docker compose up` 失败

**解决方案**：

1. **检查 Docker 服务状态**：
   ```bash
   sudo systemctl status docker
   ```

2. **检查端口冲突**：
   ```bash
   # 检查 5000 端口（Web 面板）
   netstat -tuln | grep 5000

   # 检查 8080 端口（API 服务器）
   netstat -tuln | grep 8080

   # 检查 8022 端口（WebSocket 服务器）
   netstat -tuln | grep 8022
   ```

3. **查看容器日志**：
   ```bash
   docker compose logs
   ```

### Docker 权限问题

**症状**：运行 Docker 命令时提示权限不足

**解决方案**：

1. 将用户添加到 docker 组：
   ```bash
   sudo usermod -aG docker $USER
   ```

2. 重新登录或运行：
   ```bash
   newgrp docker
   ```

### 文件权限问题

**症状**：容器内无法访问挂载的文件

**解决方案**：

1. 检查 PUID 和 PGID 设置：
   ```bash
   id  # 查看当前用户的 UID 和 GID
   ```

2. 在 `compose.yaml` 中设置正确的值：
   ```yaml
   environment:
     - PUID=1000  # 替换为您的 UID
     - PGID=1000  # 替换为您的 GID
   ```

3. 重启容器：
   ```bash
   docker compose down
   docker compose up -d
   ```

## 配置问题

### 配置文件格式错误

**症状**：隧道无法启动，日志显示 YAML 解析错误

**解决方案**：

1. 验证 YAML 语法：
   ```bash
   # 使用 Python 验证
   python3 -c "import yaml; yaml.safe_load(open('config/config.yaml'))"
   ```

2. 检查常见错误：
   - 缩进必须使用空格，不能使用制表符
   - 确保冒号后有空格
   - 字符串值如果包含特殊字符需要用引号包围

3. 参考示例配置：
   ```bash
   cat config/config.yaml.sample
   ```

### 配置更改未生效

**症状**：修改配置后隧道未更新

**解决方案**：

1. 检查配置文件监控是否正常：
   ```bash
   docker compose logs autossh | grep inotify
   ```

2. 手动重启服务：
   ```bash
   docker compose restart autossh
   ```

3. 验证配置文件路径：
   ```bash
   docker compose exec autossh cat /etc/autossh/config/config.yaml
   ```

## 交互式认证问题

### 交互式隧道无法启动

**症状**：运行 `autossh-cli auth <hash>` 失败或显示错误，或者浏览器终端弹窗无法完成认证

**解决方案**：

1. **确保使用正确的用户上下文**：
   
   `auth` 命令必须以 `myuser` 用户身份运行：
   ```bash
   docker exec -it -u myuser <容器名称> autossh-cli auth <hash>
   ```
   
   如果不使用 `-u myuser`，可能会看到访问 SSH 配置文件的权限错误。

2. **验证隧道是否标记为交互式**：
   
   检查隧道配置中是否有 `interactive: true`：
   ```bash
   docker exec -it autossh-1 autossh-cli show-tunnel <hash>
   ```

3. **检查 SSH 主机配置**：
   
   确保远程主机在 `~/.ssh/config` 中正确配置：
   ```bash
   docker exec -it autossh-1 cat /home/myuser/.ssh/config
   ```

### 认证失败

**症状**：2FA 验证码或密码被拒绝

**解决方案**：

1. **验证凭据**：
   - 确保输入正确的 2FA 验证码或密码
   - 检查 2FA 令牌是否已过期（TOTP 验证码有时间限制）

2. **检查 SSH 服务器配置**：
   - 验证远程服务器是否支持键盘交互式认证
   - 检查您的账户在远程服务器上是否被锁定或禁用

3. **测试手动 SSH 连接**：
   ```bash
   docker exec -it -u myuser autossh-1 ssh <远程主机>
   ```

### 交互式隧道认证后显示 STOPPED

**症状**：隧道认证成功但立即显示为 STOPPED

**解决方案**：

1. **检查隧道日志**：
   ```bash
   docker exec -it autossh-1 autossh-cli logs <hash>
   ```

2. **验证端口可用性**：
   
   确保本地/远程端口未被占用：
   ```bash
   netstat -tuln | grep <端口号>
   ```

3. **检查 SSH 控制套接字**：
   ```bash
   docker exec -it autossh-1 ls -la /tmp/ssh_control_*
   ```

## 隧道运行问题

### 隧道频繁断开重连

**症状**：隧道不稳定，频繁断开

**解决方案**：

1. 检查网络连接稳定性

2. 调整 autossh 参数：
   ```yaml
   environment:
     - AUTOSSH_GATETIME=30  # 增加连接稳定时间
   ```

3. 检查远程服务器负载和网络状况

### 端口已被占用

**症状**：隧道启动失败，提示端口已被使用

**解决方案**：

1. 查找占用端口的进程：
   ```bash
   # Linux
   sudo lsof -i :端口号
   
   # 或使用
   sudo netstat -tulpn | grep 端口号
   ```

2. 停止占用端口的进程或更改隧道配置使用其他端口

### 无法访问隧道服务

**症状**：隧道显示运行中，但无法访问服务

**解决方案**：

1. **检查隧道方向**：
   - `local_to_remote`：在远程服务器上访问
   - `remote_to_local`：在本地机器上访问

2. **验证端口绑定**：
   ```bash
   # 在相应的机器上检查端口监听
   netstat -tuln | grep 端口号
   ```

3. **检查防火墙规则**：
   ```bash
   # 查看防火墙状态
   sudo ufw status  # Ubuntu/Debian
   sudo firewall-cmd --list-all  # CentOS/RHEL
   ```

4. **测试连接**：
   ```bash
   # 本地测试
   curl http://localhost:端口号
   
   # 远程测试
   curl http://远程主机:端口号
   ```

## Web 面板问题

### 无法访问 Web 面板

**症状**：浏览器无法打开 `http://localhost:5000`

**解决方案**：

1. 检查 Web 容器状态：
   ```bash
   docker compose ps web
   ```

2. 查看 Web 容器日志：
   ```bash
   docker compose logs web
   ```

3. 验证端口映射：
   ```bash
   docker compose port web 5000
   ```

4. 如果使用了 `PORT` 环境变量自定义端口，请确保端口映射与 `PORT` 值一致：
   ```yaml
   environment:
     - PORT=3000
   ports:
     - "3000:3000"   # 必须与 PORT 值匹配
   ```

5. 检查 API 连接：
   ```bash
   # 在 compose.yaml 中确认 API_BASE_URL 设置正确
   docker compose exec web env | grep API_BASE_URL
   ```

### Web 面板显示空白或错误

**症状**：Web 面板加载但显示异常

**解决方案**：

1. 清除浏览器缓存

2. 检查浏览器控制台错误（F12）

3. 验证 API 服务器是否运行：
   ```bash
   curl http://localhost:8080/status
   ```

### 交互式认证终端弹窗无法打开

**症状**：点击交互式隧道的启动/重启按钮时，没有弹出终端弹窗

**解决方案**：

1. **确认 WebSocket 已配置**：

   检查 Web 面板容器是否设置了 `WS_BASE_URL` 环境变量：
   ```bash
   docker compose exec web env | grep WS_BASE_URL
   ```

2. **确认 ws-server 已启动**：

   检查 autossh 容器是否设置了 `WS_PORT` 环境变量：
   ```bash
   docker compose exec autossh env | grep WS_PORT
   ```

3. **检查 ws-server 端口是否可访问**：
   ```bash
   # 默认端口为 8022
   netstat -tuln | grep 8022
   ```

4. **检查浏览器控制台**：

   打开浏览器开发者工具（F12），查看 Console 和 Network 标签中是否有 WebSocket 连接错误。

### 终端弹窗连接失败

**症状**：终端弹窗打开但显示连接错误或无法输入

**解决方案**：

1. **验证 WS_BASE_URL 地址格式**：

   确保使用正确的协议前缀：
   ```yaml
   # 正确
   - WS_BASE_URL=ws://localhost:8022

   # 如果使用 TLS
   - WS_BASE_URL=wss://localhost:8022
   ```

2. **检查防火墙规则**：

   确保 WebSocket 端口（默认 8022）未被防火墙阻止。

3. **检查 autossh 容器日志**：
   ```bash
   docker compose logs autossh | grep ws-server
   ```

4. **测试 WebSocket 连接**：

   在浏览器开发者工具的 Console 中：
   ```javascript
   const ws = new WebSocket('ws://localhost:8022');
   ws.onopen = () => console.log('Connected');
   ws.onerror = (e) => console.log('Error', e);
   ```

## API 问题

### API 请求失败

**症状**：CLI 命令或 HTTP API 请求返回错误

**解决方案**：

1. 确认 API 已启用：
   ```yaml
   environment:
     - API_ENABLE=true
   ```

2. 检查 API 服务器日志：
   ```bash
   docker compose logs autossh | grep api
   ```

3. 测试 API 连接：
   ```bash
   curl http://localhost:8080/list
   ```

## 日志和调试

### 查看日志

```bash
# 查看所有容器日志
docker compose logs

# 查看特定容器日志
docker compose logs autossh
docker compose logs web

# 实时跟踪日志
docker compose logs -f

# 查看最近 100 行日志
docker compose logs --tail=100
```

### 进入容器调试

```bash
# 进入 autossh 容器
docker compose exec autossh sh

# 进入 web 容器
docker compose exec web sh

# 在容器内检查进程
ps aux

# 检查网络连接
netstat -tuln
```

### 启用详细日志

在 `compose.yaml` 中添加调试环境变量：

```yaml
environment:
  - DEBUG=true
  - VERBOSE=true
```

## 性能问题

### 容器占用资源过高

**解决方案**：

1. 检查资源使用情况：
   ```bash
   docker stats
   ```

2. 限制容器资源：
   ```yaml
   services:
     autossh:
       deploy:
         resources:
           limits:
             cpus: '0.5'
             memory: 512M
   ```

3. 清理未使用的 Docker 资源：
   ```bash
   docker system prune -a
   ```

## 获取帮助

如果以上方法都无法解决您的问题：

1. **查看项目文档**：
   - [快速入门](getting-started.md)
   - [架构说明](architecture.md)
   - [API 文档](api/index.md)

2. **提交 Issue**：
   访问 [GitHub Issues](https://github.com/Oaklight/autossh-tunnel-dockerized/issues) 提交问题

3. **提供信息**：
   - 操作系统和版本
   - Docker 和 Docker Compose 版本
   - 完整的错误日志
   - 配置文件内容（隐藏敏感信息）
   - 重现问题的步骤