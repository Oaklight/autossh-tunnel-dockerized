# Docker Deep Dive

This page covers the Docker build infrastructure, optimization techniques, and CI/CD pipeline behind the project. For basic setup and deployment, see [Quick Start](getting-started.md). For container architecture and networking, see [Architecture](architecture.md).

## Docker Images at a Glance

The project publishes two Docker images to Docker Hub:

| Image | Purpose | Base | Stages |
|-------|---------|------|--------|
| [`oaklight/autossh-tunnel`](https://hub.docker.com/r/oaklight/autossh-tunnel) | Core tunnel manager | Alpine 3.22.0 | 2 (builder + runtime) |
| [`oaklight/autossh-tunnel-web-panel`](https://hub.docker.com/r/oaklight/autossh-tunnel-web-panel) | Web management UI | Alpine 3.22.0 | 2 (builder + runtime) |

Both images support **8 architectures** and produce minimal images (~18-20 MB).

## Dockerfile Walkthrough

### autossh-tunnel (`Dockerfile`)

A 2-stage build that compiles a Go WebSocket server and packages it with shell scripts and runtime dependencies.

```dockerfile
# Stage 1: Build the Go WebSocket server binary
ARG REGISTRY_MIRROR=docker.io
FROM ${REGISTRY_MIRROR}/library/golang:1.24-alpine AS ws-builder
ARG GOPROXY
WORKDIR /app
COPY ws-server .
RUN rm -f go.mod go.sum && \
    if [ -n "$GOPROXY" ]; then export GOPROXY="$GOPROXY"; fi && \
    go mod init ws-server && go mod tidy && go mod download
RUN GOMAXPROCS=1 CGO_ENABLED=0 go build -ldflags="-s -w" -trimpath -o ws-server .

# Stage 2: Runtime image with autossh and all scripts
FROM ${REGISTRY_MIRROR}/library/alpine:3.22.0 AS base
ARG VERSION=dev
RUN apk add --no-cache autossh flock inotify-tools netcat-openbsd socat su-exec
RUN addgroup -g 1000 mygroup && adduser -D -u 1000 -G mygroup myuser
COPY autossh-cli /usr/local/bin/autossh-cli
COPY scripts /usr/local/bin/scripts
COPY spinoff_monitor.sh /usr/local/bin/spinoff_monitor.sh
COPY entrypoint.sh /entrypoint.sh
COPY --from=ws-builder /app/ws-server /usr/local/bin/ws-server
# ... chmod, version embed, entrypoint setup
```

Key points:

- **Stage 1** (`ws-builder`) only exists to compile the Go binary — the Go toolchain never ships in the final image
- **Stage 2** (`base`) installs lightweight runtime dependencies via `apk` and copies all scripts + the compiled binary
- `COPY --from=ws-builder` bridges the two stages

### autossh-tunnel-web-panel (`Dockerfile.web`)

A 2-stage build for the web panel Go server.

```dockerfile
# Stage 1: Build the web panel binary
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

# Stage 2: Minimal runtime
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

!!! note "Why `golang:tip-alpine`?"
    The web panel uses `golang:tip-alpine` (latest development version) instead of the stable `golang:1.24-alpine` used by ws-server. This provides access to the latest Go standard library features used by the web panel.

## Build Optimization Techniques

### Go Binary Optimization

Every Go binary in this project is compiled with three optimization flags:

```bash
GOMAXPROCS=1 CGO_ENABLED=0 go build -ldflags="-s -w" -trimpath -o binary .
```

| Flag | Purpose | Impact |
|------|---------|--------|
| `CGO_ENABLED=0` | Static linking, no C library dependency | Essential for Alpine (musl vs glibc); produces fully self-contained binary |
| `-ldflags="-s -w"` | Strip symbol table (`-s`) and DWARF debug info (`-w`) | Reduces binary size by ~30% |
| `-trimpath` | Remove local filesystem paths from binary | Reproducible builds; no path leakage |

The web panel additionally uses `-X main.version=$VERSION` to embed the version string at compile time.

### GOMAXPROCS=1 for QEMU Cross-Compilation

```dockerfile
RUN GOMAXPROCS=1 CGO_ENABLED=0 go build ...
```

`GOMAXPROCS=1` forces single-threaded Go compilation. This prevents deadlocks that occur when QEMU user-mode emulation runs concurrent goroutines during cross-compilation for certain architectures (notably arm/v6, arm/v7, 386, riscv64).

!!! warning "When does this matter?"
    Only during **cross-compilation** via `docker buildx` + QEMU. Native builds on the target architecture don't need this. The small performance cost (slightly slower builds) is negligible compared to the reliability gain.

### Alpine Linux Base Image

Alpine Linux 3.22.0 provides a ~5 MB base image, keeping final images under 20 MB. Alpine uses **musl libc** instead of glibc, which is why `CGO_ENABLED=0` (static linking) is essential — dynamically linked Go binaries would fail to find glibc at runtime.

Runtime dependencies are installed via `apk add --no-cache`:

- `autossh` — persistent SSH connections
- `socat` — API server socket handling
- `su-exec` — lightweight privilege dropping (Alpine alternative to `gosu`)
- `inotify-tools` — config file change monitoring
- `flock` — file locking for concurrent access
- `netcat-openbsd` — network utilities

## Building Locally

### Makefile Target Reference

| Target | Description |
|--------|-------------|
| `build-autossh` | Build multi-arch autossh-tunnel image (cache only) |
| `build-web` | Build multi-arch web-panel image (cache only) |
| `build` | Build both images |
| `push-autossh` | Push autossh-tunnel to Docker Hub |
| `push-web` | Push web-panel to Docker Hub |
| `push` | Push both images |
| `build-and-push-autossh` | Build and push autossh-tunnel |
| `build-and-push-web` | Build and push web-panel |
| `all` | Build and push both (default target) |
| `build-test-autossh` | Build autossh-tunnel for local testing (amd64 only) |
| `build-test-web` | Build web-panel for local testing (amd64 only) |
| `build-test` | Build both for local testing |
| `clean` | Remove local Docker images |
| `clean-cache` | Remove Docker buildx cache |

### Registry Mirror Support (`REGISTRY_MIRROR`)

All `FROM` instructions use a configurable registry mirror:

```dockerfile
ARG REGISTRY_MIRROR=docker.io
FROM ${REGISTRY_MIRROR}/library/golang:1.24-alpine AS ws-builder
```

This allows building in regions where Docker Hub is throttled or blocked:

```bash
# Use a mirror for all base image pulls
REGISTRY_MIRROR=docker.1ms.run make build

# Or for a specific mirror
REGISTRY_MIRROR=docker.xuanyuan.me make build-test
```

The `REGISTRY_MIRROR` variable defaults to `docker.io` (official Docker Hub). The Makefile passes it as a build argument to all `docker buildx build` commands.

### Go Module Proxy Support (`GOPROXY`)

Go module downloads can be routed through a proxy for faster builds:

```bash
# Use a Go proxy (useful in China)
GOPROXY=https://goproxy.cn make build
```

In the Dockerfile, `GOPROXY` is conditionally exported only when set:

```dockerfile
ARG GOPROXY
RUN if [ -n "$GOPROXY" ]; then export GOPROXY="$GOPROXY"; fi && \
    go mod tidy && go mod download
```

The Makefile only includes the build argument when `GOPROXY` is non-empty:

```makefile
ifneq ($(GOPROXY),)
BUILD_ARGS += --build-arg GOPROXY=$(GOPROXY)
endif
```

### Local Testing with `--load`

Multi-arch builds cannot be loaded into the local Docker daemon (they produce manifests for multiple platforms). The `build-test` targets build **single-arch (amd64)** images with `--load` to make them available locally:

```bash
# Build for local testing
make build-test

# Then run with dev compose
docker compose -f compose.dev.yaml up
```

!!! tip
    Use `build-test` for development iteration. Use `build` + `push` for publishing.

## Multi-Architecture Builds

### Supported Platforms

| Platform | Architecture | Common Devices |
|----------|-------------|----------------|
| `linux/amd64` | x86-64 | Standard servers, desktops, cloud VMs |
| `linux/arm64/v8` | ARM 64-bit | Raspberry Pi 4/5, Apple Silicon (Linux), AWS Graviton |
| `linux/arm/v7` | ARM 32-bit v7 | Raspberry Pi 2/3 (32-bit OS), older ARM boards |
| `linux/arm/v6` | ARM 32-bit v6 | Raspberry Pi Zero, Pi 1 |
| `linux/386` | x86 32-bit | Legacy 32-bit systems |
| `linux/ppc64le` | PowerPC 64-bit LE | IBM POWER systems |
| `linux/s390x` | IBM Z | IBM mainframes |
| `linux/riscv64` | RISC-V 64-bit | RISC-V development boards |

### How buildx + QEMU Works

Multi-arch builds use Docker Buildx with QEMU user-mode emulation:

1. **QEMU** emulates the target CPU architecture on the build host
2. **Buildx** orchestrates parallel builds for each platform
3. Each platform's layers are built independently and pushed as a multi-platform manifest

No real hardware is needed — a standard x86-64 machine can build for all 8 platforms. The trade-off is build time: emulated builds are significantly slower than native builds.

### Build vs Push Workflow

The Makefile separates building and pushing:

```bash
# Step 1: Build and cache all platform layers (no push)
make build

# Step 2: Verify builds succeeded, then push from cache
make push
```

This separation allows build verification before publishing. The `build-and-push-*` targets combine both steps for convenience.

## Entrypoint Pattern

### autossh Container (`entrypoint.sh`)

The main entrypoint runs as root and performs initialization before dropping privileges:

1. **Export environment variables** for autossh-cli (`AUTOSSH_CONFIG_FILE`, `SSH_CONFIG_DIR`, `AUTOSSH_STATE_FILE`, WebSocket variables)
2. **Dynamic PUID/PGID** — modifies `/etc/passwd` and `/etc/group` in-place via `sed` to match the host user's UID/GID:
    ```bash
    sed -i "s/^myuser:x:[0-9]*:[0-9]*:/myuser:x:$PUID:$PGID:/" /etc/passwd
    sed -i "s/^mygroup:x:[0-9]*:/mygroup:x:$PGID:/" /etc/group
    ```
3. **Initialize state** — create `/tmp` directories, clean old logs and state files, set permissions
4. **Fix home directory ownership** — `chown` the home directory `/home/myuser` so the container user can create files (e.g., `~/.autossh-sockets` for interactive auth)
5. **Fix config ownership** — `chown` the config directory (Docker creates bind-mount directories as root if they don't exist on the host)
6. **Privilege drop** — `exec su-exec myuser "$@"` replaces the shell with the target command running as `myuser`

!!! note "su-exec vs gosu"
    `su-exec` is preferred in Alpine for its smaller binary size. Unlike `sudo` or `su`, `su-exec` directly `exec()`s the target command, avoiding a parent process overhead.

For user-facing PUID/PGID configuration, see [Quick Start](getting-started.md).

### Web Container (`web/entrypoint.sh`)

The web panel entrypoint is minimal — it only drops privileges:

```bash
#!/bin/sh
exec su-exec myuser "$@"
```

No state cleanup is needed because the web panel is a stateless proxy server.

### Version Embedding

Version information flows through the build pipeline:

1. `Makefile` or CI sets the `VERSION` build argument
2. **autossh container**: `echo "$VERSION" > /etc/autossh-version` — read at runtime by `spinoff_monitor.sh` for the startup banner
3. **web container**: `-X main.version=$VERSION` in `ldflags` — compiled directly into the Go binary

## CI/CD Pipeline

### Pipeline Overview (`docker-publish.yml`)

The Docker publish workflow triggers on:

- **GitHub Release** — automatically when a release is published
- **Manual dispatch** — via `workflow_dispatch` with a version input

```
┌─────────────┐    ┌──────────┐    ┌────────────┐    ┌──────────────┐
│   Trigger    │───>│ go-test  │───>│ build-and- │───>│  Docker Hub  │
│ (release or  │    │ go-fmt   │    │   push     │    │   (8 arch    │
│  dispatch)   │    │ shell-   │    │ (2 images  │    │   per image) │
│              │    │ lint     │    │  parallel) │    │              │
└─────────────┘    └──────────┘    └────────────┘    └──────────────┘
```

### Build Strategy

The workflow uses a **strategy matrix** to build both images in parallel:

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

Each matrix entry sets up:

1. **QEMU** (`docker/setup-qemu-action@v3`) — CPU emulation
2. **Buildx** (`docker/setup-buildx-action@v3`) — multi-platform builder
3. **Docker Hub login** (`docker/login-action@v3`) — registry authentication
4. **Build and push** (`docker/build-push-action@v6`) — builds all platforms and pushes

Images are tagged with both `latest` and the version tag (e.g., `v2.3.1`).

### Build Cache

The pipeline uses GitHub Actions cache for Docker layers:

```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

`mode=max` caches all layers (not just the final image layers), significantly speeding up rebuilds when only application code changes while base images and dependencies remain the same.

### CI Smoke Tests (`ci.yml`)

The regular CI pipeline (triggered on push/PR) includes a Docker build job that:

1. Builds both images single-arch (no `--platform`) for speed
2. Runs a smoke test on the autossh-tunnel image:
    ```bash
    docker run --rm autossh-tunnel:test \
        ls -la /usr/local/bin/ws-server /usr/local/bin/autossh-cli
    ```

This catches build failures early without the time cost of multi-arch builds.
