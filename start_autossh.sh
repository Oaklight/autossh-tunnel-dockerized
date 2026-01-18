#!/bin/sh

# Load the configuration from config.yaml
CONFIG_FILE="/etc/autossh/config/config.yaml"

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

	if [ "$direction" = "local_to_remote" ]; then
		echo "Starting SSH tunnel (local to remote): $local_host:$local_port -> $remote_host:$remote_port"
		autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -N -R $target_host:$target_port:$local_host:$local_port $remote_host
	else
		echo "Starting SSH tunnel (remote to local): $local_host:$local_port <- $remote_host:$remote_port"
		autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -N -L $local_host:$local_port:$target_host:$target_port $remote_host
	fi
}

# Function to cleanup old autossh processes
cleanup_old_tunnels() {
	echo "Cleaning up old autossh processes..."
	pkill -f "autossh"
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
	cleanup_old_tunnels
	start_all_tunnels "$CONFIG_FILE"
}

# Execute main function
main
