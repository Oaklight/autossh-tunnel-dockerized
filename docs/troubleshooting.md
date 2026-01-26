# Troubleshooting

This guide helps you diagnose and resolve common issues with SSH Tunnel Manager.

## SSH Connection Issues

### Permission Denied

**Symptom:** SSH connection fails with "Permission denied" error.

**Solutions:**

1. Check SSH key permissions:
   ```bash
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/config
   chmod 600 ~/.ssh/id_*
   chmod 644 ~/.ssh/id_*.pub
   ```

2. Verify the correct key is being used:
   ```bash
   ssh -v hostname
   ```

3. Ensure the key is added to the remote server's `authorized_keys`

### Host Key Verification Failed

**Symptom:** Connection fails with "Host key verification failed" error.

**Solutions:**

1. Add the host key to known_hosts:
   ```bash
   ssh-keyscan -H hostname >> ~/.ssh/known_hosts
   ```

2. Or connect manually first to accept the key:
   ```bash
   ssh hostname
   ```

### Connection Timeout

**Symptom:** SSH connection times out.

**Solutions:**

1. Check network connectivity:
   ```bash
   ping hostname
   ```

2. Increase timeout in SSH config:
   ```ssh-config
   Host slow-server
       ConnectTimeout 30
       ServerAliveInterval 60
       ServerAliveCountMax 10
   ```

3. Check if the SSH port is accessible:
   ```bash
   nc -zv hostname 22
   ```

## Docker Issues

### Container Won't Start

**Symptom:** Docker container fails to start.

**Solutions:**

1. Check container logs:
   ```bash
   docker compose logs autossh
   ```

2. Verify the config file exists:
   ```bash
   ls -la config/config.yaml
   ```

3. Check file permissions:
   ```bash
   ls -la ~/.ssh/
   ```

### Permission Issues in Container

**Symptom:** Container reports permission errors for SSH keys.

**Solutions:**

1. Set correct PUID/PGID:
   ```bash
   export PUID=$(id -u)
   export PGID=$(id -g)
   docker compose up -d
   ```

2. Verify the values in compose.yaml:
   ```yaml
   environment:
     - PUID=1000
     - PGID=1000
   ```

### Docker Permissions

**Symptom:** Cannot run Docker commands.

**Solution:**

Add your user to the docker group:
```bash
sudo usermod -aG docker $USER
# Log out and log back in
```

## Tunnel Issues

### Tunnel Won't Start

**Symptom:** Tunnel fails to start or immediately stops.

**Solutions:**

1. Check SSH config is correct:
   ```bash
   ssh -T hostname
   ```

2. Verify the remote host is accessible

3. Check if the port is already in use:
   ```bash
   netstat -tlnp | grep <port>
   ```

4. View tunnel logs:
   ```bash
   autossh-cli logs <hash>
   ```

### Tunnel Stops Automatically

**Symptom:** Tunnel starts but stops after some time.

**Possible causes:**

- Unstable network connection
- SSH server configuration issues
- Authentication failure

**Solutions:**

1. Check tunnel logs:
   ```bash
   autossh-cli logs <hash>
   ```

2. Increase keep-alive settings in SSH config:
   ```ssh-config
   Host *
       ServerAliveInterval 60
       ServerAliveCountMax 3
   ```

3. Check remote server's SSH configuration

### Port Already in Use

**Symptom:** Error message about port being in use.

**Solutions:**

1. Find what's using the port:
   ```bash
   lsof -i :<port>
   # or
   netstat -tlnp | grep <port>
   ```

2. Stop the conflicting process or use a different port

### Status Out of Sync

**Symptom:** Tunnel status doesn't match actual state.

**Solution:**

Clean up dead processes:
```bash
autossh-cli cleanup
```

## Web Panel Issues

### Web Panel Not Accessible

**Symptom:** Cannot access web panel at http://localhost:5000.

**Solutions:**

1. Check if the container is running:
   ```bash
   docker compose ps
   ```

2. Check container logs:
   ```bash
   docker compose logs web
   ```

3. Verify port 5000 is not in use:
   ```bash
   netstat -tlnp | grep 5000
   ```

### Changes Not Taking Effect

**Symptom:** Configuration changes don't apply.

**Solutions:**

1. Ensure you clicked "Save & Restart"

2. Check autossh container logs:
   ```bash
   docker compose logs autossh
   ```

3. Verify config file was updated:
   ```bash
   cat config/config.yaml
   ```

### Language Not Changing

**Symptom:** Language toggle doesn't work.

**Solutions:**

1. Clear browser cache and cookies

2. Check browser console for JavaScript errors

3. Try a different browser

## Configuration Issues

### Invalid YAML

**Symptom:** Configuration fails to load.

**Solutions:**

1. Validate YAML syntax:
   ```bash
   autossh-cli validate
   ```

2. Check for common YAML errors:
   - Incorrect indentation
   - Missing quotes around special characters
   - Tabs instead of spaces

### Tunnel Not Found

**Symptom:** CLI reports tunnel not found.

**Solutions:**

1. List all configured tunnels:
   ```bash
   autossh-cli list
   ```

2. Verify the hash is correct

3. Check if the configuration was saved

## Debugging

### Enable Debug Logging

Add to SSH config:
```ssh-config
Host debug-server
    LogLevel DEBUG3
```

### View All Logs

```bash
# Container logs
docker compose logs -f

# Tunnel-specific logs
autossh-cli logs <hash>

# All tunnel logs
autossh-cli logs
```

### Test SSH Connection

```bash
# Basic test
ssh -T hostname

# Verbose test
ssh -vvv hostname

# Test with specific config
ssh -F ~/.ssh/config hostname
```

## Getting Help

If you're still experiencing issues:

1. Check the [GitHub Issues](https://github.com/Oaklight/autossh-tunnel-dockerized/issues)
2. Open a new issue with:
   - Description of the problem
   - Steps to reproduce
   - Relevant logs
   - Configuration (with sensitive data removed)