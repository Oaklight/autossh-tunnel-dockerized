#!/bin/sh

# 监控配置文件变化并重启 autossh
CONFIG_FILE="/etc/autossh/config/config.yaml"

while true; do
	# Monitor the config directory for any changes to config.yaml
	# This handles the case where the file is moved/renamed during save
	inotifywait -e modify,create,move,delete,moved_to,moved_from "$(dirname "$CONFIG_FILE")" | grep -q "config.yaml"
	echo "检测到配置文件变化，重启 autossh..."
	echo "Detected configuration file changes, restarting autossh..."

	# Consume any additional events within a short time window to avoid multiple restarts
	# This prevents rapid-fire restarts when a single save triggers multiple inotify events
	sleep 3

	# Drain any pending inotify events
	while inotifywait -t 1 -e modify,create,move,delete,moved_to,moved_from "$(dirname "$CONFIG_FILE")" 2>/dev/null | grep -q "config.yaml"; do
		echo "Consuming additional config change event..."
		sleep 1
	done

	# Kill all autossh processes
	pkill -f "autossh"

	# Wait for processes to terminate
	sleep 2

	# Restart autossh
	/scripts/start_autossh.sh &

	# Add a cooldown period to prevent immediate re-triggers
	sleep 5
done
