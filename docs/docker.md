# Docker 深入解析

本页面介绍项目的 Docker 构建基础设施、优化技巧和 CI/CD 流水线。基本部署设置请参阅[快速入门](getting-started.md)，容器架构和网络请参阅[架构说明](architecture.md)。

## Docker 镜像概览

项目向 Docker Hub 发布两个 Docker 镜像：

| 镜像 | 用途 | 基础镜像 | 构建阶段 |
|------|------|----------|----------|
| [`oaklight/autossh-tunnel`](https://hub.docker.com/r/oaklight/autossh-tunnel) | 核心隧道管理 | Alpine 3.22.0 | 2（构建 + 运行时） |
| [`oaklight/autossh-tunnel-web-panel`](https://hub.docker.com/r/oaklight/autossh-tunnel-web-panel) | Web 管理界面 | Alpine 3.22.0 | 2（构建 + 运行时） |

两个镜像均支持 **8 种架构**，最终镜像体积约 18-20 MB。

## Dockerfile 详解

### autossh-tunnel (`Dockerfile`)

2 阶段构建：编译 Go WebSocket 服务端，并与 Shell 脚本和运行时依赖一起打包。

```dockerfile
# 阶段 1：构建 Go WebSocket 服务端二进制文件
ARG REGISTRY_MIRROR=docker.io
FROM ${REGISTRY_MIRROR}/library/golang:1.24-alpine AS ws-builder
ARG GOPROXY
WORKDIR /app
COPY ws-server .
RUN rm -f go.mod go.sum && \
    if [ -n "$GOPROXY" ]; then export GOPROXY="$GOPROXY"; fi && \
    go mod init ws-server && go mod tidy && go mod download
RUN GOMAXPROCS=1 CGO_ENABLED=0 go build -ldflags="-s -w" -trimpath -o ws-server .

# 阶段 2：包含 autossh 和所有脚本的运行时镜像
FROM ${REGISTRY_MIRROR}/library/alpine:3.22.0 AS base
ARG VERSION=dev
RUN apk add --no-cache autossh flock inotify-tools netcat-openbsd socat su-exec
RUN addgroup -g 1000 mygroup && adduser -D -u 1000 -G mygroup myuser
COPY autossh-cli /usr/local/bin/autossh-cli
COPY scripts /usr/local/bin/scripts
COPY spinoff_monitor.sh /usr/local/bin/spinoff_monitor.sh
COPY entrypoint.sh /entrypoint.sh
COPY --from=ws-builder /app/ws-server /usr/local/bin/ws-server
# ... chmod, 版本嵌入, 入口点设置
```

要点：

- **阶段 1** (`ws-builder`) 仅用于编译 Go 二进制文件——Go 工具链不会出现在最终镜像中
- **阶段 2** (`base`) 通过 `apk` 安装轻量运行时依赖，并复制所有脚本和编译好的二进制文件
- `COPY --from=ws-builder` 连接两个阶段

### autossh-tunnel-web-panel (`Dockerfile.web`)

Web 面板 Go 服务端的 2 阶段构建。

```dockerfile
# 阶段 1：构建 Web 面板二进制文件
ARG REGISTRY_MIRROR=docker.io
FROM ${REGISTRY_MIRROR}/library/golang:tip-alpine AS builder
ARG GOPROXY
ARG VERSION=dev
WORKDIR /app
COPY web .
RUN rm -f go.mod go.sum && go mod init app
RUN if [ -n "$GOPROXY" ]; then export GOPROXY="$GOPROXY"; fi && \
    go mod tidy && go mod download
RUN GOMAXPROCS=1 CGO_ENABLED=0 go build \
    -ldflags="-s -w -X main.version=$VERSION" \
    -trimpath -o app .

# 阶段 2：最小运行时
ARG REGISTRY_MIRROR=docker.io
FROM ${REGISTRY_MIRROR}/library/alpine:3.22.0
RUN apk add --no-cache su-exec
RUN addgroup -g 1000 mygroup && adduser -D -u 1000 -G mygroup myuser
WORKDIR /app
COPY --from=builder /app/app .
COPY web/static /app/static
COPY web/templates /app/templates
COPY web/entrypoint.sh /entrypoint.sh
```

!!! note "为什么使用 `golang:tip-alpine`？"
    Web 面板使用 `golang:tip-alpine`（最新开发版本），而非 ws-server 使用的稳定版 `golang:1.24-alpine`。这样可以使用 Web 面板所需的最新 Go 标准库特性。

## 构建优化技巧

### Go 二进制优化

项目中所有 Go 二进制文件都使用三个优化参数编译：

```bash
GOMAXPROCS=1 CGO_ENABLED=0 go build -ldflags="-s -w" -trimpath -o binary .
```

| 参数 | 用途 | 影响 |
|------|------|------|
| `CGO_ENABLED=0` | 静态链接，不依赖 C 库 | 对 Alpine（musl vs glibc）至关重要；生成完全自包含的二进制文件 |
| `-ldflags="-s -w"` | 去除符号表 (`-s`) 和 DWARF 调试信息 (`-w`) | 减小约 30% 的二进制体积 |
| `-trimpath` | 从二进制文件中移除本地文件系统路径 | 可重复构建；防止路径泄露 |

Web 面板额外使用 `-X main.version=$VERSION` 在编译时嵌入版本字符串。

### GOMAXPROCS=1 应对 QEMU 交叉编译

```dockerfile
RUN GOMAXPROCS=1 CGO_ENABLED=0 go build ...
```

`GOMAXPROCS=1` 强制 Go 单线程编译。这可以防止 QEMU 用户模式模拟在交叉编译某些架构（特别是 arm/v6、arm/v7、386、riscv64）时因并发 goroutine 导致的死锁。

!!! warning "什么时候需要关注？"
    仅在通过 `docker buildx` + QEMU **交叉编译**时才需要。在目标架构上原生构建不需要此设置。少量的性能损失（稍慢的构建速度）相比可靠性的提升微不足道。

### Alpine Linux 基础镜像

Alpine Linux 3.22.0 提供约 5 MB 的基础镜像，使最终镜像保持在 20 MB 以下。Alpine 使用 **musl libc** 而非 glibc，这就是 `CGO_ENABLED=0`（静态链接）至关重要的原因——动态链接的 Go 二进制文件在运行时会因找不到 glibc 而失败。

运行时依赖通过 `apk add --no-cache` 安装：

- `autossh` — 持久 SSH 连接
- `socat` — API 服务器 socket 处理
- `su-exec` — 轻量级权限降级（Alpine 上 `gosu` 的替代品）
- `inotify-tools` — 配置文件变更监控
- `flock` — 并发访问文件锁
- `netcat-openbsd` — 网络工具

## 本地构建

### Makefile 目标参考

| 目标 | 说明 |
|------|------|
| `build-autossh` | 构建多架构 autossh-tunnel 镜像（仅缓存） |
| `build-web` | 构建多架构 web-panel 镜像（仅缓存） |
| `build` | 构建两个镜像 |
| `push-autossh` | 推送 autossh-tunnel 到 Docker Hub |
| `push-web` | 推送 web-panel 到 Docker Hub |
| `push` | 推送两个镜像 |
| `build-and-push-autossh` | 构建并推送 autossh-tunnel |
| `build-and-push-web` | 构建并推送 web-panel |
| `all` | 构建并推送两个镜像（默认目标） |
| `build-test-autossh` | 构建 autossh-tunnel 用于本地测试（仅 amd64） |
| `build-test-web` | 构建 web-panel 用于本地测试（仅 amd64） |
| `build-test` | 构建两个镜像用于本地测试 |
| `clean` | 删除本地 Docker 镜像 |
| `clean-cache` | 清理 Docker buildx 缓存 |

### 镜像仓库镜像支持 (`REGISTRY_MIRROR`)

所有 `FROM` 指令都使用可配置的镜像仓库镜像：

```dockerfile
ARG REGISTRY_MIRROR=docker.io
FROM ${REGISTRY_MIRROR}/library/golang:1.24-alpine AS ws-builder
```

这允许在 Docker Hub 被限速或封锁的地区进行构建：

```bash
# 使用镜像源拉取所有基础镜像
REGISTRY_MIRROR=docker.1ms.run make build

# 或使用特定镜像源
REGISTRY_MIRROR=docker.xuanyuan.me make build-test
```

`REGISTRY_MIRROR` 变量默认为 `docker.io`（官方 Docker Hub）。Makefile 将其作为构建参数传递给所有 `docker buildx build` 命令。

### Go 模块代理支持 (`GOPROXY`)

Go 模块下载可通过代理加速：

```bash
# 使用 Go 代理（国内推荐）
GOPROXY=https://goproxy.cn make build
```

在 Dockerfile 中，`GOPROXY` 仅在设置时才会被导出：

```dockerfile
ARG GOPROXY
RUN if [ -n "$GOPROXY" ]; then export GOPROXY="$GOPROXY"; fi && \
    go mod tidy && go mod download
```

Makefile 仅在 `GOPROXY` 非空时才包含该构建参数：

```makefile
ifneq ($(GOPROXY),)
BUILD_ARGS += --build-arg GOPROXY=$(GOPROXY)
endif
```

### 使用 `--load` 进行本地测试

多架构构建无法加载到本地 Docker daemon（它们会生成多平台 manifest）。`build-test` 目标构建**单架构 (amd64)** 镜像并使用 `--load` 使其在本地可用：

```bash
# 构建用于本地测试
make build-test

# 然后使用开发 compose 运行
docker compose -f compose.dev.yaml up
```

!!! tip
    开发迭代使用 `build-test`。发布使用 `build` + `push`。

## 多架构构建

### 支持的平台

| 平台 | 架构 | 常见设备 |
|------|------|----------|
| `linux/amd64` | x86-64 | 标准服务器、台式机、云虚拟机 |
| `linux/arm64/v8` | ARM 64 位 | Raspberry Pi 4/5、Apple Silicon (Linux)、AWS Graviton |
| `linux/arm/v7` | ARM 32 位 v7 | Raspberry Pi 2/3（32 位系统）、旧版 ARM 开发板 |
| `linux/arm/v6` | ARM 32 位 v6 | Raspberry Pi Zero、Pi 1 |
| `linux/386` | x86 32 位 | 旧版 32 位系统 |
| `linux/ppc64le` | PowerPC 64 位 LE | IBM POWER 系统 |
| `linux/s390x` | IBM Z | IBM 大型机 |
| `linux/riscv64` | RISC-V 64 位 | RISC-V 开发板 |

### buildx + QEMU 工作原理

多架构构建使用 Docker Buildx 配合 QEMU 用户模式模拟：

1. **QEMU** 在构建主机上模拟目标 CPU 架构
2. **Buildx** 协调各平台的并行构建
3. 每个平台的层独立构建，最终推送为多平台 manifest

不需要真实硬件——标准 x86-64 机器即可为所有 8 个平台构建。代价是构建时间：模拟构建比原生构建慢很多。

### 构建与推送工作流

Makefile 将构建和推送分离：

```bash
# 步骤 1：构建并缓存所有平台层（不推送）
make build

# 步骤 2：验证构建成功后，从缓存推送
make push
```

这种分离允许在发布前验证构建。`build-and-push-*` 目标将两个步骤合并以方便使用。

## 入口点模式

### autossh 容器 (`entrypoint.sh`)

主入口点以 root 身份运行，在降权前执行初始化：

1. **导出环境变量**供 autossh-cli 使用（`AUTOSSH_CONFIG_FILE`、`SSH_CONFIG_DIR`、`AUTOSSH_STATE_FILE`、WebSocket 变量）
2. **动态 PUID/PGID** — 通过 `sed` 就地修改 `/etc/passwd` 和 `/etc/group` 以匹配宿主机用户的 UID/GID：
    ```bash
    sed -i "s/^myuser:x:[0-9]*:[0-9]*:/myuser:x:$PUID:$PGID:/" /etc/passwd
    sed -i "s/^mygroup:x:[0-9]*:/mygroup:x:$PGID:/" /etc/group
    ```
3. **初始化状态** — 创建 `/tmp` 目录，清理旧日志和状态文件，设置权限
4. **修正 home 目录权限** — `chown` home 目录 `/home/myuser`，使容器用户能够创建文件（如 interactive auth 所需的 `~/.autossh-sockets`）
5. **修正配置目录权限** — `chown` 配置目录（Docker 在宿主机目录不存在时以 root 身份创建 bind mount 目录）
6. **权限降级** — `exec su-exec myuser "$@"` 将 shell 替换为以 `myuser` 身份运行的目标命令

!!! note "su-exec vs gosu"
    Alpine 中优先使用 `su-exec`，因为其二进制文件更小。与 `sudo` 或 `su` 不同，`su-exec` 直接 `exec()` 目标命令，避免了父进程开销。

用户端 PUID/PGID 配置请参阅[快速入门](getting-started.md)。

### Web 容器 (`web/entrypoint.sh`)

Web 面板的入口点非常简单——仅降权：

```bash
#!/bin/sh
exec su-exec myuser "$@"
```

无需状态清理，因为 Web 面板是无状态的代理服务器。

### 版本嵌入

版本信息在构建流水线中流转：

1. `Makefile` 或 CI 设置 `VERSION` 构建参数
2. **autossh 容器**：`echo "$VERSION" > /etc/autossh-version` — 运行时由 `spinoff_monitor.sh` 读取用于启动横幅
3. **web 容器**：`-X main.version=$VERSION` 写入 `ldflags` — 直接编译到 Go 二进制文件中

## CI/CD 流水线

### 流水线概览 (`docker-publish.yml`)

Docker 发布工作流在以下情况触发：

- **GitHub Release** — 发布 release 时自动触发
- **手动调度** — 通过 `workflow_dispatch` 输入版本号

```
┌─────────────┐    ┌──────────┐    ┌────────────┐    ┌──────────────┐
│   触发       │───>│ go-test  │───>│ build-and- │───>│  Docker Hub  │
│ (release 或  │    │ go-fmt   │    │   push     │    │  （每镜像    │
│  手动调度)   │    │ shell-   │    │（2 个镜像  │    │   8 架构）   │
│              │    │ lint     │    │  并行）     │    │              │
└─────────────┘    └──────────┘    └────────────┘    └──────────────┘
```

### 构建策略

工作流使用**策略矩阵**并行构建两个镜像：

```yaml
strategy:
  matrix:
    include:
      - image: oaklight/autossh-tunnel
        dockerfile: Dockerfile
        platforms: linux/amd64,linux/arm64/v8,...
      - image: oaklight/autossh-tunnel-web-panel
        dockerfile: Dockerfile.web
        platforms: linux/amd64,linux/arm64/v8,...
```

每个矩阵条目设置：

1. **QEMU** (`docker/setup-qemu-action@v3`) — CPU 模拟
2. **Buildx** (`docker/setup-buildx-action@v3`) — 多平台构建器
3. **Docker Hub 登录** (`docker/login-action@v3`) — 仓库认证
4. **构建并推送** (`docker/build-push-action@v6`) — 构建所有平台并推送

镜像同时打上 `latest` 和版本标签（如 `v2.3.1`）。

### 构建缓存

流水线使用 GitHub Actions 缓存存储 Docker 层：

```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

`mode=max` 缓存所有层（不仅是最终镜像层），在只有应用代码变更而基础镜像和依赖不变时，显著加速重新构建。

### CI 冒烟测试 (`ci.yml`)

常规 CI 流水线（push/PR 触发）包含 Docker 构建任务：

1. 单架构构建两个镜像（无 `--platform`）以提高速度
2. 对 autossh-tunnel 镜像运行冒烟测试：
    ```bash
    docker run --rm autossh-tunnel:test \
        ls -la /usr/local/bin/ws-server /usr/local/bin/autossh-cli
    ```

这可以在不花费多架构构建时间的情况下尽早发现构建失败。
