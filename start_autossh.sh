#!/bin/sh

# Load the configuration from config.yaml
CONFIG_FILE="/etc/autossh/config/config.yaml"
LOG_DIR="/var/log/autossh"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Clear old log files for fresh start
rm -f "$LOG_DIR"/tunnel_*.log

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

	if [ "$direction" = "local_to_remote" ]; then
		echo "Starting SSH tunnel (local to remote): $local_host:$local_port -> $remote_host:$remote_port [Log ID: ${log_id}]"
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting tunnel (local to remote): $local_host:$local_port -> $remote_host:$remote_port" >>"$log_file"
		autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -N -R $target_host:$target_port:$local_host:$local_port $remote_host >>"$log_file" 2>&1
	else
		echo "Starting SSH tunnel (remote to local): $local_host:$local_port <- $remote_host:$remote_port [Log ID: ${log_id}]"
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting tunnel (remote to local): $local_host:$local_port <- $remote_host:$remote_port" >>"$log_file"
		autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -N -L $local_host:$local_port:$target_host:$target_port $remote_host >>"$log_file" 2>&1
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
