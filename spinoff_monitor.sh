#!/bin/sh

# 监控配置文件变化并重启 autossh
while true; do
    inotifywait -r -e modify,create,delete /etc/autossh/config
    echo "检测到配置文件变化，重启 autossh..."
    echo "Detected configuration file changes, restarting autossh..."
    pkill -f "autossh"
    /start_autossh.sh &
done
