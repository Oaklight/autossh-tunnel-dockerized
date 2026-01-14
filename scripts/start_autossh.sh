#!/bin/sh

# Load the configuration from config.yaml
CONFIG_FILE="/etc/autossh/config/config.yaml"
LOG_DIR="/var/log/autossh"
# Default log size threshold: 100KB (102400 bytes)
# This keeps recent status entries for web monitoring while preventing log bloat
LOG_SIZE=${LOG_SIZE:-102400}

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Clear old log files for fresh start (including compressed files)
rm -f "$LOG_DIR"/tunnel_*.log "$LOG_DIR"/tunnel_*.log.gz

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

	# Create a string from the configuration
	local config_string="${remote_host}:${remote_port}:${local_port}:${direction}"

	# Generate MD5 hash (first 8 characters for readability)
	echo -n "$config_string" | md5sum | cut -c1-8
}

# Function to extract header block from log file
extract_header() {
	local log_file=$1
	local header=""
	local in_header=0

	while IFS= read -r line; do
		if echo "$line" | grep -q "^========================================="; then
			if [ $in_header -eq 0 ]; then
				in_header=1
				header="${header}${line}\n"
			else
				header="${header}${line}\n"
				break
			fi
		elif [ $in_header -eq 1 ]; then
			header="${header}${line}\n"
		fi
	done <"$log_file"

	printf "%b" "$header"
}

# Function to check and compress log if needed
check_and_compress_log() {
	local log_file=$1

	# Check if file exists and get its size
	if [ ! -f "$log_file" ]; then
		return 0
	fi

	local log_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null)

	# Check if file size exceeds threshold
	if [ "$log_size" -lt "$LOG_SIZE" ]; then
		return 0
	fi

	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log file size ($log_size bytes) exceeds threshold ($LOG_SIZE bytes), compressing..."

	# Extract header block
	local header=$(extract_header "$log_file")

	# Generate timestamp for compressed file
	local timestamp=$(date '+%Y%m%d_%H%M%S')
	local compressed_file="${log_file%.log}_${timestamp}.log.gz"

	# Compress the log file
	if gzip -c "$log_file" >"$compressed_file"; then
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Created compressed file: $compressed_file"

		# Recreate log file with header only
		printf "%b" "$header" >"$log_file"

		# Add compression notice to the new log file
		{
			echo "[$(date '+%Y-%m-%d %H:%M:%S')] Previous log compressed to: $(basename "$compressed_file")"
			echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log rotation performed due to size threshold (${LOG_SIZE} bytes)"
			echo "========================================="
		} >>"$log_file"

		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log file reset with header preserved"
	else
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to compress $log_file"
		rm -f "$compressed_file"
		return 1
	fi
}

# Function to start autossh
start_autossh() {
	local remote_host=$1
	local remote_port=$2
	local local_port=$3
	local direction=${4:-remote_to_local} # 设置默认值为 remote_to_local

	# Generate unique log ID
	local log_id=$(generate_log_id "$remote_host" "$remote_port" "$local_port" "$direction")
	local log_file="${LOG_DIR}/tunnel_${log_id}.log"

	# Create a descriptive header in the log file
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

	if echo "$remote_port" | grep -q ":"; then
		target_host=$(echo "$remote_port" | cut -d: -f1)
		target_port=$(echo "$remote_port" | cut -d: -f2)
	else
		target_host="localhost"
		target_port="$remote_port"
	fi

	# Parse local_port to extract local_host and local_port
	if echo "$local_port" | grep -q ":"; then
		local_host=$(echo "$local_port" | cut -d: -f1)
		local_port=$(echo "$local_port" | cut -d: -f2)
	else
		local_host="localhost"
	fi

	# Check and compress log if needed before starting
	check_and_compress_log "$log_file"

	if [ "$direction" = "local_to_remote" ]; then
		echo "Starting SSH tunnel (local to remote): $local_host:$local_port -> $remote_host:$remote_port [Log ID: ${log_id}]"
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting tunnel (local to remote): $local_host:$local_port -> $remote_host:$remote_port" >>"$log_file"
		autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -o "ExitOnForwardFailure=yes" -N -R $target_host:$target_port:$local_host:$local_port $remote_host >>"$log_file" 2>&1
	else
		echo "Starting SSH tunnel (remote to local): $local_host:$local_port <- $remote_host:$remote_port [Log ID: ${log_id}]"
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting tunnel (remote to local): $local_host:$local_port <- $remote_host:$remote_port" >>"$log_file"
		autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -o "ExitOnForwardFailure=yes" -N -L $local_host:$local_port:$target_host:$target_port $remote_host >>"$log_file" 2>&1
	fi
}

# clear old autossh processes if any
pkill -f "autossh"

# Store PIDs of background processes
pids=""

# Read the config.yaml file and start autossh for each entry
while IFS=$'\t' read -r remote_host remote_port local_port direction; do
	start_autossh "$remote_host" "$remote_port" "$local_port" "$direction" &
	pids="$pids $!"
done <<EOF
$(parse_config "$CONFIG_FILE")
EOF

# Wait for all background processes to finish
for pid in $pids; do
	wait "$pid"
done
