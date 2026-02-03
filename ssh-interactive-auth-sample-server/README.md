# SSH Interactive Auth Sample Server

This project provides a Dockerized SSH server configured to require keyboard-interactive authentication (simulating 2FA). It is designed for testing SSH clients that need to handle interactive prompts, such as `autossh-cli auth`.

## Features

- **OpenSSH Server**: Runs a standard OpenSSH server on port 2222.
- **Keyboard-Interactive Auth**: Configured to require `keyboard-interactive` authentication.
- **Google Authenticator**: Uses `libpam-google-authenticator` to simulate 2FA.
- **Pre-configured User**: Creates a user `testuser` with password `testpass` and a pre-generated 2FA secret.

## Prerequisites

- Docker
- Docker Compose (optional, but recommended)
- Make (optional)

## Usage

### Using Make (Recommended)

1.  **Build and Start**:

    ```bash
    make up
    ```

    To use a registry mirror:

    ```bash
    REGISTRY_MIRROR=docker.1ms.run make up
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
    _Note: The current setup script uses `-C` which might not output the QR code to the file. Using the secret key is more reliable for testing._

## Configuration Details

- **sshd_config**:
  - `PasswordAuthentication no`
  - `ChallengeResponseAuthentication yes`
  - `UsePAM yes`
  - `AuthenticationMethods keyboard-interactive`

- **PAM**:
  - Configured in `config/pam.d/sshd` to use `pam_google_authenticator.so`.

## License

MIT
