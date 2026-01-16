#!/bin/sh

# 监控配置文件变化并重启 autossh
CONFIG_FILE="/etc/autossh/config/config.yaml"

while true; do
	# Only monitor the config.yaml file, not the entire directory
	inotifywait -e modify,create "$CONFIG_FILE"
	echo "检测到配置文件变化，重启 autossh..."
	echo "Detected configuration file changes, restarting autossh..."

	# Add a small delay to avoid rapid restarts
	sleep 2

	# Kill all autossh processes
	pkill -f "autossh"

	# Wait for processes to terminate
	sleep 1

	# Restart autossh
	/scripts/start_autossh.sh &
done
