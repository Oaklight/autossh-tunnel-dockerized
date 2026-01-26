---
hide:
  - navigation
---

# 基于 Docker 和 Autossh 的 SSH 隧道管理器

![网页面板界面](assets/images/web-panel.png)

本项目提供了一个基于 Docker 的解决方案，使用 `autossh` 和 YAML 配置文件来管理 SSH 隧道。此设置允许您轻松地**将本地服务通过 SSH 隧道暴露到远程服务器**或**将远程服务映射到本地端口**，方便访问防火墙后的服务。

## 功能特性

- **Docker 化**：使用 Docker 封装环境，易于部署和管理。
- **非 root 用户**：以非 root 用户运行容器，增强安全性。
- **YAML 配置**：使用 `config.yaml` 文件定义多个 SSH 隧道映射，支持配置变更时自动重载服务。
- **Autossh**：自动维护 SSH 连接，确保隧道保持活跃。
- **动态 UID/GID 支持**：使用 `PUID` 和 `PGID` 环境变量动态设置容器用户的 UID 和 GID，以匹配主机用户权限。
- **多架构支持**：支持所有 Alpine 基础架构，包括 `linux/amd64`、`linux/arm64/v8`、`linux/arm/v7`、`linux/arm/v6`、`linux/386`、`linux/ppc64le`、`linux/s390x` 和 `linux/riscv64`。
- **灵活的方向配置**：支持将本地服务暴露到远程服务器（`local_to_remote`）或将远程服务映射到本地端口（`remote_to_local`）。
- **自动重载**：检测 `config.yaml` 的变化并自动重载服务配置。
- **Web 配置界面**：通过 Web 面板管理隧道和配置更新。
- **CLI 工具 (autossh-cli)**：用于管理隧道、查看状态和控制单个隧道的命令行界面。
- **HTTP API**：用于程序化隧道控制的 RESTful API，支持与其他工具和自动化集成。
- **单个隧道控制**：独立启动、停止和管理每个隧道，不影响其他隧道。

## 前置要求

- 本地机器上已安装 Docker 和 Docker Compose。
- 已设置用于访问远程主机的 SSH 密钥。

## 快速链接

- [快速入门](getting-started.md) - 快速安装和设置指南
- [SSH 配置](ssh-config.md) - 如何配置 SSH 隧道连接
- [Web 面板](web-panel.md) - 使用基于 Web 的管理界面
- [隧道控制 API](api/index.md) - CLI 和 HTTP API 文档

## 发布版本

打包的 Docker 镜像可在 Docker Hub 上获取：

[Docker Hub 链接](https://hub.docker.com/r/oaklight/autossh-tunnel)

欢迎使用并提供反馈！

## 许可证

本项目基于 MIT 许可证。

## 致谢

- [autossh](http://www.harding.motd.ca/autossh/) 用于维护 SSH 连接。
- [Docker](https://www.docker.com/) 用于容器化。
- [Alpine Linux](https://alpinelinux.org/) 提供轻量级基础镜像。
- [Go](https://golang.org/) 用于 Web 面板后端。
- [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) 提供文档主题。