# SSH 交互式认证测试服务器

这个工具提供了一个 Docker 化的 SSH 服务器，配置为强制要求键盘交互式认证（模拟 2FA）。它旨在用于测试需要处理交互式提示的 SSH 客户端，例如 `autossh-cli auth`。

## 功能特性

*   **OpenSSH Server**: 在 2222 端口运行标准的 OpenSSH 服务器。
*   **键盘交互式认证**: 配置为强制要求 `keyboard-interactive` 认证。
*   **Google Authenticator**: 使用 `libpam-google-authenticator` 模拟 2FA。
*   **预配置用户**: 创建用户 `testuser`，密码为 `testpass`，并预生成了 2FA 密钥。

## 位置

该工具的源代码位于项目根目录下的 `ssh-interactive-auth-sample-server/` 目录中。

## 使用方法

### 使用 Make（推荐）

1.  **构建并启动**:
    ```bash
    cd ssh-interactive-auth-sample-server
    make up
    ```
    如果需要使用镜像加速：
    ```bash
    make up REGISTRY_MIRROR=docker.1ms.run
    ```

2.  **查看日志**:
    ```bash
    make logs
    ```

3.  **停止**:
    ```bash
    make down
    ```

4.  **清理**:
    ```bash
    make clean
    ```

### 直接使用 Docker Compose

1.  **启动**:
    ```bash
    cd ssh-interactive-auth-sample-server
    docker compose up -d --build
    ```

2.  **停止**:
    ```bash
    docker compose down
    ```

## 测试连接

要测试连接，请使用 SSH 客户端：

```bash
ssh -p 2222 testuser@localhost
```

你将会收到以下提示：
1.  **Password**: `testpass`
2.  **Verification code**: 你需要输入当前的 TOTP 代码。

### 获取验证码

由于 2FA 密钥是在容器内生成的，你有两种选择：

1.  **获取密钥**:
    运行以下命令查看密钥（第一行）：
    ```bash
    docker exec -it ssh-interactive-auth cat /home/testuser/.google_authenticator | head -n 1
    ```
    在 TOTP 应用（如 Google Authenticator）或命令行工具（如 `oathtool`）中使用此密钥生成代码。

    使用 `oathtool` 的示例：
    ```bash
    SECRET=$(docker exec ssh-interactive-auth head -n 1 /home/testuser/.google_authenticator)
    oathtool --totp -b "$SECRET"
    ```

2.  **扫描二维码**:
    如果你想用手机扫描二维码，可以查看生成的文件内容（如果生成时包含了 URL 或 ASCII 二维码，虽然当前设置是最小化的）：
    ```bash
    docker exec -it ssh-interactive-auth cat /home/testuser/.google_authenticator
    ```

## 与 Autossh Tunnel 集成

要使用此服务器测试 `autossh-cli auth`：

1.  启动测试服务器。
2.  在你的 `config.yaml` 中添加隧道配置：
    ```yaml
    - name: "test-2fa"
      remote_host: "testuser@host.docker.internal" # 或者运行测试服务器的主机 IP
      remote_port: 2222
      local_port: 22222
      interactive: true
    ```
3.  启动 autossh 容器。
4.  运行认证命令：
    ```bash
    docker compose exec -it -u myuser autossh autossh-cli auth <hash>