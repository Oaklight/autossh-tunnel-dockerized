import os
import shutil
from datetime import datetime

import yaml
from flask import Flask, jsonify, render_template, request

app = Flask(__name__)
CONFIG_DIR = "config"  # 配置文件目录
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.yaml")


# 加载 YAML 文件
def load_config():
    if not os.path.exists(CONFIG_FILE):
        return {"tunnels": []}
    with open(CONFIG_FILE, "r") as f:
        config = yaml.safe_load(f) or {"tunnels": []}
    # 确保每个隧道条目都有 direction，默认为 remote_to_local
    for tunnel in config.get("tunnels", []):
        tunnel.setdefault("direction", "remote_to_local")
    return config


# 保存 YAML 文件并备份
def save_config(data):
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    backup_file = os.path.join(
        CONFIG_DIR, f"config_{timestamp}.yaml"
    )  # 使用配置文件目录
    if os.path.exists(CONFIG_FILE):
        shutil.copy(CONFIG_FILE, backup_file)

    # 自定义排序逻辑
    def sort_keys(tunnel):
        order = ["name", "remote_host", "remote_port", "local_port", "direction"]
        return {key: tunnel[key] for key in order if key in tunnel}

    # 对每个隧道条目重新排序
    sorted_data = {"tunnels": [sort_keys(tunnel) for tunnel in data.get("tunnels", [])]}

    with open(CONFIG_FILE, "w") as f:
        yaml.safe_dump(sorted_data, f, default_flow_style=False, sort_keys=False)


@app.route("/", methods=["GET"])
def index():
    # 渲染 templates/index.html
    return render_template("index.html")


@app.route("/api/config", methods=["GET"])
def get_config():
    config = load_config()
    return jsonify(config)


@app.route("/api/config", methods=["POST"])
def update_config():
    data = request.json
    print("Received data:", data)  # 打印接收到的数据
    if not data or "tunnels" not in data:
        return jsonify({"status": "error", "message": "Invalid data"}), 400
    save_config(data)
    return jsonify({"status": "success"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
