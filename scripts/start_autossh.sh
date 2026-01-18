#!/bin/sh

# Load the configuration from config.yaml
# Allow customization via environment variables
CONFIG_FILE="${AUTOSSH_CONFIG_FILE:-/etc/autossh/config/config.yaml}"
SSH_CONFIG_DIR="${SSH_CONFIG_DIR:-/home/myuser/.ssh}"

# Get the directory where this script is located
SCRIPT_DIR="$(dirname "$0")"

# Source the configuration parser module
. "$SCRIPT_DIR/config_parser.sh"

# Source the state manager module
. "$SCRIPT_DIR/state_manager.sh"

# Function to start a single autossh tunnel
start_single_tunnel() {
	local remote_host=$1
	local remote_port=$2
	local local_port=$3
	local direction=${4:-remote_to_local} # 设置默认值为 remote_to_local
	local tunnel_hash=${5:-""}            # Optional tunnel hash for identification

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

	# Add tunnel hash as a comment in the process name for identification
	if [ -n "$tunnel_hash" ]; then
		ssh_opts="$ssh_opts -o SetEnv=TUNNEL_HASH=$tunnel_hash"
	fi

	# Create log directory if it doesn't exist
	log_dir="/tmp/autossh-logs"
	mkdir -p "$log_dir"
	
	# Generate log file name based on tunnel hash or connection info
	if [ -n "$tunnel_hash" ]; then
		log_file="$log_dir/tunnel-${tunnel_hash}.log"
	else
		log_file="$log_dir/tunnel-${remote_host}-${local_port}.log"
	fi

	if [ "$direction" = "local_to_remote" ]; then
		echo "Starting SSH tunnel (local to remote): $local_host:$local_port -> $remote_host:$remote_port" >>"$log_file"
		exec autossh $ssh_opts -N -R $target_host:$target_port:$local_host:$local_port $remote_host >>"$log_file" 2>&1
	else
		echo "Starting SSH tunnel (remote to local): $local_host:$local_port <- $remote_host:$remote_port" >>"$log_file"
		exec autossh $ssh_opts -N -L $local_host:$local_port:$target_host:$target_port $remote_host >>"$log_file" 2>&1
	fi
}

# Function to cleanup old autossh processes (legacy mode)
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

	# Clear state file for fresh start
	local state_file=$(get_state_file)
	>"$state_file"
}

# Function to start all tunnels with smart restart
start_all_tunnels() {
	local config_file=$1

	echo "Starting tunnels with smart restart..."

	# Create a temporary file to store the parsed config
	temp_file=$(mktemp)
	parse_config "$config_file" >"$temp_file"

	# Get current running tunnel hashes
	running_hashes=$(get_running_tunnel_hashes)

	# Create temporary files for comparison
	temp_running=$(mktemp)
	temp_new=$(mktemp)

	echo "$running_hashes" | sort >"$temp_running"
	cut -f6 "$temp_file" | sort >"$temp_new"

	# Find tunnels to stop (removed from config)
	to_stop=$(comm -23 "$temp_running" "$temp_new")

	# Find tunnels to start (new in config)
	to_start=$(comm -13 "$temp_running" "$temp_new")

	# Find unchanged tunnels
	unchanged=$(comm -12 "$temp_running" "$temp_new")

	# Stop removed tunnels
	if [ -n "$to_stop" ]; then
		echo "Stopping removed tunnels..."
		echo "$to_stop" | while read -r hash; do
			if [ -n "$hash" ]; then
				stop_tunnel_by_hash "$hash"
			fi
		done
	fi

	# Start new tunnels
	if [ -n "$to_start" ]; then
		echo "Starting new tunnels..."
		while IFS='	' read -r remote_host remote_port local_port direction name hash interactive; do
			if [ "$interactive" = "true" ]; then
				continue
			fi
			if echo "$to_start" | grep -q "^$hash$"; then
				echo "Starting new tunnel: ${name} (${hash})"
				start_single_tunnel "$remote_host" "$remote_port" "$local_port" "$direction" "$hash" &
				tunnel_pid=$!
				save_tunnel_state "$remote_host" "$remote_port" "$local_port" "$direction" "$name" "$hash" "$tunnel_pid"
			fi
		done <"$temp_file"
	fi

	# Report unchanged tunnels
	if [ -n "$unchanged" ]; then
		echo "Keeping existing tunnels:"
		echo "$unchanged" | while read -r hash; do
			if [ -n "$hash" ]; then
				tunnel_info=$(grep "	$hash	" "$STATE_FILE" 2>/dev/null | cut -f5 || echo "unknown")
				echo "  - $tunnel_info ($hash)"
			fi
		done
	fi

	# Clean up temporary files
	rm -f "$temp_file" "$temp_running" "$temp_new"

	echo "Smart restart completed."
}

# Main function to orchestrate the tunnel startup process
main() {
	local smart_restart=${1:-"true"} # Default to smart restart
	local state_file=$(get_state_file)

	echo "Using config file: $CONFIG_FILE"
	echo "Using SSH config dir: $SSH_CONFIG_DIR"
	echo "Using state file: $state_file"

	# Check if config file exists
	if [ ! -f "$CONFIG_FILE" ]; then
		echo "Error: Config file not found: $CONFIG_FILE"
		echo "Please ensure the config file exists or set AUTOSSH_CONFIG_FILE environment variable"
		exit 1
	fi

	if [ "$smart_restart" = "false" ] || [ ! -f "$state_file" ]; then
		echo "Performing full restart..."
		cleanup_old_tunnels
		# Initialize state file and start all tunnels
		>"$state_file"
		temp_file=$(mktemp)
		parse_config "$CONFIG_FILE" >"$temp_file"
		while IFS='	' read -r remote_host remote_port local_port direction name hash interactive; do
			if [ "$interactive" = "true" ]; then
				echo "Skipping interactive tunnel: ${name} (${hash})"
				continue
			fi
			echo "Starting tunnel: ${name} (${hash})"
			start_single_tunnel "$remote_host" "$remote_port" "$local_port" "$direction" "$hash" &
			tunnel_pid=$!
			save_tunnel_state "$remote_host" "$remote_port" "$local_port" "$direction" "$name" "$hash" "$tunnel_pid"
		done <"$temp_file"
		rm -f "$temp_file"
	else
		echo "Performing smart restart..."
		start_all_tunnels "$CONFIG_FILE"
	fi
}

# Execute main function
main "$@"
