# Docker Build Optimization Guide

This document explains how to leverage Docker cache mechanisms to speed up the build process.

## Optimization Details

### 1. Dockerfile.web Optimization

#### Multi-stage Build Cache

- **Layered Copying**: Copy `go.mod` and `go.sum` first, then copy source code
- **Dependency Cache**: Go module download layer is cached and only re-downloaded when dependencies change
- **Build Optimization**: Use `-ldflags="-w -s"` to reduce binary size

#### Cache Strategy

```dockerfile
# Layer 1: Copy go.mod and go.sum (low change frequency)
COPY web/go.* ./

# Layer 2: Download dependencies (only re-executed when dependencies change)
RUN go mod download

# Layer 3: Copy source code (high change frequency)
COPY web/*.go ./

# Layer 4: Build (only re-executed when source code changes)
RUN go build ...
```

### 2. Makefile Optimization

#### Optimized Build Commands

**`build-test-autossh`** - Build autossh image (optimized)

```bash
make build-test-autossh
```

- Uses local cache (`/tmp/.buildx-cache-autossh`)
- Only builds amd64 architecture
- Tagged as `latest`
- Supports incremental builds

**`build-test-web`** - Build web panel image (optimized)

```bash
make build-test-web
```

- Uses local cache (`/tmp/.buildx-cache-web`)
- Only builds amd64 architecture
- Tagged as `latest`
- Supports incremental builds with Go dependency caching

**`clean-cache`** - Clean build cache

```bash
make clean-cache
```

- Removes all build cache directories
- Used to resolve cache corruption or force complete rebuild

### 3. .dockerignore Optimization

Excludes unnecessary files to reduce build context size:

- Documentation files (_.md, README_, LICENSE)
- Development tool configurations (.vscode, Makefile)
- Temporary files and caches
- Git-related files

## Usage Recommendations

### First Build

```bash
# Build autossh image
make build-test-autossh

# Build web panel image
make build-test-web
```

### Daily Development

**Method 1: Use compose.dev.yaml (Recommended)**

```bash
# Build and run locally
docker compose -f compose.dev.yaml up --build
```

**Method 2: Use Makefile + compose.yaml**

```bash
# Build images first
make build-test-web

# Then run
docker compose up
```

### Clean Cache

```bash
# If encountering cache issues, clean and rebuild
make clean-cache
make build-test-web
```

## Performance Comparison

### Before Optimization

- First build: ~2-3 minutes
- Rebuild after code changes: ~2-3 minutes (re-downloads dependencies every time)

### After Optimization

- First build: ~2-3 minutes
- Rebuild after code changes: ~10-30 seconds (reuses dependency cache) ✨
- Only static file changes: ~5-10 seconds

## Technical Details

### Docker BuildKit Cache

Uses `--cache-from` and `--cache-to` options:

- `type=local,src=/tmp/.buildx-cache-web` - Read from local cache
- `type=local,dest=/tmp/.buildx-cache-web,mode=max` - Save all layers to cache

### Go Module Cache

Go modules are downloaded to Docker layers. As long as `go.mod` and `go.sum` don't change, the cache is reused.

### Build Optimization Flags

- `CGO_ENABLED=0` - Disable CGO, generate static binary
- `-ldflags="-w -s"` - Remove debug information, reduce file size
  - `-w` - Remove DWARF debug information
  - `-s` - Remove symbol table

## Troubleshooting

### Cache Corruption

If encountering strange build errors:

```bash
make clean-cache
docker system prune -f
make build-test-web
```

### Dependency Updates

After modifying `web/go.mod`:

```bash
# Cache will automatically invalidate and re-download dependencies
make build-test-web
```

### Complete Rebuild

```bash
docker buildx build --no-cache -f Dockerfile.web -t oaklight/autossh-tunnel-web-panel:latest --load .
```
