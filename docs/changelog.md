# 更新日志

本项目的所有重要变更都将记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [v2.3.1] - 2026-03-27

### 修复

- **API 反向代理**：Web 面板现通过 `/api/autossh/` 代理所有 API 请求到后端，修复远程访问时浏览器无法连接 Docker 宿主机 `localhost:8080` 的问题
- **Web 面板网络**：Web 容器改用 `network_mode: "host"`，使其能够访问宿主机网络上的 autossh API
- **隧道状态轮询**：修复状态图标始终显示沙漏（加载中）的问题，通过区分 API 错误和有效的空响应来正确处理 `fetchTunnelStatuses()`
- **Home 目录权限**：PUID/PGID 变更后添加 `/home/myuser` 的 `chown`，修复 interactive auth 创建 `~/.autossh-sockets` 时的 `Permission denied` 错误
- **配置目录权限**：添加 `/etc/autossh/config` 的 `chown`，修复 Docker 自动创建 bind mount 目录时属主为 root 的问题
- **WebSocket 会话清理**：修复浏览器异常断开后哈希锁永远无法释放的问题，通过终止进程组（SIGTERM/SIGKILL）替代仅关闭 PTY
- **Interactive Auth 竞态条件**：修复 Go `select` 竞态问题，优先处理会话完成信号，避免客户端断开时误杀已成功 fork 的 SSH 进程
- **Fork SSH 进程 SIGHUP**：成功 `ssh -f` 认证后保持 PTY master 打开，防止内核 SIGHUP 在 SSH 子进程完成 `setsid()` 前将其杀死
- **QEMU 构建兼容性**：Dockerfile 中 Go 构建添加 `GOMAXPROCS=1`，防止跨平台 QEMU 模拟（s390x、riscv64 等）时出现死锁

### 新增

- **CI/CD Docker 发布**：新增 GitHub Actions 工作流，在发布 Release 时自动构建并推送多架构 Docker 镜像
- **手动触发工作流**：Docker 发布工作流支持手动触发并指定版本号
- **Docker 文档**：新增"Docker 深入解析"文档页，涵盖 Dockerfile 详解、构建优化、多架构构建和 CI/CD 流水线

### 移除

- **`API_BASE_URL` 前端暴露**：`API_BASE_URL` 环境变量现仅用于服务端代理，不再发送到浏览器

## [v2.3.0] - 2026-03-20

### 新增

- **WebSocket 服务器 (ws-server)**：新增 WebSocket 服务器，运行在 autossh 容器内，用于浏览器内交互式认证
    - 通过 `WS_PORT` 环境变量配置监听端口（默认：8022）
    - 支持与 xterm.js 终端进行 WebSocket 通信
- **浏览器内 xterm.js 终端弹窗**：交互式隧道现在可以直接在浏览器中完成密码和 2FA/TOTP 认证
    - 交互式隧道的启动/重启按钮显示终端图标徽标
    - 点击启动/重启按钮弹出 xterm.js 终端弹窗
    - 认证成功后弹窗自动关闭，隧道状态自动刷新
- **隧道详情页增强**：详情页新增交互式认证徽标和终端控制按钮
- **深色/浅色主题支持**：Web 面板新增配色方案选择器，支持深色和浅色两种主题
- **PORT 环境变量**：Web 面板支持通过 `PORT` 环境变量自定义监听端口（默认：5000）
- **WS_BASE_URL 环境变量**：Web 面板通过 `WS_BASE_URL` 环境变量配置 WebSocket 服务器地址

### 变更

- **交互式隧道 UI**：交互式隧道不再强制要求使用 CLI 认证，支持通过浏览器终端弹窗完成认证
- **Web 面板架构**：新增 WebSocket 代理支持，浏览器可直接连接 ws-server

## [v2.2.0] - 2026-02-04

### 新增

- **交互式认证（CLI）**：新增 `autossh-cli auth` 命令，支持需要 2FA 或密码认证的隧道
    - 使用 SSH control socket 管理连接
    - 支持哈希前缀匹配（8+ 字符）
    - 自动 PID 跟踪和状态管理
- **交互式认证测试服务器**：用于测试 2FA 认证的 Docker 化 SSH 服务器（`ssh-interactive-auth-sample-server/`）
    - 预配置 Google Authenticator
    - 包含 Makefile 便于快速启动
- **API 并发连接**：添加 socat 支持以处理并发 API 请求
- **Web 面板增强**：
    - 浮动 toast 通知，支持复制到剪贴板
    - 隧道详情页添加复制哈希按钮
    - 帮助页面添加交互式认证 CLI 文档
    - 改进配置网格布局和元素一致性

### 变更

- **交互式隧道 UI**：增强交互式认证隧道的 UI，使用指纹图标切换
- **i18n 改进**：语言按钮提示使用静态翻译键

## [v2.1.0] - 2026-02-03

### 新增

- **配置管理 API**：新增 RESTful API 用于配置管理（`/config` 端点）
    - `GET /config` - 获取所有隧道配置
    - `GET /config/<hash>` - 获取单个隧道配置
    - `POST /config` - 替换所有配置
    - `POST /config/new` - 添加新隧道
    - `POST /config/<hash>` - 更新单个隧道
    - `DELETE /config/<hash>` - 删除隧道
    - `POST /config/<hash>/delete` - 删除隧道（POST 替代方式）
- **隧道详情页配置编辑**：直接在详情页编辑隧道配置
- **单行保存按钮**：保存单个隧道配置而不影响其他隧道
- **本地化外部资源**：Material Design CSS/JS 和字体现在本地提供
- **增强状态可视化**：改进详情页的隧道状态显示
- **哈希前缀匹配**：支持使用 8+ 字符的哈希前缀识别隧道
- **刷新间隔标签**：在国际化中添加刷新间隔到自动刷新标签

### 变更

- **API 模块化**：将 `api_server.sh` 重构为独立模块，提高可维护性
- **配置 API 集成**：Web 面板现在使用配置 API 而非直接文件访问
- **优化行更新**：仅更新已保存的行而非刷新整个页面
- **autossh 容器配置挂载**：从只读（`ro`）改为读写（`rw`）以支持配置 API 写入
- **Web 面板简化**：移除配置卷挂载和 PUID/PGID 环境变量 - 所有配置操作现在通过配置 API 完成

### 修复

- **加载指示器**：在主页状态列显示沙漏加载指示器
- **i18n 就绪检查**：在调用 `t()` 前检查 `i18n.isReady`，防止显示原始键名
- **控制按钮**：在替换前重新启用控制按钮
- **保存延迟**：增加保存后的延迟以等待文件监控重启
- **快速重试**：在初始加载时添加状态获取的快速重试
- **配置保存体验**：改进配置保存用户体验并添加请求日志
- **配置 API 路径**：使用 `/etc/autossh/config/` 作为默认路径
- **JSON 输出**：修复配置 API 中的 JSON 输出和日志问题
- **隧道状态**：修复详情页中内部隧道状态的更新
- **状态识别**：改进隧道状态识别和处理
- **哈希映射**：使用哈希而非名称进行隧道状态映射

## [v2.0.0] - 2026-01-30

### 新增

- **Web 面板**：功能完整的基于 Web 的管理界面
- **HTTP API**：用于程序化隧道控制的 RESTful API
- **CLI 工具 (autossh-cli)**：用于隧道管理的命令行界面
- **单个隧道控制**：独立启动、停止和管理每个隧道
- **Bearer Token 认证**：可选的 API 认证支持
- **隧道方向模式**：支持默认（服务导向）和 SSH 标准两种模式
- **国际化**：Web 面板多语言支持
- **自动备份**：修改前自动备份配置

### 变更

- **架构**：将 Web 面板分离到独立容器，采用 API 驱动设计
- **配置**：增强 YAML 配置，提供更多选项
- **文档**：将文档迁移到专用 worktree（docs_en、docs_zh）

### 修复

- 各种 bug 修复和稳定性改进

## [v1.6.2] - 2025-07-23

### 新增

- **Material UI**：集成 Material Design 样式和组件，提供现代化 UI
- **数据表格**：Material 数据表格，支持输入验证和动画反馈
- **SSH 配置指南**：全面的 SSH 配置使用文档

### 变更

- **UI 样式**：表格单元格和输入框文本居中对齐

## [v1.6.1] - 2025-06-22

### 变更

- **Docker 基础镜像**：更新 Alpine 基础镜像版本
- **Dockerfile.web**：更新 Web 面板基础镜像

### 修复

- README 文档更新（英文和中文）

## [v1.6.0-fix] - 2025-03-04

### 修复

- **SSH 隧道配置**：调整 start_autossh.sh 中的 SSH 隧道配置
- **日志**：改进日志输出
- **备份权限**：修复备份文件夹权限问题
- **拼写错误**：修复小的拼写错误

## [v1.6.0] - 2025-02-12

### 新增

- **Web 面板**：初始 Web 配置界面（从 webpanel-golang 迁移）

### 变更

- **版本号**：更新以匹配版本号传统
- **权限**：使用 PGID 和 PUID 修复权限问题

### 修复

- README 重定向问题

## [v1.5.0] - 2025-02-12

### 新增

- **配置文件监控**：后台监控配置文件变化
- **自动重载**：配置变更时自动重载服务

## [v1.4.0] - 2025-02-03

### 新增

- **正向隧道**：支持将隧道转发到远程主机（local_to_remote 方向）

## [v1.3.0] - 2025-01-13

### 变更

- **远程端口解析**：增强 start_autossh.sh 以解析复杂的 remote_port 配置（ip:port 格式）
- **Makefile**：添加 build-test 目标用于本地测试

## [v1.2.0] - 2025-01-09

### 新增

- **多架构支持**：构建和推送多架构 Docker 镜像（amd64、arm64、arm/v7、arm/v6、386、ppc64le、s390x、riscv64）
- **Makefile**：添加用于多架构 Docker 镜像构建和推送的 Makefile
- **PUID/PGID 环境变量**：动态用户/组 ID 匹配宿主机

### 变更

- **入口点**：改进 entrypoint.sh 以匹配用户和组 ID
- **非 root 用户**：容器以非 root 用户（myuser）运行

### 移除

- 自定义 Dockerfile 和 compose 文件（合并到主文件中）

## [v1.1.1] - 2024-12-29

### 变更

- **环境变量**：在文档和配置中重命名为 HOST_UID/GID

### 修复

- **用户创建**：仅当提供的 uid/gid 与 1000 不同时才创建新的 myuser

## [v1.1.0] - 2024-12-28

### 新增

- **自定义 Dockerfile**：添加用于 UID/GID 匹配的自定义 Dockerfile 和 compose 文件
- **自动重启**：容器失败时自动重启
- **许可证**：添加 MIT 许可证

## [v1.0.0] - 2024-11-14

### 新增

- **初始版本**：基于 Docker 和 autossh 的 SSH 隧道管理器
- **YAML 配置**：使用 config.yaml 定义多个 SSH 隧道映射
- **自动 SSH 维护**：autossh 保持隧道活跃
- **Docker Compose**：使用 docker-compose 轻松部署