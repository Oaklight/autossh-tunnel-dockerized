# SSH 隧道管理器文档（中文）

本目录包含 SSH 隧道管理器的中文文档，使用 MkDocs 构建。

## 本地构建

### 前置要求

- Python 3.8+
- pip

### 设置

1. 创建虚拟环境：
   ```bash
   python -m venv .venv
   source .venv/bin/activate  # Windows 系统: .venv\Scripts\activate
   ```

2. 安装依赖：
   ```bash
   pip install -r requirements.txt
   ```

3. 本地运行：
   ```bash
   mkdocs serve
   ```

4. 在浏览器中打开 http://127.0.0.1:8000

### 构建

构建静态站点：

```bash
mkdocs build
```

构建的站点将位于 `site/` 目录中。

## 文档结构

```
docs/
├── index.md                  # 首页
├── getting-started.md        # 快速入门指南
├── ssh-config.md             # SSH 配置指南
├── architecture.md           # 架构说明
├── web-panel.md              # Web 面板使用
├── troubleshooting.md        # 故障排除指南
├── api/
│   ├── index.md              # API 概述
│   ├── cli-reference.md      # CLI 命令参考
│   ├── http-api.md           # HTTP API 参考
│   └── tunnel-lifecycle.md   # 隧道生命周期管理
└── development/
    ├── contributing.md       # 贡献指南
    └── i18n.md               # 国际化指南
```

## ReadTheDocs

本文档托管在 ReadTheDocs 上。配置文件为 `.readthedocs.yaml`。

## 贡献

有关如何为文档做出贡献的详细信息，请参阅[贡献指南](docs/development/contributing.md)。

## 许可证

MIT License