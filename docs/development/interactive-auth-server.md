# SSH Interactive Auth Sample Server

This tool provides a Dockerized SSH server configured to require keyboard-interactive authentication (simulating 2FA). It is designed for testing SSH clients that need to handle interactive prompts, such as `autossh-cli auth`.

## Features

*   **OpenSSH Server**: Runs a standard OpenSSH server on port 2222.
*   **Keyboard-Interactive Auth**: Configured to require `keyboard-interactive` authentication.
*   **Google Authenticator**: Uses `libpam-google-authenticator` to simulate 2FA.
*   **Pre-configured User**: Creates a user `testuser` with password `testpass` and a pre-generated 2FA secret.

## Location

The source code for this tool is located in the `ssh-interactive-auth-sample-server/` directory of the project root.

## Usage

### Using Make (Recommended)

1.  **Build and Start**:
    ```bash
    cd ssh-interactive-auth-sample-server
    make up
    ```
    To use a registry mirror:
    ```bash
    make up REGISTRY_MIRROR=docker.1ms.run
    ```

2.  **View Logs**:
    ```bash
    make logs
    ```

3.  **Stop**:
    ```bash
    make down
    ```

4.  **Clean**:
    ```bash
    make clean
    ```

### Using Docker Compose Directly

1.  **Start**:
    ```bash
    cd ssh-interactive-auth-sample-server
    docker compose up -d --build
    ```

2.  **Stop**:
    ```bash
    docker compose down
    ```

## Testing Connection

To test the connection, use an SSH client:

```bash
ssh -p 2222 testuser@localhost
```

You will be prompted for:
1.  **Password**: `testpass`
2.  **Verification code**: You need the current TOTP code.

### Getting the Verification Code

Since the 2FA secret is generated inside the container, you have two options:

1.  **Get the Secret Key**:
    Run the following command to see the secret key (first line):
    ```bash
    docker exec -it ssh-interactive-auth cat /home/testuser/.google_authenticator | head -n 1
    ```
    Use this key in a TOTP app (like Google Authenticator) or a CLI tool (like `oathtool`) to generate the code.

    Example with `oathtool`:
    ```bash
    SECRET=$(docker exec ssh-interactive-auth head -n 1 /home/testuser/.google_authenticator)
    oathtool --totp -b "$SECRET"
    ```

2.  **Scan the QR Code**:
    If you want to scan the QR code with your phone, you can view the generated file content (which might contain a URL or ASCII QR code if generated with those options, though the current setup is minimal):
    ```bash
    docker exec -it ssh-interactive-auth cat /home/testuser/.google_authenticator
    ```

## Integration with Autossh Tunnel

To test `autossh-cli auth` with this server:

1.  Start the sample server.
2.  Add a tunnel configuration to your `config.yaml`:
    ```yaml
    - name: "test-2fa"
      remote_host: "testuser@host.docker.internal" # Or the IP of the host running the sample server
      remote_port: 2222
      local_port: 22222
      interactive: true
    ```
3.  Start the autossh container.
4.  Authenticate via one of the following methods:

    **Option A: CLI**
    ```bash
    docker compose exec -it -u myuser autossh autossh-cli auth <hash>
    ```

    **Option B: Web Panel (in-browser terminal)**

    If `WS_BASE_URL` is configured on the web container, click the Start button on the interactive tunnel row in the web panel. An xterm.js terminal modal will open for you to enter your credentials. See [Web Panel - WebSocket Configuration](../web-panel.md#websocket-configuration-for-interactive-auth) for setup details.