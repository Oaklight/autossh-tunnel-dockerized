# SSH Config Configuration Guide

[中文版](../zh/ssh_config.md) | **English**

This guide explains how to configure the SSH config file (`~/.ssh/config`) for use with the autossh-tunnel-dockerized project. The SSH config file is essential for defining connection parameters and ensuring smooth tunnel establishment.

## Table of Contents

- [Overview](#overview)
- [SSH Config File Location](#ssh-config-file-location)
- [Basic Configuration](#basic-configuration)
- [Advanced Configuration](#advanced-configuration)
- [Common Configuration Examples](#common-configuration-examples)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

The SSH config file (`~/.ssh/config`) allows you to define connection parameters for SSH hosts, including:

- Host aliases and real hostnames
- Username for each host
- SSH port numbers
- Private key files
- Connection options and timeouts
- Proxy configurations

This project relies heavily on the SSH config file because:

1. **Host Identification**: The `remote_host` parameter in `config.yaml` references entries in your SSH config
2. **Authentication**: SSH config specifies which private keys to use for each host
3. **Connection Parameters**: Timeouts, ports, and other connection settings are defined here
4. **Simplified Configuration**: Instead of specifying full connection details in each tunnel, you can use simple host aliases

## SSH Config File Location

The SSH config file should be located at:

```bash
~/.ssh/config
```

If this file doesn't exist, create it:

```bash
touch ~/.ssh/config
chmod 600 ~/.ssh/config
```

## Basic Configuration

### Simple Host Configuration

```ssh-config
Host myserver
    HostName example.com
    User myuser
    Port 22
    IdentityFile ~/.ssh/id_ed25519
```

### Multiple Hosts

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

## Advanced Configuration

### Connection Optimization

```ssh-config
Host *
    # Enable connection multiplexing
    ControlMaster auto
    ControlPath ~/.ssh/sockets/ssh_mux_%h_%p_%r
    ControlPersist 600

    # Connection timeouts
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ConnectTimeout 10

    # Security settings
    StrictHostKeyChecking yes
    UserKnownHostsFile ~/.ssh/known_hosts

Host production-server
    HostName prod.example.com
    User deploy
    Port 22
    IdentityFile ~/.ssh/production_key

    # Specific settings for this host
    ServerAliveInterval 30
    TCPKeepAlive yes
    Compression yes
```

### Jump Host Configuration

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

    # Alternative syntax for older SSH versions
    # ProxyCommand ssh -W %h:%p jumphost
```

### Wildcard Patterns

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

## Common Configuration Examples

### Example 1: Simple VPS Configuration

```ssh-config
Host vps1
    HostName 203.0.113.10
    User root
    Port 22
    IdentityFile ~/.ssh/vps1_key
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Corresponding `config.yaml` entry:

```yaml
tunnels:
  - remote_host: "vps1"
    remote_port: 8080
    local_port: 3000
    direction: local_to_remote
```

### Example 2: Corporate Environment with Jump Host

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

Corresponding `config.yaml` entry:

```yaml
tunnels:
  - remote_host: "internal-db"
    remote_port: 5432
    local_port: 5432
    direction: remote_to_local
```

### Example 3: Multiple Environments

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

## Security Best Practices

### 1. File Permissions

Ensure proper permissions for SSH files:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/id_*.pub
chmod 600 ~/.ssh/known_hosts
```

### 2. Key Management

```ssh-config
Host *
    # Only use keys specified in config
    IdentitiesOnly yes

    # Disable password authentication
    PasswordAuthentication no
    PubkeyAuthentication yes

    # Use strong ciphers
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
```

### 3. Host Verification

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

## Troubleshooting

### Common Issues

1. **Permission Denied**

   ```bash
   chmod 600 ~/.ssh/config
   chmod 600 ~/.ssh/private_key
   ```

2. **Host Key Verification Failed**

   ```bash
   ssh-keyscan -H hostname >> ~/.ssh/known_hosts
   ```

3. **Connection Timeout**

   ```ssh-config
   Host slow-server
       ConnectTimeout 30
       ServerAliveInterval 60
       ServerAliveCountMax 10
   ```

### Testing SSH Configuration

Test your SSH config before using with autossh:

```bash
# Test connection
ssh -T hostname

# Test with verbose output
ssh -v hostname

# Test specific config file
ssh -F ~/.ssh/config hostname
```

### Debug Mode

Enable debug mode in your SSH config:

```ssh-config
Host debug-server
    HostName example.com
    User myuser
    LogLevel DEBUG3
    IdentityFile ~/.ssh/debug_key
```

## Integration with Autossh Tunnel

When using this SSH config with the autossh-tunnel project:

1. **Host References**: Use the `Host` names from your SSH config as `remote_host` values in `config.yaml`
2. **Authentication**: Ensure `IdentityFile` paths are correct and accessible from within the Docker container
3. **Permissions**: The `~/.ssh` directory is mounted as read-only in the container
4. **Testing**: Always test SSH connections manually before configuring tunnels

### Example Integration

SSH Config (`~/.ssh/config`):

```ssh-config
Host tunnel-server
    HostName tunnel.example.com
    User tunneluser
    Port 22
    IdentityFile ~/.ssh/tunnel_key
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Tunnel Config (`config/config.yaml`):

```yaml
tunnels:
  - remote_host: "tunnel-server"
    remote_port: 8080
    local_port: 3000
    direction: local_to_remote
```

---

For more information about the autossh-tunnel project, see the main [README](../../README_en.md).
