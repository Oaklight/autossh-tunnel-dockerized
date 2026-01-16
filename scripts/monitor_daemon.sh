#!/bin/sh

# Monitor daemon that keeps the container alive and monitors tunnel status
# This script runs continuously and provides status information via API

CONFIG_FILE="/etc/autossh/config/config.yaml"
LOG_DIR="/var/log/autossh"
STATUS_FILE="/tmp/tunnel_status.json"
CHECK_INTERVAL=5 # Check status every 5 seconds

# Function to generate log ID
generate_log_id() {
	local remote_host=$1
	local remote_port=$2
	local local_port=$3
	local direction=$4
	local config_string="${remote_host}:${remote_port}:${local_port}:${direction}"
	echo -n "$config_string" | md5sum | cut -c1-8
}

# Function to parse log file and extract status
parse_log_status() {
	local log_file=$1
	local status="unknown"
	local last_update=""
	local message="No log data available"

	if [ ! -f "$log_file" ]; then
		echo "disconnected|Log file not found|"
		return
	fi

	# Read last 20 lines
	local lines=$(tail -n 20 "$log_file" 2>/dev/null)

	if [ -z "$lines" ]; then
		echo "disconnected|Log file is empty|"
		return
	fi

	# Parse lines from bottom to top to get most recent status
	# Use a temporary file to avoid subshell issues with pipes
	local temp_result=$(mktemp)
	local found_disconnect=false
	local disconnect_time=""

	echo "$lines" | tac | while IFS= read -r line; do
		# Skip if we already found a definitive result
		[ -s "$temp_result" ] && continue

		# Extract timestamp if present
		if echo "$line" | grep -q '\[.*\]'; then
			last_update=$(echo "$line" | sed -n 's/.*\[\([^]]*\)\].*/\1/p' | head -1)
		fi

		# Check for disconnection FIRST (most recent events)
		if echo "$line" | grep -q "Connection closed\|Connection reset"; then
			if [ ! -s "$temp_result" ]; then
				echo "disconnected|Connection lost|$last_update" >"$temp_result"
			fi
			continue
		fi

		# Check for restart indicators (high priority)
		if echo "$line" | grep -q "Restarting tunnel\|Tunnel restart requested"; then
			if [ ! -s "$temp_result" ]; then
				echo "connected|Tunnel restarting|$last_update" >"$temp_result"
			fi
			continue
		fi

		# Check for successful connection
		if echo "$line" | grep -q "Connection established\|Authenticated to"; then
			if [ ! -s "$temp_result" ]; then
				echo "connected|Connected|$last_update" >"$temp_result"
			fi
			continue
		fi

		# Check for error conditions
		if echo "$line" | grep -q "Permission denied\|Connection refused\|Could not resolve hostname"; then
			if [ ! -s "$temp_result" ]; then
				message=$(echo "$line" | sed 's/^[^]]*] //')
				echo "error|$message|$last_update" >"$temp_result"
			fi
			continue
		fi

		# Check for tunnel start (only if no other status found)
		if echo "$line" | grep -q "Starting tunnel"; then
			if [ ! -s "$temp_result" ]; then
				echo "connected|Tunnel starting|$last_update" >"$temp_result"
			fi
			continue
		fi
	done

	# Read result from temp file
	if [ -s "$temp_result" ]; then
		cat "$temp_result"
		rm -f "$temp_result"
	else
		rm -f "$temp_result"
		# No specific status found
		if [ -n "$last_update" ]; then
			echo "unknown|No recent activity|$last_update"
		else
			echo "unknown|No status information|"
		fi
	fi
}

# Function to update status file
update_status() {
	local tunnels_json=""
	local first=true
	local temp_file=$(mktemp)

	# Parse config and check each tunnel
	# Use cut to properly handle empty fields in TSV
	yq e '.tunnels[] | [.name, .remote_host, .remote_port, .local_port, .direction] | @tsv' "$CONFIG_FILE" | while IFS= read -r line; do
		# Use cut to extract fields (handles empty fields correctly)
		name=$(echo "$line" | cut -f1)
		remote_host=$(echo "$line" | cut -f2)
		remote_port=$(echo "$line" | cut -f3)
		local_port=$(echo "$line" | cut -f4)
		direction=$(echo "$line" | cut -f5)

		log_id=$(generate_log_id "$remote_host" "$remote_port" "$local_port" "$direction")
		log_file="${LOG_DIR}/tunnel_${log_id}.log"

		# Parse status from log
		status_info=$(parse_log_status "$log_file")
		status=$(echo "$status_info" | cut -d'|' -f1)
		message=$(echo "$status_info" | cut -d'|' -f2)
		last_update=$(echo "$status_info" | cut -d'|' -f3)

		# Escape special characters in message for JSON
		# Replace backslashes first, then quotes, then convert newlines/tabs to spaces
		# Also remove any control characters
		message=$(printf '%s' "$message" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n\t\r' '   ' | tr -d '\000-\037' | sed 's/  */ /g; s/^ //; s/ $//')

		# Build JSON object and append to temp file
		if [ "$first" = true ]; then
			first=false
		else
			echo -n "," >>"$temp_file"
		fi

		echo -n "{\"name\":\"${name}\",\"remote_host\":\"${remote_host}\",\"remote_port\":\"${remote_port}\",\"local_port\":\"${local_port}\",\"direction\":\"${direction}\",\"log_id\":\"${log_id}\",\"status\":\"${status}\",\"message\":\"${message}\",\"last_update\":\"${last_update}\"}" >>"$temp_file"
	done

	# Read accumulated JSON from temp file
	tunnels_json=$(cat "$temp_file")
	rm -f "$temp_file"

	# Write to status file with timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	echo "{\"tunnels\":[${tunnels_json}],\"timestamp\":\"${timestamp}\"}" >"$STATUS_FILE"
}

echo "Monitor daemon started. Checking tunnel status every ${CHECK_INTERVAL} seconds..."

# Main monitoring loop
while true; do
	update_status
	sleep "$CHECK_INTERVAL"
done
