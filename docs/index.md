---
hide:
  - navigation
---

# SSH 隧道管理器

基于 Docker 和 autossh 的 SSH 隧道管理解决方案，支持 Web 面板和 API 控制。

![网页面板界面](https://github.com/user-attachments/assets/bb26d0f5-14ee-4289-b809-e48381c05bc1)

## 功能特性

- **Docker 化**：使用 Docker 封装环境，易于部署和管理
- **非 root 用户**：以非 root 用户运行容器，增强安全性
- **YAML 配置**：使用 `config.yaml` 文件定义多个 SSH 隧道映射
- **自动重载**：检测配置文件变化并自动重载服务
- **Web 面板**：可视化界面管理隧道配置
- **CLI 工具**：命令行界面用于管理隧道
- **HTTP API**：RESTful API 用于程序化控制
- **单个隧道控制**：独立启动、停止和管理每个隧道
- **多架构支持**：支持 `linux/amd64`、`linux/arm64/v8`、`linux/arm/v7` 等多种架构

## 快速开始

### 前置要求

- Docker 和 Docker Compose
- SSH 密钥用于访问远程主机

### 安装

1. 下载 Docker Compose 文件：

```bash
mkdir autossh-tunnel && cd autossh-tunnel
curl -O https://oaklight.github.io/autossh-tunnel-dockerized/compose.yaml
mkdir config
touch config/config.yaml
```

2. 启动服务：

```bash
docker compose up -d
```

3. 访问 Web 面板：

打开浏览器访问 `http://localhost:5000`

## 文档导航

- **[快速入门](getting-started.md)** - 详细的安装和配置指南
- **[SSH 配置](ssh-config.md)** - SSH 配置文件设置说明
- **[架构说明](architecture.md)** - 系统架构和组件说明
- **[Web 面板](web-panel.md)** - Web 界面使用指南
- **[API 文档](api/index.md)** - CLI 和 HTTP API 参考
- **[故障排除](troubleshooting.md)** - 常见问题解决方案

## 项目链接

- **GitHub**: [Oaklight/autossh-tunnel-dockerized](https://github.com/Oaklight/autossh-tunnel-dockerized)
- **Docker Hub**: [oaklight/autossh-tunnel](https://hub.docker.com/r/oaklight/autossh-tunnel)
- **文档**: [ReadTheDocs](https://autossh-tunnel-zh.readthedocs.io/)

## 许可证

本项目基于 MIT 许可证。详见 [LICENSE](https://github.com/Oaklight/autossh-tunnel-dockerized/blob/master/LICENSE) 文件。