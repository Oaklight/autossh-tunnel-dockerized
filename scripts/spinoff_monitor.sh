#!/bin/sh

# 监控配置文件变化并智能增量重启 autossh

# Source shared tunnel utilities
. /scripts/tunnel_utils.sh

CONFIG_FILE="/etc/autossh/config/config.yaml"
STATE_FILE="/tmp/.tunnel_state"

# Function to get current tunnel IDs from config
get_current_tunnel_ids() {
	yq e '.tunnels[] | [.remote_host, .remote_port, .local_port, .direction] | @tsv' "$CONFIG_FILE" |
		while IFS=$'\t' read -r remote_host remote_port local_port direction; do
			generate_log_id "$remote_host" "$remote_port" "$local_port" "$direction"
		done | sort
}

# Function to start a new tunnel
start_new_tunnel() {
	local log_id=$1

	# Find tunnel configuration from current config
	yq e '.tunnels[] | [.remote_host, .remote_port, .local_port, .direction] | @tsv' "$CONFIG_FILE" |
		while IFS=$'\t' read -r remote_host remote_port local_port direction; do
			local current_id=$(generate_log_id "$remote_host" "$remote_port" "$local_port" "$direction")
			if [ "$current_id" = "$log_id" ]; then
				echo "Starting new tunnel ${log_id}: ${remote_host}:${remote_port} <-> ${local_port}"

				# Create fresh log file with header
				create_fresh_log "$remote_host" "$remote_port" "$local_port" "$direction" "Started"

				# Start the tunnel
				/scripts/start_single_tunnel.sh "$remote_host" "$remote_port" "$local_port" "$direction" &
				return 0
			fi
		done
}

# Function to stop a tunnel
stop_tunnel() {
	local log_id=$1
	echo "Stopping removed tunnel ${log_id}"

	# Kill the tunnel process
	pkill -f "TUNNEL_ID=${log_id}" 2>/dev/null

	# Archive the log file before removal
	local log_file="${LOG_DIR}/tunnel_${log_id}.log"
	if [ -f "$log_file" ]; then
		# Add final entry to log
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Tunnel removed from configuration" >>"$log_file"

		# Compress and archive the log
		gzip -c "$log_file" >"${log_file}.removed_$(date '+%Y%m%d_%H%M%S').gz"

		# Remove the original log file
		rm -f "$log_file"

		echo "Archived log file to ${log_file}.removed_$(date '+%Y%m%d_%H%M%S').gz"
	fi
}

# Initialize state file with current tunnels
get_current_tunnel_ids >"$STATE_FILE"

while true; do
	# Monitor the config directory for changes to config.yaml
	# We monitor the directory instead of the file directly because:
	# 1. Some editors (VSCode, etc.) delete and recreate files on save
	# 2. Docker volume mounts may not propagate inode changes correctly
	# 3. Monitoring the directory catches all types of file modifications
	inotifywait -e modify,create,move,delete,moved_to,moved_from,close_write,attrib "$(dirname "$CONFIG_FILE")" 2>/dev/null | grep -q "config.yaml"
	echo "检测到配置文件变化，分析差异..."
	echo "Detected configuration file changes, analyzing differences..."

	# Consume any additional events within a short time window
	sleep 3
	while inotifywait -t 1 -e modify,create,move,delete,moved_to,moved_from,close_write,attrib "$(dirname "$CONFIG_FILE")" 2>/dev/null | grep -q "config.yaml"; do
		echo "Consuming additional config change event..."
		sleep 1
	done

	# Get old and new tunnel IDs
	old_ids=$(cat "$STATE_FILE" 2>/dev/null || echo "")
	new_ids=$(get_current_tunnel_ids)

	# Find added, removed, and unchanged tunnels
	added_ids=$(echo "$new_ids" | grep -vxF "$old_ids" 2>/dev/null || echo "")
	removed_ids=$(echo "$old_ids" | grep -vxF "$new_ids" 2>/dev/null || echo "")

	# Process changes
	changes_made=false

	# Stop removed tunnels
	if [ -n "$removed_ids" ]; then
		echo "Removed tunnels:"
		echo "$removed_ids" | while read -r log_id; do
			[ -n "$log_id" ] && stop_tunnel "$log_id"
		done
		changes_made=true
	fi

	# Start new tunnels
	if [ -n "$added_ids" ]; then
		echo "New tunnels:"
		echo "$added_ids" | while read -r log_id; do
			[ -n "$log_id" ] && start_new_tunnel "$log_id"
		done
		changes_made=true
	fi

	if [ "$changes_made" = "false" ]; then
		echo "No tunnel configuration changes detected (only metadata changed)"
	fi

	# Update state file
	echo "$new_ids" >"$STATE_FILE"

	# Add a cooldown period
	sleep 5
done
