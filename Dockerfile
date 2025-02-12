# 第一阶段：构建阶段
FROM alpine:3.21 AS builder

# 设置工作目录
WORKDIR /app

# 复制依赖文件
COPY requirements.txt .

# 安装必要的构建工具和依赖
RUN apk add --no-cache --virtual .build-deps \
        gcc \
        musl-dev \
        libffi-dev \
        make \
        python3-dev \
        py3-pip \
        && python3 -m venv /venv \
        && /venv/bin/pip install --no-cache-dir --prefer-binary -r requirements.txt \
        && find /venv/lib/python3.*/site-packages -name "*.pyc" -delete \
        && find /venv/lib/python3.*/site-packages -name "__pycache__" -delete \
        && apk del .build-deps

# 复制应用代码
COPY . .

# 第二阶段：运行阶段
FROM alpine:3.21

# 安装运行时依赖
RUN apk add --no-cache \
        libffi \
        python3

# 设置工作目录
WORKDIR /app

# 复制虚拟环境和应用代码
COPY --from=builder /venv /venv
COPY --from=builder /app /app

# 设置虚拟环境路径
ENV PATH="/venv/bin:$PATH"

# 暴露端口
EXPOSE 5000

# 启动命令
CMD ["python3", "app.py"]
