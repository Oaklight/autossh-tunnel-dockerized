# Troubleshooting

This guide helps you diagnose and resolve common issues with SSH Tunnel Manager.

## SSH Connection Issues

### Tunnel Cannot Establish Connection

**Symptom:** Tunnel fails to start or immediately disconnects.

**Possible causes and solutions:**

1. **SSH key permissions are incorrect**

   Ensure the `.ssh` directory and its contents have appropriate permissions:
   
   ```bash
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/id_*
   chmod 644 ~/.ssh/*.pub
   chmod 644 ~/.ssh/config
   chmod 644 ~/.ssh/known_hosts
   ```

2. **SSH config file is missing or incorrect**

   Check if `~/.ssh/config` file exists and is correctly configured:
   
   ```bash
   cat ~/.ssh/config
   ```
   
   Refer to [SSH Configuration Guide](ssh-config.md) for proper configuration.

3. **Remote host is unreachable**

   Test SSH connection:
   
   ```bash
   ssh user@remote-host
   ```

4. **Firewall blocking connection**

   Check local and remote firewall settings to ensure SSH connections are allowed.

### Permission Denied

**Symptom:** SSH connection prompts permission denied.

**Solutions:**

1. Confirm using the correct SSH key:
   ```bash
   ssh -i ~/.ssh/id_ed25519 user@remote-host
   ```

2. Check the remote server's `authorized_keys` file:
   ```bash
   cat ~/.ssh/authorized_keys  # Execute on remote server
   ```

3. Ensure public key is added to remote server:
   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519.pub user@remote-host
   ```

## Docker Issues

### Container Won't Start

**Symptom:** `docker compose up` fails.

**Solutions:**

1. **Check Docker service status:**
   ```bash
   sudo systemctl status docker
   ```

2. **Check port conflicts:**
   ```bash
   # Check port 5000 (Web panel)
   netstat -tuln | grep 5000
   
   # Check port 8080 (API server)
   netstat -tuln | grep 8080
   ```

3. **View container logs:**
   ```bash
   docker compose logs
   ```

### Docker Permission Issues

**Symptom:** Permission denied when running Docker commands.

**Solutions:**

1. Add user to docker group:
   ```bash
   sudo usermod -aG docker $USER
   ```

2. Re-login or run:
   ```bash
   newgrp docker
   ```

### File Permission Issues

**Symptom:** Container cannot access mounted files.

**Solutions:**

1. Check PUID and PGID settings:
   ```bash
   id  # View current user's UID and GID
   ```

2. Set correct values in `compose.yaml`:
   ```yaml
   environment:
     - PUID=1000  # Replace with your UID
     - PGID=1000  # Replace with your GID
   ```

3. Restart containers:
   ```bash
   docker compose down
   docker compose up -d
   ```

## Configuration Issues

### Configuration File Format Error

**Symptom:** Tunnel cannot start, logs show YAML parsing error.

**Solutions:**

1. Validate YAML syntax:
   ```bash
   # Validate using Python
   python3 -c "import yaml; yaml.safe_load(open('config/config.yaml'))"
   ```

2. Check common errors:
   - Indentation must use spaces, not tabs
   - Ensure there's a space after colons
   - String values with special characters need quotes

3. Reference sample configuration:
   ```bash
   cat config/config.yaml.sample
   ```

### Configuration Changes Not Taking Effect

**Symptom:** Tunnel not updated after modifying configuration.

**Solutions:**

1. Check if config file monitoring is working:
   ```bash
   docker compose logs autossh | grep inotify
   ```

2. Manually restart service:
   ```bash
   docker compose restart autossh
   ```

3. Verify config file path:
   ```bash
   docker compose exec autossh cat /etc/autossh/config/config.yaml
   ```

## Tunnel Runtime Issues

### Tunnel Frequently Disconnects and Reconnects

**Symptom:** Tunnel is unstable, frequently disconnects.

**Solutions:**

1. Check network connection stability

2. Adjust autossh parameters:
   ```yaml
   environment:
     - AUTOSSH_GATETIME=30  # Increase connection stability time
   ```

3. Check remote server load and network conditions

### Port Already in Use

**Symptom:** Tunnel fails to start, prompts port is in use.

**Solutions:**

1. Find process using the port:
   ```bash
   # Linux
   sudo lsof -i :port_number
   
   # Or use
   sudo netstat -tulpn | grep port_number
   ```

2. Stop the process using the port or change tunnel configuration to use a different port

### Cannot Access Tunnel Service

**Symptom:** Tunnel shows running but cannot access service.

**Solutions:**

1. **Check tunnel direction:**
   - `local_to_remote`: Access on remote server
   - `remote_to_local`: Access on local machine

2. **Verify port binding:**
   ```bash
   # Check port listening on the appropriate machine
   netstat -tuln | grep port_number
   ```

3. **Check firewall rules:**
   ```bash
   # View firewall status
   sudo ufw status  # Ubuntu/Debian
   sudo firewall-cmd --list-all  # CentOS/RHEL
   ```

4. **Test connection:**
   ```bash
   # Local test
   curl http://localhost:port_number
   
   # Remote test
   curl http://remote-host:port_number
   ```

## Web Panel Issues

### Cannot Access Web Panel

**Symptom:** Browser cannot open `http://localhost:5000`.

**Solutions:**

1. Check Web container status:
   ```bash
   docker compose ps web
   ```

2. View Web container logs:
   ```bash
   docker compose logs web
   ```

3. Verify port mapping:
   ```bash
   docker compose port web 5000
   ```

4. Check API connection:
   ```bash
   # Confirm API_BASE_URL is set correctly in compose.yaml
   docker compose exec web env | grep API_BASE_URL
   ```

### Web Panel Shows Blank or Error

**Symptom:** Web panel loads but displays abnormally.

**Solutions:**

1. Clear browser cache

2. Check browser console for errors (F12)

3. Verify API server is running:
   ```bash
   curl http://localhost:8080/status
   ```

## API Issues

### API Request Fails

**Symptom:** CLI commands or HTTP API requests return errors.

**Solutions:**

1. Confirm API is enabled:
   ```yaml
   environment:
     - API_ENABLE=true
   ```

2. Check API server logs:
   ```bash
   docker compose logs autossh | grep api
   ```

3. Test API connection:
   ```bash
   curl http://localhost:8080/list
   ```

## Logs and Debugging

### Viewing Logs

```bash
# View all container logs
docker compose logs

# View specific container logs
docker compose logs autossh
docker compose logs web

# Follow logs in real-time
docker compose logs -f

# View last 100 lines of logs
docker compose logs --tail=100
```

### Entering Container for Debugging

```bash
# Enter autossh container
docker compose exec autossh sh

# Enter web container
docker compose exec web sh

# Check processes inside container
ps aux

# Check network connections
netstat -tuln
```

### Enable Verbose Logging

Add debug environment variables in `compose.yaml`:

```yaml
environment:
  - DEBUG=true
  - VERBOSE=true
```

## Performance Issues

### Container Using Too Many Resources

**Solutions:**

1. Check resource usage:
   ```bash
   docker stats
   ```

2. Limit container resources:
   ```yaml
   services:
     autossh:
       deploy:
         resources:
           limits:
             cpus: '0.5'
             memory: 512M
   ```

3. Clean up unused Docker resources:
   ```bash
   docker system prune -a
   ```

## Getting Help

If the above methods cannot solve your problem:

1. **Check project documentation:**
   - [Getting Started](getting-started.md)
   - [Architecture](architecture.md)
   - [API Documentation](api/index.md)

2. **Submit an Issue:**
   Visit [GitHub Issues](https://github.com/Oaklight/autossh-tunnel-dockerized/issues) to submit a problem

3. **Provide information:**
   - Operating system and version
   - Docker and Docker Compose versions
   - Complete error logs
   - Configuration file contents (hide sensitive information)
   - Steps to reproduce the problem