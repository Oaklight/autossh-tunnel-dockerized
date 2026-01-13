# Docker 构建优化说明

本文档说明了如何利用 Docker 缓存机制加速构建过程。

## 优化内容

### 1. Dockerfile.web 优化

#### 多阶段构建缓存

- **分层复制**：先复制 `go.mod` 和 `go.sum`，再复制源代码
- **依赖缓存**：Go 模块下载层会被缓存，只有在依赖变化时才重新下载
- **构建优化**：使用 `-ldflags="-w -s"` 减小二进制文件大小

#### 缓存策略

```dockerfile
# 第一层：复制 go.mod 和 go.sum（变化频率低）
COPY web/go.* ./

# 第二层：下载依赖（只有依赖变化时才重新执行）
RUN go mod download

# 第三层：复制源代码（变化频率高）
COPY web/*.go ./

# 第四层：构建（只有源代码变化时才重新执行）
RUN go build ...
```

### 2. Makefile 优化

#### 优化的构建命令

**`build-test-autossh`** - 构建 autossh 镜像（已优化）

```bash
make build-test-autossh
```

- 使用本地缓存 (`/tmp/.buildx-cache-autossh`)
- 只构建 amd64 架构
- 标签为 `latest`
- 支持增量构建

**`build-test-web`** - 构建 web 面板镜像（已优化）

```bash
make build-test-web
```

- 使用本地缓存 (`/tmp/.buildx-cache-web`)
- 只构建 amd64 架构
- 标签为 `latest`
- 支持增量构建，Go 依赖缓存

**`clean-cache`** - 清理构建缓存

```bash
make clean-cache
```

- 删除所有构建缓存目录
- 用于解决缓存损坏或强制完全重新构建

### 3. .dockerignore 优化

排除不必要的文件，减少构建上下文大小：

- 文档文件 (_.md, README_, LICENSE)
- 开发工具配置 (.vscode, Makefile)
- 临时文件和缓存
- Git 相关文件

## 使用建议

### 首次构建

```bash
# 构建 autossh 镜像
make build-test-autossh

# 构建 web 面板镜像
make build-test-web
```

### 日常开发

**方式 1：使用 compose.dev.yaml（推荐）**

```bash
# 本地构建并运行
docker compose -f compose.dev.yaml up --build
```

**方式 2：使用 Makefile + compose.yaml**

```bash
# 先构建镜像
make build-test-web

# 然后运行
docker compose up
```

### 清理缓存

```bash
# 如果遇到缓存问题，清理后重新构建
make clean-cache
make build-test-web
```

## 性能对比

### 优化前

- 首次构建：~2-3 分钟
- 代码修改后重新构建：~2-3 分钟（每次都重新下载依赖）

### 优化后

- 首次构建：~2-3 分钟
- 代码修改后重新构建：~10-30 秒（复用依赖缓存）✨
- 仅修改静态文件：~5-10 秒

## 技术细节

### Docker BuildKit 缓存

使用 `--cache-from` 和 `--cache-to` 选项：

- `type=local,src=/tmp/.buildx-cache-web` - 从本地缓存读取
- `type=local,dest=/tmp/.buildx-cache-web,mode=max` - 保存所有层到缓存

### Go 模块缓存

Go 模块下载到 Docker 层中，只要 `go.mod` 和 `go.sum` 不变，就会复用缓存。

### 构建优化标志

- `CGO_ENABLED=0` - 禁用 CGO，生成静态二进制
- `-ldflags="-w -s"` - 去除调试信息，减小文件大小
  - `-w` - 去除 DWARF 调试信息
  - `-s` - 去除符号表

## 故障排除

### 缓存损坏

如果遇到奇怪的构建错误：

```bash
make clean-cache
docker system prune -f
make build-test-web
```

### 依赖更新

修改 `web/go.mod` 后：

```bash
# 缓存会自动失效，重新下载依赖
make build-test-web
```

### 完全重新构建

```bash
docker buildx build --no-cache -f Dockerfile.web -t oaklight/autossh-tunnel-web-panel:latest --load .
```
