# 测试脚本 / Test Scripts

这个目录包含用于测试项目功能的脚本。

## 可用测试

### test_compression.sh

测试日志压缩功能。

**功能**：

- 创建测试日志文件
- 模拟日志增长超过阈值
- 验证压缩功能是否正常工作
- 检查头部信息是否正确保留

**使用方法**：

```bash
# 在容器内运行
docker compose exec autossh sh
cd /
chmod +x tests/test_compression.sh
./tests/test_compression.sh

# 或者从主机运行
docker compose exec autossh /tests/test_compression.sh
```

**清理测试文件**：

```bash
# 删除测试生成的日志文件
rm /var/log/autossh/tunnel_test1234*
```

## 添加新测试

在此目录中添加新的测试脚本时，请：

1. 使用描述性的文件名（如 `test_<feature>.sh`）
2. 在脚本开头添加清晰的注释说明测试目的
3. 确保脚本可执行（`chmod +x`）
4. 在本 README 中添加测试说明

---

# Test Scripts

This directory contains scripts for testing project functionality.

## Available Tests

### test_compression.sh

Tests the log compression functionality.

**Features**:

- Creates test log files
- Simulates log growth exceeding threshold
- Verifies compression works correctly
- Checks header information is preserved

**Usage**:

```bash
# Run inside container
docker compose exec autossh sh
cd /
chmod +x tests/test_compression.sh
./tests/test_compression.sh

# Or run from host
docker compose exec autossh /tests/test_compression.sh
```

**Cleanup test files**:

```bash
# Remove test-generated log files
rm /var/log/autossh/tunnel_test1234*
```

## Adding New Tests

When adding new test scripts to this directory, please:

1. Use descriptive filenames (e.g., `test_<feature>.sh`)
2. Add clear comments at the beginning explaining the test purpose
3. Ensure the script is executable (`chmod +x`)
4. Add test documentation to this README
