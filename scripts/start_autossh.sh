#!/bin/sh

# Refactored startup script that uses the unified start_single_tunnel.sh
# This script initializes the environment and starts all configured tunnels

# Source shared tunnel utilities
. /scripts/tunnel_utils.sh

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

# Use shared cleanup function to clear old processes
cleanup_all_autossh_processes

# Additional cleanup: kill any processes holding the ports we need (in parallel)
echo "Checking and cleaning up ports in parallel..."
cleanup_pids=""
parse_config "$CONFIG_FILE" | while IFS=$'\t' read -r remote_host remote_port local_port direction; do
	# Extract actual port number
	actual_port="$local_port"
	if echo "$local_port" | grep -q ":"; then
		actual_port=$(echo "$local_port" | cut -d: -f2)
	fi

	# Kill any process using this port in background
	(
		pids=$(lsof -ti :${actual_port} 2>/dev/null)
		if [ -n "$pids" ]; then
			echo "Cleaning up processes on port ${actual_port}..."
			echo "$pids" | xargs kill -9 2>/dev/null
		fi
	) &
	cleanup_pids="$cleanup_pids $!"
done

# Wait for all port cleanup operations to complete
for pid in $cleanup_pids; do
	wait $pid 2>/dev/null
done

# Final wait for ports to be released
sleep 1

echo "Cleanup complete. Starting tunnels in parallel..."

# Maximum number of parallel tunnel starts (configurable via env var)
MAX_PARALLEL=${MAX_PARALLEL:-10}
tunnel_count=0
pids=""

# Read the config.yaml file and start each tunnel using the unified script
while IFS=$'\t' read -r remote_host remote_port local_port direction; do
	# Create fresh log file with header
	log_id=$(create_fresh_log "$remote_host" "$remote_port" "$local_port" "$direction" "Started")
	echo "Initialized new log file for tunnel ${log_id}"

	# Start tunnel using unified script in background
	# No need for su since this script is already running as myuser
	/scripts/start_single_tunnel.sh "$remote_host" "$remote_port" "$local_port" "$direction" &
	pid=$!
	pids="$pids $pid"
	tunnel_count=$((tunnel_count + 1))

	# If we've reached max parallel, wait for current batch to complete
	if [ $((tunnel_count % MAX_PARALLEL)) -eq 0 ]; then
		echo "Waiting for batch of $MAX_PARALLEL tunnels to start..."
		for pid in $pids; do
			wait $pid 2>/dev/null
		done
		pids=""
		sleep 0.5
	fi
done <<EOF
$(parse_config "$CONFIG_FILE")
EOF

# Wait for any remaining tunnels to start
if [ -n "$pids" ]; then
	echo "Waiting for remaining tunnels to start..."
	for pid in $pids; do
		wait $pid 2>/dev/null
	done
fi

echo "All $tunnel_count tunnels started in parallel. Container will keep running..."

# Keep the script running indefinitely
# This prevents the container from exiting
while true; do
	sleep 3600
done
