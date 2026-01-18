#!/bin/sh

# Load the configuration from config.yaml
# Allow customization via environment variables
CONFIG_FILE="${AUTOSSH_CONFIG_FILE:-/etc/autossh/config/config.yaml}"
SSH_CONFIG_DIR="${SSH_CONFIG_DIR:-/home/myuser/.ssh}"

# Function to parse YAML and extract tunnel configurations
parse_config() {
	local config_file=$1
	yq e '.tunnels[] | [.remote_host, .remote_port, .local_port, .direction] | @tsv' "$config_file"
}

# Function to start a single autossh tunnel
start_single_tunnel() {
	local remote_host=$1
	local remote_port=$2
	local local_port=$3
	local direction=${4:-remote_to_local} # 设置默认值为 remote_to_local

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

	# Build SSH options
	ssh_opts="-M 0 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

	# Add SSH config directory if it exists
	if [ -d "$SSH_CONFIG_DIR" ]; then
		ssh_opts="$ssh_opts -F $SSH_CONFIG_DIR/config"
	fi

	if [ "$direction" = "local_to_remote" ]; then
		echo "Starting SSH tunnel (local to remote): $local_host:$local_port -> $remote_host:$remote_port"
		autossh $ssh_opts -N -R $target_host:$target_port:$local_host:$local_port $remote_host
	else
		echo "Starting SSH tunnel (remote to local): $local_host:$local_port <- $remote_host:$remote_port"
		autossh $ssh_opts -N -L $local_host:$local_port:$target_host:$target_port $remote_host
	fi
}

# Function to cleanup old autossh processes
cleanup_old_tunnels() {
	echo "Cleaning up old autossh processes..."
	# Use more specific pattern to avoid killing this script
	if pgrep -f "autossh.*-M.*-o" >/dev/null 2>&1; then
		pkill -f "autossh.*-M.*-o"
		echo "Old autossh processes terminated"
		sleep 2
	else
		echo "No existing autossh processes found"
	fi
}

# Function to start all tunnels from configuration
start_all_tunnels() {
	local config_file=$1

	echo "Starting all tunnels from configuration..."

	# Create a temporary file to store the parsed config
	temp_file=$(mktemp)
	parse_config "$config_file" >"$temp_file"

	# Read from the temporary file using POSIX-compatible syntax
	while IFS='	' read -r remote_host remote_port local_port direction; do
		start_single_tunnel "$remote_host" "$remote_port" "$local_port" "$direction" &
	done <"$temp_file"

	# Clean up temporary file
	rm -f "$temp_file"

	# Wait for all background processes to finish
	wait
}

# Main function to orchestrate the tunnel startup process
main() {
	echo "Using config file: $CONFIG_FILE"
	echo "Using SSH config dir: $SSH_CONFIG_DIR"

	# Check if config file exists
	if [ ! -f "$CONFIG_FILE" ]; then
		echo "Error: Config file not found: $CONFIG_FILE"
		echo "Please ensure the config file exists or set AUTOSSH_CONFIG_FILE environment variable"
		exit 1
	fi

	# Check if yq is available
	if ! command -v yq >/dev/null 2>&1; then
		echo "Error: yq command not found. Please install yq to parse YAML files"
		exit 1
	fi

	cleanup_old_tunnels
	start_all_tunnels "$CONFIG_FILE"
}

# Execute main function
main
