# 配置文件监控修复说明

## 问题描述

在之前的版本中，当用户在容器外手动编辑挂载的 `config.yaml` 文件时，配置监控可能无法检测到文件变化，导致隧道配置不会自动更新。

## 根本原因

问题的根源在于不同编辑器修改文件的方式不同：

1. **直接修改型编辑器**（如 vim, nano）

   - 直接修改文件内容
   - 触发 `modify` 事件
   - 通常能被正确检测

2. **替换型编辑器**（如 VSCode, 某些 IDE）

   - 先创建临时文件
   - 删除原文件
   - 重命名临时文件为原文件名
   - 触发 `delete` + `create` 或 `moved_to` 事件
   - 可能不触发 `modify` 事件

3. **Docker 卷挂载的影响**
   - inode 变化可能不会正确传播到容器内
   - 文件描述符可能在文件替换后失效

## 解决方案

### 修改内容

在 [`scripts/spinoff_monitor.sh`](../../scripts/spinoff_monitor.sh) 中：

1. **监控目录而非文件**

   - 监控 `/etc/autossh/config` 目录
   - 避免文件替换导致的监控失效

2. **扩展监控事件类型**

   ```bash
   inotifywait -e modify,create,move,delete,moved_to,moved_from,close_write,attrib
   ```

   - `modify`: 文件内容修改
   - `create`: 新文件创建
   - `move`, `moved_to`, `moved_from`: 文件移动/重命名
   - `delete`: 文件删除
   - `close_write`: 文件写入后关闭（捕获编辑器保存）
   - `attrib`: 文件属性变化

3. **过滤目标文件**
   ```bash
   | grep -q "config.yaml"
   ```
   - 只响应 `config.yaml` 的变化
   - 忽略目录中其他文件的变化

### 测试方法

使用提供的测试脚本验证监控功能：

```bash
./tests/test_config_monitor.sh
```

测试脚本会模拟三种不同的文件修改方式：

1. 直接追加内容（模拟 vim/nano）
2. 文件替换（模拟 VSCode）
3. 属性变化（touch 命令）

### 验证步骤

1. 启动容器：

   ```bash
   docker compose up -d
   ```

2. 查看监控日志：

   ```bash
   docker compose logs -f autossh | grep "配置文件变化"
   ```

3. 在宿主机上编辑配置文件：

   ```bash
   vim config/config.yaml  # 或使用你喜欢的编辑器
   ```

4. 保存后应该看到类似输出：
   ```
   检测到配置文件变化，分析差异...
   Detected configuration file changes, analyzing differences...
   ```

## 技术细节

### inotify 事件说明

| 事件          | 触发条件                       | 用途                   |
| ------------- | ------------------------------ | ---------------------- |
| `modify`      | 文件内容被修改                 | 捕获直接编辑           |
| `create`      | 新文件被创建                   | 捕获文件替换的创建阶段 |
| `delete`      | 文件被删除                     | 捕获文件替换的删除阶段 |
| `moved_to`    | 文件被移动到监控目录           | 捕获 mv 操作           |
| `moved_from`  | 文件从监控目录移出             | 捕获 mv 操作           |
| `close_write` | 以写模式打开的文件被关闭       | 捕获编辑器保存操作     |
| `attrib`      | 文件属性（权限、时间戳等）变化 | 捕获 touch 等操作      |

### 为什么监控目录而不是文件

当监控文件本身时，如果文件被删除并重新创建（如 VSCode 的保存行为），`inotifywait` 监控的文件描述符会失效，导致后续变化无法被检测。

监控目录可以：

- 持续监控目录中的所有事件
- 不受单个文件删除/创建的影响
- 通过 `grep` 过滤只处理目标文件的事件

## 日志管理

### 隧道移除时的日志处理

当从配置中移除隧道时，系统会自动：

1. **记录移除事件**：在日志文件中添加最后一条记录
2. **压缩归档**：将日志文件压缩为 `.gz` 格式
3. **添加时间戳**：归档文件名包含移除时间，格式为 `tunnel_<log_id>.log.removed_YYYYMMDD_HHMMSS.gz`
4. **清理原文件**：删除原始日志文件

示例归档文件名：

```
tunnel_a1b2c3d4.log.removed_20260116_193045.gz
```

这样可以：

- 保留历史记录以供审计
- 避免日志文件累积占用空间
- 清晰标识已移除的隧道

### 查看归档日志

```bash
# 列出所有归档日志
ls -lh ./logs/*.removed_*.gz

# 查看归档日志内容
zcat ./logs/tunnel_a1b2c3d4.log.removed_20260116_193045.gz

# 搜索归档日志
zgrep "error" ./logs/*.removed_*.gz
```

## 相关文件

- [`scripts/spinoff_monitor.sh`](../../scripts/spinoff_monitor.sh) - 配置监控脚本
- [`tests/test_config_monitor.sh`](../../tests/test_config_monitor.sh) - 测试脚本
- [`entrypoint.sh`](../../entrypoint.sh) - 容器入口脚本

## 历史版本对比

### v1.6.2（工作正常）

```bash
inotifywait -r -e modify,create,delete /etc/autossh/config
```

### 当前版本（修复后）

```bash
inotifywait -e modify,create,move,delete,moved_to,moved_from,close_write,attrib "$(dirname "$CONFIG_FILE")" 2>/dev/null | grep -q "config.yaml"
```

主要改进：

1. 添加了更多事件类型（`move`, `moved_to`, `moved_from`, `close_write`, `attrib`）
2. 添加了文件名过滤（`grep -q "config.yaml"`）
3. 抑制错误输出（`2>/dev/null`）
