# 第一阶段：构建阶段
FROM python:3.9-alpine AS builder

# 安装必要的构建工具和依赖
RUN apk add --no-cache gcc musl-dev libffi-dev make

# 设置工作目录
WORKDIR /app

# 复制依赖文件
COPY requirements.txt .

# 安装 Python 依赖
RUN pip install --no-cache-dir --prefer-binary -r requirements.txt && \
    apk del gcc musl-dev make

# 第二阶段：运行阶段
FROM python:3.9-alpine

# 设置工作目录
WORKDIR /app

# 仅复制运行所需的文件
COPY --from=builder /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
COPY . .

# 暴露端口
EXPOSE 5000

# 启动命令
CMD ["python", "app.py"]
