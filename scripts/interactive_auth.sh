#!/bin/sh

# interactive_auth.sh - Interactive SSH Tunnel Manager
# Handles manual authentication (2FA/Password) for SSH tunnels using plain ssh with backgrounding
#
# This module is designed for tunnels that require interactive authentication,
# such as servers with 2FA (Duo, Google Authenticator) or password-only access.
# Unlike autossh, this uses plain ssh to avoid automatic reconnection attempts
# that could trigger fail2ban or account lockouts.

# Get the directory where this script is located
SCRIPT_DIR="$(dirname "$0")"

# Source required modules if not already loaded
if ! command -v parse_config >/dev/null 2>&1; then
	if [ -f "$SCRIPT_DIR/config_parser.sh" ]; then
		. "$SCRIPT_DIR/config_parser.sh"
	fi
fi

if ! command -v save_tunnel_state >/dev/null 2>&1; then
	if [ -f "$SCRIPT_DIR/state_manager.sh" ]; then
		. "$SCRIPT_DIR/state_manager.sh"
	fi
fi

if ! command -v log_info >/dev/null 2>&1; then
	if [ -f "$SCRIPT_DIR/logger.sh" ]; then
		. "$SCRIPT_DIR/logger.sh"
	else
		# Fallback to simple echo if logger not found
		log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [$1] $2"; }
		log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [$1] $2" >&2; }
	fi
fi

# Control socket directory
# Use home directory to avoid permission issues between users
get_sockets_dir() {
	local sockets_dir="${HOME}/.autossh-sockets"
	mkdir -p "$sockets_dir"
	chmod 700 "$sockets_dir"
	echo "$sockets_dir"
}

# Function to start an interactive tunnel
# This function will prompt for password/2FA and then background the SSH connection
start_interactive_tunnel() {
	local input_hash=$1
	local config_file="${AUTOSSH_CONFIG_FILE:-/etc/autossh/config/config.yaml}"
	local ssh_config_dir="${SSH_CONFIG_DIR:-/home/myuser/.ssh}"

	# Check required modules
	if ! command -v parse_config >/dev/null 2>&1; then
		log_error "INTERACTIVE" "config_parser.sh not loaded"
		return 1
	fi

	if ! command -v save_tunnel_state >/dev/null 2>&1; then
		log_error "INTERACTIVE" "state_manager.sh not loaded"
		return 1
	fi

	# Resolve hash prefix to full hash
	local target_hash
	target_hash=$(resolve_hash_prefix "$input_hash")
	if [ $? -ne 0 ]; then
		# Error message already printed by resolve_hash_prefix
		return 1
	fi

	# Find tunnel configuration
	local tunnel_config=$(parse_config "$config_file" | grep "	$target_hash	")

	if [ -z "$tunnel_config" ]; then
		log_error "INTERACTIVE" "Tunnel configuration not found for hash: $target_hash"
		return 1
	fi

	# Parse configuration
	local remote_host=$(echo "$tunnel_config" | cut -f1)
	local remote_port=$(echo "$tunnel_config" | cut -f2)
	local local_port=$(echo "$tunnel_config" | cut -f3)
	local direction=$(echo "$tunnel_config" | cut -f4)
	local name=$(echo "$tunnel_config" | cut -f5)
	local interactive=$(echo "$tunnel_config" | cut -f7)

	log_info "INTERACTIVE" "Initializing interactive tunnel: $name ($target_hash)"

	# Verify this is an interactive tunnel
	if [ "$interactive" != "true" ]; then
		log_error "INTERACTIVE" "Tunnel '$name' is not marked as interactive. Use 'autossh-cli start-tunnel' instead."
		return 1
	fi

	# Check if already running
	if is_tunnel_running "$target_hash"; then
		log_info "INTERACTIVE" "Tunnel is already running: $name ($target_hash)"
		return 0
	fi

	# Parse remote port (may contain host:port)
	local target_host
	local target_port
	if echo "$remote_port" | grep -q ":"; then
		target_host=$(echo "$remote_port" | cut -d: -f1)
		target_port=$(echo "$remote_port" | cut -d: -f2)
	else
		target_host="localhost"
		target_port="$remote_port"
	fi

	# Parse local port (may contain host:port)
	local local_host
	local local_port_num
	if echo "$local_port" | grep -q ":"; then
		local_host=$(echo "$local_port" | cut -d: -f1)
		local_port_num=$(echo "$local_port" | cut -d: -f2)
	else
		local_host="localhost"
		local_port_num="$local_port"
	fi

	# Prepare Control Socket path for PID tracking
	local sockets_dir=$(get_sockets_dir)
	local ctrl_socket="$sockets_dir/$target_hash"

	# Cleanup stale socket if exists
	if [ -e "$ctrl_socket" ]; then
		log_info "INTERACTIVE" "Cleaning up stale control socket"
		rm -f "$ctrl_socket"
	fi

	# Build SSH options
	# -f: Go to background after authentication
	# -N: Do not execute a remote command (port forwarding only)
	# -M: Master mode for connection sharing (used here for PID tracking via socket)
	# -S: Control socket path
	local ssh_opts="-f -N -M -S $ctrl_socket"
	ssh_opts="$ssh_opts -o ServerAliveInterval=30"
	ssh_opts="$ssh_opts -o ServerAliveCountMax=3"
	ssh_opts="$ssh_opts -o SetEnv=TUNNEL_HASH=$target_hash"

	# Add SSH config directory if it exists
	if [ -d "$ssh_config_dir" ] && [ -f "$ssh_config_dir/config" ]; then
		ssh_opts="$ssh_opts -F $ssh_config_dir/config"
	fi

	# Create log directory if it doesn't exist
	local log_dir="/tmp/autossh-logs"
	mkdir -p "$log_dir"
	local log_file="$log_dir/tunnel-${target_hash}.log"

	echo ""
	log_info "INTERACTIVE" "Starting SSH session for: $name" | tee -a "$log_file"
	log_info "INTERACTIVE" "You may be prompted for password or 2FA." | tee -a "$log_file"
	log_info "INTERACTIVE" "The session will go to background upon successful authentication." | tee -a "$log_file"
	echo ""

	# Execute SSH command based on direction
	# Note: ssh -f will fork to background after successful authentication
	# The exit code reflects whether authentication succeeded
	# We use a temporary file to capture the exit code since we're in /bin/sh (not bash)
	local ssh_result
	local ssh_exit_file=$(mktemp)
	if [ "$direction" = "local_to_remote" ]; then
		# Remote Forwarding (-R): expose local service to remote
		log_info "INTERACTIVE" "Direction: local_to_remote (Remote Forwarding)" | tee -a "$log_file"
		log_info "INTERACTIVE" "Forwarding: $local_host:$local_port_num -> $remote_host:$target_host:$target_port" | tee -a "$log_file"
		# Run ssh and capture exit code, while still showing output to terminal and log
		(
			ssh $ssh_opts -R $target_host:$target_port:$local_host:$local_port_num $remote_host 2>&1
			echo $? >"$ssh_exit_file"
		) | tee -a "$log_file"
		ssh_result=$(cat "$ssh_exit_file")
	else
		# Local Forwarding (-L): bring remote service to local (default)
		log_info "INTERACTIVE" "Direction: remote_to_local (Local Forwarding)" | tee -a "$log_file"
		log_info "INTERACTIVE" "Forwarding: $local_host:$local_port_num <- $remote_host:$target_host:$target_port" | tee -a "$log_file"
		# Run ssh and capture exit code, while still showing output to terminal and log
		(
			ssh $ssh_opts -L $local_host:$local_port_num:$target_host:$target_port $remote_host 2>&1
			echo $? >"$ssh_exit_file"
		) | tee -a "$log_file"
		ssh_result=$(cat "$ssh_exit_file")
	fi
	rm -f "$ssh_exit_file"

	if [ $ssh_result -eq 0 ]; then
		echo "" | tee -a "$log_file"
		log_info "INTERACTIVE" "Authentication successful. Tunnel running in background." | tee -a "$log_file"

		# Wait a moment for the control socket to be created
		sleep 1

		# Retrieve PID from Control Socket
		local check_output=$(ssh -S "$ctrl_socket" -O check ignored-host 2>&1)
		# Output format: "Master running (pid=12345)"
		local ssh_pid=$(echo "$check_output" | sed -n 's/.*pid=\([0-9]*\).*/\1/p')

		if [ -n "$ssh_pid" ]; then
			log_info "INTERACTIVE" "Tunnel PID: $ssh_pid" | tee -a "$log_file"
			save_tunnel_state "$remote_host" "$remote_port" "$local_port" "$direction" "$name" "$target_hash" "$ssh_pid"
			log_info "INTERACTIVE" "Tunnel registered in state file." | tee -a "$log_file"
			echo "" | tee -a "$log_file"
			log_info "INTERACTIVE" "Tunnel '$name' is now running." | tee -a "$log_file"
			log_info "INTERACTIVE" "Use 'autossh-cli status' to check tunnel status." | tee -a "$log_file"
			log_info "INTERACTIVE" "Use 'autossh-cli stop-tunnel $target_hash' to stop." | tee -a "$log_file"
		else
			log_error "INTERACTIVE" "Could not retrieve tunnel PID from control socket." | tee -a "$log_file"
			log_error "INTERACTIVE" "Debug output: $check_output" | tee -a "$log_file"
			log_info "INTERACTIVE" "The tunnel may still be running. Check with 'ps aux | grep ssh'" | tee -a "$log_file"
			return 1
		fi
	else
		echo "" | tee -a "$log_file"
		log_error "INTERACTIVE" "SSH exited with error code $ssh_result" | tee -a "$log_file"
		log_error "INTERACTIVE" "Authentication may have failed or connection was refused." | tee -a "$log_file"
		return $ssh_result
	fi
}

# Function to stop an interactive tunnel using control socket
stop_interactive_tunnel() {
	local input_hash=$1

	# Resolve hash prefix to full hash
	local target_hash
	target_hash=$(resolve_hash_prefix "$input_hash")
	if [ $? -ne 0 ]; then
		return 1
	fi

	local sockets_dir=$(get_sockets_dir)
	local ctrl_socket="$sockets_dir/$target_hash"

	if [ -e "$ctrl_socket" ]; then
		log_info "INTERACTIVE" "Stopping tunnel via control socket: $target_hash"
		ssh -S "$ctrl_socket" -O exit ignored-host 2>/dev/null
		rm -f "$ctrl_socket"
	fi

	# Also use the standard stop mechanism
	stop_tunnel_by_hash "$target_hash"
}

# Function to check interactive tunnel status via control socket
check_interactive_tunnel() {
	local input_hash=$1

	# Resolve hash prefix to full hash
	local target_hash
	target_hash=$(resolve_hash_prefix "$input_hash")
	if [ $? -ne 0 ]; then
		return 1
	fi

	local sockets_dir=$(get_sockets_dir)
	local ctrl_socket="$sockets_dir/$target_hash"

	if [ -e "$ctrl_socket" ]; then
		local check_output=$(ssh -S "$ctrl_socket" -O check ignored-host 2>&1)
		if echo "$check_output" | grep -q "Master running"; then
			local ssh_pid=$(echo "$check_output" | sed -n 's/.*pid=\([0-9]*\).*/\1/p')
			echo "RUNNING (PID: $ssh_pid)"
			return 0
		else
			echo "STOPPED (socket exists but master not running)"
			return 1
		fi
	else
		echo "STOPPED (no control socket)"
		return 1
	fi
}

# Function to cleanup stale control sockets
cleanup_interactive_sockets() {
	local sockets_dir=$(get_sockets_dir)

	if [ -d "$sockets_dir" ]; then
		log_info "INTERACTIVE" "Cleaning up stale control sockets..."
		for socket in "$sockets_dir"/*; do
			if [ -e "$socket" ]; then
				local hash=$(basename "$socket")
				local check_output=$(ssh -S "$socket" -O check ignored-host 2>&1)
				if ! echo "$check_output" | grep -q "Master running"; then
					log_info "INTERACTIVE" "Removing stale socket: $hash"
					rm -f "$socket"
				fi
			fi
		done
	fi
}
