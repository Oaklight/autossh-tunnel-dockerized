# SSH 配置文件配置指南

[中文版](README_ssh_config_zh.md) | [English](README_ssh_config_en.md)

本指南说明如何配置SSH配置文件（`~/.ssh/config`）以便与autossh-tunnel-dockerized项目配合使用。SSH配置文件对于定义连接参数和确保隧道顺利建立至关重要。

## 目录

- [概述](#概述)
- [SSH配置文件位置](#ssh配置文件位置)
- [基础配置](#基础配置)
- [高级配置](#高级配置)
- [常见配置示例](#常见配置示例)
- [安全最佳实践](#安全最佳实践)
- [故障排除](#故障排除)

## 概述

SSH配置文件（`~/.ssh/config`）允许您为SSH主机定义连接参数，包括：

- 主机别名和真实主机名
- 每个主机的用户名
- SSH端口号
- 私钥文件
- 连接选项和超时设置
- 代理配置

本项目严重依赖SSH配置文件，因为：

1. **主机识别**：`config.yaml`中的`remote_host`参数引用您SSH配置中的条目
2. **身份验证**：SSH配置指定每个主机使用哪些私钥
3. **连接参数**：超时、端口和其他连接设置在此定义
4. **简化配置**：无需在每个隧道中指定完整的连接详细信息，您可以使用简单的主机别名

## SSH配置文件位置

SSH配置文件应位于：

```bash
~/.ssh/config
```

如果此文件不存在，请创建它：

```bash
touch ~/.ssh/config
chmod 600 ~/.ssh/config
```

## 基础配置

### 简单主机配置

```ssh-config
Host myserver
    HostName example.com
    User myuser
    Port 22
    IdentityFile ~/.ssh/id_ed25519
```

### 多个主机

```ssh-config
Host server1
    HostName 192.168.1.100
    User admin
    Port 22
    IdentityFile ~/.ssh/id_rsa

Host server2
    HostName server2.example.com
    User root
    Port 2222
    IdentityFile ~/.ssh/id_ed25519

Host jumphost
    HostName jump.example.com
    User jumpuser
    Port 22
    IdentityFile ~/.ssh/jump_key
```

## 高级配置

### 连接优化

```ssh-config
Host *
    # 启用连接复用
    ControlMaster auto
    ControlPath ~/.ssh/sockets/ssh_mux_%h_%p_%r
    ControlPersist 600
    
    # 连接超时设置
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ConnectTimeout 10
    
    # 安全设置
    StrictHostKeyChecking yes
    UserKnownHostsFile ~/.ssh/known_hosts

Host production-server
    HostName prod.example.com
    User deploy
    Port 22
    IdentityFile ~/.ssh/production_key
    
    # 此主机的特定设置
    ServerAliveInterval 30
    TCPKeepAlive yes
    Compression yes
```

### 跳板机配置

```ssh-config
Host jumphost
    HostName jump.example.com
    User jumpuser
    Port 22
    IdentityFile ~/.ssh/jump_key

Host internal-server
    HostName 10.0.1.100
    User admin
    Port 22
    IdentityFile ~/.ssh/internal_key
    ProxyJump jumphost
    
    # 旧版SSH的替代语法
    # ProxyCommand ssh -W %h:%p jumphost
```

### 通配符模式

```ssh-config
Host *.internal
    User admin
    Port 22
    IdentityFile ~/.ssh/internal_key
    ProxyJump jumphost

Host dev-*
    User developer
    Port 2222
    IdentityFile ~/.ssh/dev_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

## 常见配置示例

### 示例1：简单VPS配置

```ssh-config
Host vps1
    HostName 203.0.113.10
    User root
    Port 22
    IdentityFile ~/.ssh/vps1_key
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

对应的`config.yaml`条目：

```yaml
tunnels:
  - remote_host: "vps1"
    remote_port: 8080
    local_port: 3000
    direction: local_to_remote
```

### 示例2：带跳板机的企业环境

```ssh-config
Host corporate-jump
    HostName jump.company.com
    User myusername
    Port 22
    IdentityFile ~/.ssh/company_key

Host internal-db
    HostName db.internal.company.com
    User dbuser
    Port 22
    IdentityFile ~/.ssh/db_key
    ProxyJump corporate-jump
```

对应的`config.yaml`条目：

```yaml
tunnels:
  - remote_host: "internal-db"
    remote_port: 5432
    local_port: 5432
    direction: remote_to_local
```

### 示例3：多环境配置

```ssh-config
Host dev-server
    HostName dev.example.com
    User developer
    Port 2222
    IdentityFile ~/.ssh/dev_key

Host staging-server
    HostName staging.example.com
    User deploy
    Port 22
    IdentityFile ~/.ssh/staging_key

Host prod-server
    HostName prod.example.com
    User deploy
    Port 22
    IdentityFile ~/.ssh/prod_key
    StrictHostKeyChecking yes
```

## 安全最佳实践

### 1. 文件权限

确保SSH文件具有正确的权限：

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/id_*.pub
chmod 600 ~/.ssh/known_hosts
```

### 2. 密钥管理

```ssh-config
Host *
    # 仅使用配置中指定的密钥
    IdentitiesOnly yes
    
    # 禁用密码认证
    PasswordAuthentication no
    PubkeyAuthentication yes
    
    # 使用强加密算法
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
```

### 3. 主机验证

```ssh-config
Host trusted-servers
    HostName *.trusted.com
    StrictHostKeyChecking yes
    UserKnownHostsFile ~/.ssh/known_hosts

Host dev-*
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel QUIET
```

## 故障排除

### 常见问题

1. **权限被拒绝**

   ```bash
   chmod 600 ~/.ssh/config
   chmod 600 ~/.ssh/private_key
   ```

2. **主机密钥验证失败**

   ```bash
   ssh-keyscan -H hostname >> ~/.ssh/known_hosts
   ```

3. **连接超时**

   ```ssh-config
   Host slow-server
       ConnectTimeout 30
       ServerAliveInterval 60
       ServerAliveCountMax 10
   ```

### 测试SSH配置

在使用autossh之前测试您的SSH配置：

```bash
# 测试连接
ssh -T hostname

# 详细输出测试
ssh -v hostname

# 测试特定配置文件
ssh -F ~/.ssh/config hostname
```

### 调试模式

在SSH配置中启用调试模式：

```ssh-config
Host debug-server
    HostName example.com
    User myuser
    LogLevel DEBUG3
    IdentityFile ~/.ssh/debug_key
```

## 与Autossh隧道集成

在autossh-tunnel项目中使用此SSH配置时：

1. **主机引用**：使用SSH配置中的`Host`名称作为`config.yaml`中的`remote_host`值
2. **身份验证**：确保`IdentityFile`路径正确且可从Docker容器内访问
3. **权限**：`~/.ssh`目录在容器中以只读方式挂载
4. **测试**：在配置隧道之前始终手动测试SSH连接

### 集成示例

SSH配置（`~/.ssh/config`）：

```ssh-config
Host tunnel-server
    HostName tunnel.example.com
    User tunneluser
    Port 22
    IdentityFile ~/.ssh/tunnel_key
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

隧道配置（`config/config.yaml`）：

```yaml
tunnels:
  - remote_host: "tunnel-server"
    remote_port: 8080
    local_port: 3000
    direction: local_to_remote
```

---

有关autossh-tunnel项目的更多信息，请参阅主要的[README](README_zh.md)。
