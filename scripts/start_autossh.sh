#!/bin/sh

# Refactored startup script that uses the unified start_single_tunnel.sh
# This script initializes the environment and starts all configured tunnels

# Source shared log utilities
. /scripts/log_utils.sh

CONFIG_FILE="/etc/autossh/config/config.yaml"
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

# Clear old autossh processes if any
pkill -f "autossh"

# Read the config.yaml file and start each tunnel using the unified script
while IFS=$'\t' read -r remote_host remote_port local_port direction; do
	# Create fresh log file with header
	log_id=$(create_fresh_log "$remote_host" "$remote_port" "$local_port" "$direction" "Started")
	echo "Initialized new log file for tunnel ${log_id}"

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
