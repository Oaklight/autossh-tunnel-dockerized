# 贡献指南

感谢您对 SSH 隧道管理器项目的关注！我们欢迎各种形式的贡献。

## 如何贡献

### 报告问题

如果您发现了 bug 或有功能建议：

1. 在 [GitHub Issues](https://github.com/Oaklight/autossh-tunnel-dockerized/issues) 中搜索是否已有相关问题
2. 如果没有，创建新的 issue
3. 提供详细的描述：
   - Bug 报告：重现步骤、预期行为、实际行为、环境信息
   - 功能建议：用例、预期效果、可能的实现方式

### 提交代码

1. **Fork 仓库**

   点击 GitHub 页面右上角的 "Fork" 按钮

2. **克隆您的 Fork**

   ```bash
   git clone https://github.com/YOUR_USERNAME/autossh-tunnel-dockerized.git
   cd autossh-tunnel-dockerized
   ```

3. **创建功能分支**

   ```bash
   git checkout -b feature/your-feature-name
   ```

4. **进行更改**

   - 遵循现有的代码风格
   - 添加必要的测试
   - 更新相关文档

5. **提交更改**

   ```bash
   git add .
   git commit -m "描述您的更改"
   ```

   提交信息应该：
   - 使用现在时态（"Add feature" 而不是 "Added feature"）
   - 第一行简短描述（50 字符以内）
   - 如需要，添加详细描述

6. **推送到您的 Fork**

   ```bash
   git push origin feature/your-feature-name
   ```

7. **创建 Pull Request**

   - 访问原始仓库
   - 点击 "New Pull Request"
   - 选择您的分支
   - 填写 PR 描述

## 开发指南

### 环境设置

#### 前置要求

- Docker 和 Docker Compose
- Git
- 文本编辑器或 IDE

#### 本地开发

1. 克隆仓库：
   ```bash
   git clone https://github.com/Oaklight/autossh-tunnel-dockerized.git
   cd autossh-tunnel-dockerized
   ```

2. 构建开发镜像：
   ```bash
   docker compose -f compose.dev.yaml build
   ```

3. 启动服务：
   ```bash
   docker compose -f compose.dev.yaml up
   ```

### 项目结构

```
autossh-tunnel-dockerized/
├── config/                 # 配置文件
│   └── config.yaml.sample # 示例配置
├── scripts/               # Shell 脚本
│   ├── api_server.sh     # API 服务器
│   ├── config_parser.sh  # 配置解析器
│   ├── logger.sh         # 日志工具
│   ├── start_autossh.sh  # 启动脚本
│   └── state_manager.sh  # 状态管理
├── web/                   # Web 面板
│   ├── main.go           # Go 后端
│   ├── static/           # 静态资源
│   └── templates/        # HTML 模板
├── doc/                   # 文档
├── Dockerfile            # autossh 容器
├── Dockerfile.web        # web 面板容器
├── entrypoint.sh         # 容器入口点
└── autossh-cli          # CLI 工具
```

### 代码风格

#### Shell 脚本

- 使用 4 空格缩进
- 函数名使用 snake_case
- 添加注释说明复杂逻辑
- 使用 `shellcheck` 检查脚本

#### Go 代码

- 遵循 Go 官方代码风格
- 使用 `gofmt` 格式化代码
- 添加必要的注释和文档

#### JavaScript

- 使用 2 空格缩进
- 使用现代 ES6+ 语法
- 添加 JSDoc 注释

### 测试

在提交 PR 前，请确保：

1. **功能测试**：
   ```bash
   # 启动服务
   docker compose -f compose.dev.yaml up -d
   
   # 测试基本功能
   docker exec -it autotunnel-autossh-1 autossh-cli list
   docker exec -it autotunnel-autossh-1 autossh-cli status
   ```

2. **Web 面板测试**：
   - 访问 `http://localhost:5000`
   - 测试所有功能
   - 检查不同语言

3. **API 测试**：
   ```bash
   curl http://localhost:8080/list
   curl http://localhost:8080/status
   ```

### 文档

更新文档时：

1. **README 文件**：
   - 同时更新 `README.md`、`README_en.md` 和 `README_zh.md`
   - 保持三个版本内容一致

2. **API 文档**：
   - 更新 `doc/tunnel-control-api_en.md` 和 `doc/tunnel-control-api_zh.md`
   - 包含示例和响应格式

3. **在线文档**：
   - 更新 `docs_en/` 和 `docs_zh/` 目录中的相应文件
   - 使用 MkDocs 预览：
     ```bash
     cd docs_en  # 或 docs_zh
     mkdocs serve
     ```

## 贡献类型

### Bug 修复

1. 在 issue 中描述 bug
2. 创建修复分支
3. 添加测试用例（如适用）
4. 提交 PR 并引用 issue

### 新功能

1. 先创建 issue 讨论功能
2. 等待维护者反馈
3. 实现功能
4. 更新文档
5. 提交 PR

### 文档改进

1. 修正错别字、语法错误
2. 改进说明和示例
3. 添加缺失的文档
4. 翻译文档

### 国际化

参见 [国际化指南](i18n.md) 了解如何添加新语言支持。

## Pull Request 指南

### PR 标题

使用清晰的标题描述更改：

- `feat: 添加新功能`
- `fix: 修复 bug`
- `docs: 更新文档`
- `style: 代码格式化`
- `refactor: 重构代码`
- `test: 添加测试`
- `chore: 构建/工具更改`

### PR 描述

包含以下信息：

1. **更改内容**：简要描述做了什么
2. **原因**：为什么需要这个更改
3. **测试**：如何测试这些更改
4. **截图**：如果是 UI 更改，提供截图
5. **相关 Issue**：引用相关的 issue

### 代码审查

- 响应审查意见
- 进行必要的修改
- 保持讨论专业和建设性

## 行为准则

### 我们的承诺

为了营造开放和友好的环境，我们承诺：

- 使用友好和包容的语言
- 尊重不同的观点和经验
- 优雅地接受建设性批评
- 关注对社区最有利的事情
- 对其他社区成员表示同理心

### 不可接受的行为

- 使用性化的语言或图像
- 人身攻击或侮辱性评论
- 公开或私下骚扰
- 未经许可发布他人的私人信息
- 其他不道德或不专业的行为

## 许可证

通过贡献，您同意您的贡献将在 MIT 许可证下授权。

## 问题？

如有任何问题，请：

- 查看现有文档
- 搜索已关闭的 issues
- 创建新的 issue 提问

感谢您的贡献！