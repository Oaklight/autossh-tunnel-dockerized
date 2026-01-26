# 国际化贡献指南 / Internationalization Contributing Guide

[English](#english) | [中文](#中文)

## English

### How to Add a New Language

Thank you for your interest in contributing translations to SSH Tunnel Manager! This guide will help you add support for a new language.

#### Step 1: Create Language Resource File

1. Navigate to the `web/static/locales/` directory
2. Create a new JSON file named with the language code (e.g., `fr.json` for French, `de.json` for German)
3. Copy the structure from `en.json` and translate all the values

#### Step 2: Language File Structure

The language file should follow this structure:

```json
{
  "app": {
    "title": "Your translation here",
    "name": "Your translation here",
    "help_title": "Your translation here"
  },
  "navigation": {
    "help": "Your translation here",
    "docker_hub": "Docker Hub",
    "github": "GitHub",
    "back": "Your translation here"
  }
  // ... continue with all sections
}
```

#### Step 3: Update Language Support

1. Open `web/static/i18n.js`
2. Find the `getSupportedLanguages()` method
3. Add your language to the array:

```javascript
getSupportedLanguages() {
    return [
        { code: 'en', name: 'English' },
        { code: 'zh', name: '中文' },
        { code: 'fr', name: 'Français' }, // Add your language here
        // ... other languages
    ];
}
```

4. Update the language validation in the `switchLanguage()` method:

```javascript
if (!["en", "zh", "fr"].includes(lang)) {
  // Add your language code here
  console.error(`Unsupported language: ${lang}`);
  return false;
}
```

#### Step 4: Test Your Translation

1. Start the application
2. Use the language toggle button to switch to your new language
3. Verify that all text is properly translated
4. Check both the main page and help page

#### Translation Guidelines

- **Consistency**: Use consistent terminology throughout the translation
- **Context**: Consider the context in which text appears (buttons, labels, messages)
- **Length**: Keep translations reasonably similar in length to avoid UI layout issues
- **Technical Terms**: Some technical terms like "SSH", "Docker", "YAML" should remain in English
- **Placeholders**: Preserve placeholder formats like `{{variable}}` in your translations

#### Common Translation Keys

- `app.*`: Application titles and names
- `navigation.*`: Navigation elements and links
- `table.*`: Table headers, placeholders, and content
- `buttons.*`: Button labels and tooltips
- `messages.*`: User feedback messages
- `validation.*`: Form validation error messages
- `help.*`: Help documentation content

#### Submitting Your Translation

1. Fork the repository
2. Create a new branch for your translation (e.g., `add-french-translation`)
3. Add your language file and update the necessary JavaScript files
4. Test your translation thoroughly
5. Submit a pull request with a clear description of your changes

---

## 中文

### 如何添加新语言

感谢您对为 SSH Tunnel Manager 贡献翻译的兴趣！本指南将帮助您添加新语言支持。

#### 步骤 1：创建语言资源文件

1. 导航到 `web/static/locales/` 目录
2. 创建一个以语言代码命名的新 JSON 文件（例如，法语用 `fr.json`，德语用 `de.json`）
3. 复制 `en.json` 的结构并翻译所有值

#### 步骤 2：语言文件结构

语言文件应遵循以下结构：

```json
{
  "app": {
    "title": "您的翻译",
    "name": "您的翻译",
    "help_title": "您的翻译"
  },
  "navigation": {
    "help": "您的翻译",
    "docker_hub": "Docker Hub",
    "github": "GitHub",
    "back": "您的翻译"
  }
  // ... 继续所有部分
}
```

#### 步骤 3：更新语言支持

1. 打开 `web/static/i18n.js`
2. 找到 `getSupportedLanguages()` 方法
3. 将您的语言添加到数组中：

```javascript
getSupportedLanguages() {
    return [
        { code: 'en', name: 'English' },
        { code: 'zh', name: '中文' },
        { code: 'fr', name: 'Français' }, // 在这里添加您的语言
        // ... 其他语言
    ];
}
```

4. 在 `switchLanguage()` 方法中更新语言验证：

```javascript
if (!["en", "zh", "fr"].includes(lang)) {
  // 在这里添加您的语言代码
  console.error(`Unsupported language: ${lang}`);
  return false;
}
```

#### 步骤 4：测试您的翻译

1. 启动应用程序
2. 使用语言切换按钮切换到您的新语言
3. 验证所有文本都已正确翻译
4. 检查主页面和帮助页面

#### 翻译指南

- **一致性**：在整个翻译中使用一致的术语
- **上下文**：考虑文本出现的上下文（按钮、标签、消息）
- **长度**：保持翻译长度合理相似，避免 UI 布局问题
- **技术术语**：一些技术术语如 "SSH"、"Docker"、"YAML" 应保持英文
- **占位符**：在翻译中保留占位符格式，如 `{{variable}}`

#### 常见翻译键

- `app.*`：应用程序标题和名称
- `navigation.*`：导航元素和链接
- `table.*`：表格标题、占位符和内容
- `buttons.*`：按钮标签和工具提示
- `messages.*`：用户反馈消息
- `validation.*`：表单验证错误消息
- `help.*`：帮助文档内容

#### 提交您的翻译

1. Fork 仓库
2. 为您的翻译创建新分支（例如，`add-french-translation`）
3. 添加您的语言文件并更新必要的 JavaScript 文件
4. 彻底测试您的翻译
5. 提交包含清晰更改描述的拉取请求

---

## Supported Languages / 支持的语言

Currently supported languages:

- English (en)
- 简体中文 (zh)

We welcome contributions for additional languages!

## Contact / 联系方式

If you have questions about contributing translations, please:

- Open an issue on GitHub
- Contact the maintainers

Thank you for helping make SSH Tunnel Manager accessible to more users worldwide!
