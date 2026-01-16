# 进程清理功能重构

## 重构日期

2026-01-16

## 重构目标

将分散在多个脚本中的进程清理逻辑统一到共享工具函数中，提高代码可维护性和一致性。

## 问题背景

在修复隧道端口占用问题时，发现进程清理逻辑分散在多个文件中：

- [`scripts/control_api.sh`](../../scripts/control_api.sh) - API 重启时的清理
- [`scripts/start_autossh.sh`](../../scripts/start_autossh.sh) - 容器启动时的清理

这导致：

1. 代码重复
2. 维护困难（需要在多处同步修改）
3. 逻辑不一致的风险

## 重构内容

### 1. 文件重命名

**原文件名**: `scripts/log_utils.sh`  
**新文件名**: `scripts/tunnel_utils.sh`

**原因**: 该文件现在不仅包含日志管理功能，还包含进程清理功能，需要更通用的名称。

### 2. 新增公共函数

在 [`scripts/tunnel_utils.sh`](../../scripts/tunnel_utils.sh) 中添加了两个新函数：

#### cleanup_tunnel_processes()

用于清理特定隧道的进程和端口。

**参数**:

- `log_id` - 隧道的日志 ID（可选）
- `local_port` - 本地端口（可选）
- `remote_host` - 远程主机（可选）

**功能**:

1. 通过 TUNNEL_ID 杀死 autossh 进程
2. 通过端口号杀死占用端口的进程（使用 lsof）
3. 杀死连接到远程主机的 SSH 进程
4. 等待并验证端口释放

**使用场景**: API 重启单个隧道时

#### cleanup_all_autossh_processes()

用于清理所有 autossh 相关进程。

**功能**:

1. 强制杀死所有 autossh 进程
2. 强制杀死所有 SSH 进程
3. 等待并验证进程终止

**使用场景**: 容器启动时的初始化清理

### 3. 更新调用方

#### scripts/control_api.sh

**修改前**:

```bash
# 大量重复的进程清理代码（约30行）
pkill -9 -f "TUNNEL_ID=${log_id}"
lsof -ti :${actual_local_port} | xargs kill -9
pkill -9 -f "ssh.*${remote_host}"
# ... 等待和验证逻辑
```

**修改后**:

```bash
# 使用共享函数（1行）
cleanup_tunnel_processes "$log_id" "$local_port" "$remote_host"
```

#### scripts/start_autossh.sh

**修改前**:

```bash
# 大量重复的进程清理代码（约40行）
pkill -9 -f "autossh"
pkill -9 -f "ssh -"
# ... 等待和验证逻辑
```

**修改后**:

```bash
# 使用共享函数（1行）
cleanup_all_autossh_processes
```

### 4. 更新所有引用

更新了以下文件中对 `log_utils.sh` 的引用：

- [`scripts/control_api.sh`](../../scripts/control_api.sh)
- [`scripts/start_autossh.sh`](../../scripts/start_autossh.sh)
- [`scripts/start_single_tunnel.sh`](../../scripts/start_single_tunnel.sh)
- [`scripts/spinoff_monitor.sh`](../../scripts/spinoff_monitor.sh)

## 重构效果

### 代码行数减少

- `control_api.sh`: 减少约 30 行
- `start_autossh.sh`: 减少约 40 行
- 总计减少约 70 行重复代码

### 可维护性提升

- ✅ 单一职责：进程清理逻辑集中在一处
- ✅ 易于修改：只需修改 `tunnel_utils.sh` 即可
- ✅ 一致性：所有脚本使用相同的清理逻辑
- ✅ 可测试：独立函数更容易测试

### 功能增强

- ✅ 更可靠的进程清理
- ✅ 更完善的端口释放验证
- ✅ 统一的错误处理

## 向后兼容性

此重构保持了完全的向后兼容性：

- 所有现有功能保持不变
- API 接口没有变化
- 配置文件格式没有变化

## 测试建议

重构后应测试以下场景：

1. **API 重启隧道**

   ```bash
   curl -X POST http://localhost:5002/restart/{log_id}
   ```

2. **容器重启**

   ```bash
   docker-compose restart
   ```

3. **多个隧道同时运行**

   - 验证端口不冲突
   - 验证进程正确清理

4. **异常情况**
   - 端口被其他进程占用
   - 网络连接中断
   - 快速连续重启

## 相关文档

- [端口占用问题说明](restart_issue.md)
- [脚本说明](../../scripts/README.md)

## 未来改进方向

1. **添加单元测试**

   - 为 `cleanup_tunnel_processes()` 添加测试
   - 为 `cleanup_all_autossh_processes()` 添加测试

2. **增强错误处理**

   - 添加清理失败时的重试机制
   - 记录清理过程的详细日志

3. **性能优化**

   - 并行清理多个端口
   - 减少不必要的等待时间

4. **监控和告警**
   - 记录清理耗时
   - 清理失败时发送告警
