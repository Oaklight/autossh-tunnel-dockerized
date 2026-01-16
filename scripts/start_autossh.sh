#!/bin/sh

# Refactored startup script that uses the unified start_single_tunnel.sh
# This script initializes the environment and starts all configured tunnels

CONFIG_FILE="/etc/autossh/config/config.yaml"
LOG_DIR="/var/log/autossh"
LOG_SIZE=${LOG_SIZE:-102400}

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Clear old log files only on initial container startup (not on config reload)
# Check if this is initial startup by looking for a marker file
STARTUP_MARKER="/tmp/.autossh_initial_startup"
if [ ! -f "$STARTUP_MARKER" ]; then
	echo "Initial startup detected, clearing old log files..."
	rm -f "$LOG_DIR"/tunnel_*.log "$LOG_DIR"/tunnel_*.log.gz
	touch "$STARTUP_MARKER"
else
	echo "Config reload detected, preserving existing log files..."
fi

# Function to parse YAML and extract tunnel configurations
parse_config() {
	local config_file=$1
	yq e '.tunnels[] | [.remote_host, .remote_port, .local_port, .direction] | @tsv' "$config_file"
}

# Function to generate a unique log ID based on tunnel configuration
generate_log_id() {
	local remote_host=$1
	local remote_port=$2
	local local_port=$3
	local direction=$4
	local config_string="${remote_host}:${remote_port}:${local_port}:${direction}"
	echo -n "$config_string" | md5sum | cut -c1-8
}

# Function to initialize log file with header
init_log_file() {
	local remote_host=$1
	local remote_port=$2
	local local_port=$3
	local direction=$4

	local log_id=$(generate_log_id "$remote_host" "$remote_port" "$local_port" "$direction")
	local log_file="${LOG_DIR}/tunnel_${log_id}.log"

	# Check if log file already exists (config reload scenario)
	if [ -f "$log_file" ]; then
		# Append restart marker instead of overwriting
		{
			echo ""
			echo "========================================="
			echo "Tunnel Restarted at: $(date '+%Y-%m-%d %H:%M:%S')"
			echo "Configuration:"
			echo "  Remote Host: ${remote_host}"
			echo "  Remote Port: ${remote_port}"
			echo "  Local Port: ${local_port}"
			echo "  Direction: ${direction}"
			echo "========================================="
		} >>"$log_file"
		echo "Appended restart marker to existing log file for tunnel ${log_id}"
	else
		# Create a new log file with header (initial startup)
		{
			echo "========================================="
			echo "Tunnel Log ID: ${log_id}"
			echo "Started at: $(date '+%Y-%m-%d %H:%M:%S')"
			echo "Configuration:"
			echo "  Remote Host: ${remote_host}"
			echo "  Remote Port: ${remote_port}"
			echo "  Local Port: ${local_port}"
			echo "  Direction: ${direction}"
			echo "========================================="
		} >"$log_file"
		echo "Initialized new log file for tunnel ${log_id}"
	fi
}

# Clear old autossh processes if any
pkill -f "autossh"

# Read the config.yaml file and start each tunnel using the unified script
while IFS=$'\t' read -r remote_host remote_port local_port direction; do
	# Initialize log file with header
	init_log_file "$remote_host" "$remote_port" "$local_port" "$direction"

	# Start tunnel using unified script
	# No need for su since this script is already running as myuser
	/scripts/start_single_tunnel.sh "$remote_host" "$remote_port" "$local_port" "$direction" &

	# Small delay to prevent overwhelming the system
	sleep 0.5
done <<EOF
$(parse_config "$CONFIG_FILE")
EOF

echo "All tunnels started. Container will keep running..."

# Keep the script running indefinitely
# This prevents the container from exiting
while true; do
	sleep 3600
done
