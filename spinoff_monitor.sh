#!/bin/sh

# 监控配置文件变化并重启 autossh
# Monitor configuration file changes and restart autossh

CONFIG_FILE="${AUTOSSH_CONFIG_FILE:-/etc/autossh/config/config.yaml}"
CONFIG_DIR=$(dirname "$CONFIG_FILE")

VERSION=$(cat /etc/autossh-version 2>/dev/null || echo "dev")

print_banner() {
	_label="AutoSSH Tunnel Manager  $VERSION"
	_len=${#_label}
	_pad=$((_len + 6))
	_border=""
	_i=0
	while [ "$_i" -lt "$_pad" ]; do
		_border="${_border}═"
		_i=$((_i + 1))
	done
	printf '  ╔%s╗\n' "$_border"
	printf '  ║   %s   ║\n' "$_label"
	printf '  ╚%s╝\n' "$_border"
}

# Function to handle shutdown
cleanup() {
	echo "Stopping autossh tunnels..."
	autossh-cli stop
	if [ -n "$WS_PID" ]; then
		echo "Stopping WebSocket server..."
		kill "$WS_PID" 2>/dev/null
	fi
	if [ -n "$API_PID" ]; then
		echo "Stopping API server..."
		kill "$API_PID" 2>/dev/null
	fi
	exit 0
}

# Trap signals
trap cleanup TERM INT

# Ensure state file and log directory have proper permissions
# Note: entrypoint.sh already created these with correct ownership
# We just ensure they still exist and are accessible
if [ ! -f /tmp/autossh_tunnels.state ]; then
	echo "Creating state file..."
	touch /tmp/autossh_tunnels.state
	chmod 666 /tmp/autossh_tunnels.state
fi

if [ ! -d /tmp/autossh-logs ]; then
	echo "Creating log directory..."
	mkdir -p /tmp/autossh-logs
	chmod 777 /tmp/autossh-logs
fi

print_banner

# Start API server if enabled
if [ "${API_ENABLE:-false}" = "true" ]; then
	echo "Starting API server..."
	/usr/local/bin/scripts/api_server.sh &
	API_PID=$!
fi

# Start WebSocket server for interactive auth if API is enabled
if [ "${API_ENABLE:-false}" = "true" ]; then
	echo "Starting WebSocket server for interactive auth..."
	/usr/local/bin/ws-server &
	WS_PID=$!
fi

# Initial start
echo "Starting autossh tunnels..."
autossh-cli start

# Monitor loop
echo "Monitoring configuration file: $CONFIG_FILE"
while true; do
	# Wait for changes
	# We monitor the directory to catch file replacements (e.g. atomic saves by editors)
	if inotifywait -r -e modify,create,delete,move "$CONFIG_DIR" 2>/dev/null; then
		echo "Detected configuration file changes, applying updates..."
		# Give a small buffer for file write completion
		sleep 2
		autossh-cli start
	else
		# If inotifywait fails (e.g. directory doesn't exist yet), sleep and retry
		echo "Monitor failed or directory missing, retrying in 5s..."
		sleep 5
	fi
done
