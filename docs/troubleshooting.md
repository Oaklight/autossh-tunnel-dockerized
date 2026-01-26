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

4. 检查 API 连接：
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