#!/bin/sh

# state_manager.sh - Tunnel state management module
# This module provides functions to track and manage autossh tunnel states

# Default state file location
DEFAULT_STATE_FILE="/tmp/autossh_tunnels.state"

# Get state file path (can be overridden by environment variable)
get_state_file() {
	echo "${AUTOSSH_STATE_FILE:-$DEFAULT_STATE_FILE}"
}

# Function to get running tunnel hashes
get_running_tunnel_hashes() {
	local state_file=$(get_state_file)
	if [ -f "$state_file" ]; then
		cut -f6 "$state_file" 2>/dev/null || true
	fi
}

# Function to save tunnel state
save_tunnel_state() {
	local remote_host=$1
	local remote_port=$2
	local local_port=$3
	local direction=$4
	local name=$5
	local hash=$6
	local pid=$7
	local state_file=$(get_state_file)

	echo "$remote_host	$remote_port	$local_port	$direction	$name	$hash	$pid" >>"$state_file"
}

# Function to remove tunnel from state
remove_tunnel_from_state() {
	local hash=$1
	local state_file=$(get_state_file)
	if [ -f "$state_file" ]; then
		grep -v "	$hash	" "$state_file" >"$state_file.tmp" 2>/dev/null || true
		mv "$state_file.tmp" "$state_file" 2>/dev/null || true
	fi
}

# Function to get PID by tunnel hash
get_tunnel_pid() {
	local hash=$1
	local state_file=$(get_state_file)
	if [ -f "$state_file" ]; then
		grep "	$hash	" "$state_file" 2>/dev/null | cut -f7 || true
	fi
}

# Function to get tunnel info by hash
get_tunnel_info() {
	local hash=$1
	local state_file=$(get_state_file)
	if [ -f "$state_file" ]; then
		grep "	$hash	" "$state_file" 2>/dev/null || true
	fi
}

# Function to get tunnel name by hash
get_tunnel_name() {
	local hash=$1
	local state_file=$(get_state_file)
	if [ -f "$state_file" ]; then
		grep "	$hash	" "$state_file" 2>/dev/null | cut -f5 || echo "unknown"
	fi
}

# Function to check if tunnel is running
is_tunnel_running() {
	local hash=$1
	local pid=$(get_tunnel_pid "$hash")

	if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
		return 0 # Running
	else
		return 1 # Not running
	fi
}

# Function to stop tunnel by hash
stop_tunnel_by_hash() {
	local hash=$1
	local pid=$(get_tunnel_pid "$hash")
	local name=$(get_tunnel_name "$hash")

	# Source logger if not already loaded
	if ! command -v log_info >/dev/null 2>&1; then
		# Try multiple possible locations for logger.sh
		if [ -f "/usr/local/bin/scripts/logger.sh" ]; then
			. "/usr/local/bin/scripts/logger.sh"
		elif [ -f "$(dirname "$0")/logger.sh" ]; then
			. "$(dirname "$0")/logger.sh"
		else
			# Fallback to simple echo if logger not found
			log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [$1] $2"; }
			log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [$1] $2" >&2; }
		fi
	fi

	if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
		log_info "STATE" "Stopping tunnel: $name ($hash, PID: $pid)"
		kill "$pid" 2>/dev/null || true
		sleep 1
		# Force kill if still running
		if kill -0 "$pid" 2>/dev/null; then
			log_info "STATE" "Force stopping tunnel: $name ($hash)"
			kill -9 "$pid" 2>/dev/null || true
		fi
	fi

	# Remove tunnel from state
	remove_tunnel_from_state "$hash"

	# Clean up log file
	local log_file="/tmp/autossh-logs/tunnel-${hash}.log"
	if [ -f "$log_file" ]; then
		log_info "STATE" "Removing log file: $log_file"
		rm -f "$log_file"
	fi
}

# Function to cleanup all managed tunnels
cleanup_managed_tunnels() {
	local state_file=$(get_state_file)
	log_info "STATE" "Cleaning up managed tunnels..."

	if [ -f "$state_file" ]; then
		while IFS=$'\t' read -r remote_host remote_port local_port direction name hash pid; do
			if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
				log_info "STATE" "Stopping tunnel: $name ($hash)"
				kill "$pid" 2>/dev/null || true
			fi
		done <"$state_file"

		# Wait a moment for graceful shutdown
		sleep 2

		# Force kill any remaining processes and clean up log files
		while IFS=$'\t' read -r remote_host remote_port local_port direction name hash pid; do
			if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
				log_info "STATE" "Force stopping tunnel: $name ($hash)"
				kill -9 "$pid" 2>/dev/null || true
			fi

			# Clean up log file for this tunnel
			local log_file="/tmp/autossh-logs/tunnel-${hash}.log"
			if [ -f "$log_file" ]; then
				log_info "STATE" "Removing log file: $log_file"
				rm -f "$log_file"
			fi
		done <"$state_file"
	fi

	# Clear state file
	>"$state_file"

	# Clean up any remaining log files (in case of orphaned logs)
	if [ -d "/tmp/autossh-logs" ]; then
		log_info "STATE" "Cleaning up any remaining log files..."
		rm -f /tmp/autossh-logs/tunnel-*.log 2>/dev/null || true
		# Remove directory if empty
		rmdir /tmp/autossh-logs 2>/dev/null || true
	fi
}

# Function to list all managed tunnels
list_managed_tunnels() {
	local state_file=$(get_state_file)
	if [ -f "$state_file" ]; then
		echo "Managed tunnels:"
		while IFS=$'\t' read -r remote_host remote_port local_port direction name hash pid; do
			if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
				status="RUNNING"
			else
				status="STOPPED"
			fi
			printf "  %-20s %-10s %s -> %s:%s (%s)\n" "$name" "$status" "$local_port" "$remote_host" "$remote_port" "$hash"
		done <"$state_file"
	else
		echo "No managed tunnels found."
	fi
}

# Function to clean up dead processes from state file
cleanup_dead_processes() {
	local state_file=$(get_state_file)
	local temp_file=$(mktemp)

	if [ -f "$state_file" ]; then
		while IFS=$'\t' read -r remote_host remote_port local_port direction name hash pid; do
			if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
				# Process is still running, keep it
				echo "$remote_host	$remote_port	$local_port	$direction	$name	$hash	$pid" >>"$temp_file"
			else
				log_info "STATE" "Removing dead process from state: $name ($hash, PID: $pid)"
				# Clean up log file for dead process
				local log_file="/tmp/autossh-logs/tunnel-${hash}.log"
				if [ -f "$log_file" ]; then
					log_info "STATE" "Removing log file for dead process: $log_file"
					rm -f "$log_file"
				fi
			fi
		done <"$state_file"

		mv "$temp_file" "$state_file"
	fi

	rm -f "$temp_file"
}

# Function to start a specific tunnel by hash
start_tunnel_by_hash() {
	local hash=$1
	local config_file="${AUTOSSH_CONFIG_FILE:-/etc/autossh/config/config.yaml}"

	# Source logger if not already loaded
	if ! command -v log_info >/dev/null 2>&1; then
		# Try multiple possible locations for logger.sh
		if [ -f "/usr/local/bin/scripts/logger.sh" ]; then
			. "/usr/local/bin/scripts/logger.sh"
		elif [ -f "$(dirname "$0")/logger.sh" ]; then
			. "$(dirname "$0")/logger.sh"
		else
			# Fallback to simple echo if logger not found
			log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [$1] $2"; }
			log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [$1] $2" >&2; }
		fi
	fi

	# Source config parser if not already loaded
	if ! command -v parse_config >/dev/null 2>&1; then
		# Try multiple possible locations for config_parser.sh
		if [ -f "/usr/local/bin/scripts/config_parser.sh" ]; then
			. "/usr/local/bin/scripts/config_parser.sh"
		elif [ -f "$(dirname "$0")/config_parser.sh" ]; then
			. "$(dirname "$0")/config_parser.sh"
		else
			log_error "STATE" "Cannot find config_parser.sh module"
			return 1
		fi
	fi

	# Check if tunnel is already running
	if is_tunnel_running "$hash"; then
		local name=$(get_tunnel_name "$hash")
		log_info "STATE" "Tunnel already running: $name ($hash)"
		return 0
	fi

	# Find tunnel configuration by hash
	local tunnel_config=$(parse_config "$config_file" | grep "	$hash	")

	if [ -z "$tunnel_config" ]; then
		log_error "STATE" "Tunnel configuration not found for hash: $hash"
		return 1
	fi

	# Parse tunnel configuration
	local remote_host=$(echo "$tunnel_config" | cut -f1)
	local remote_port=$(echo "$tunnel_config" | cut -f2)
	local local_port=$(echo "$tunnel_config" | cut -f3)
	local direction=$(echo "$tunnel_config" | cut -f4)
	local name=$(echo "$tunnel_config" | cut -f5)
	local interactive=$(echo "$tunnel_config" | cut -f7)

	# Skip interactive tunnels
	if [ "$interactive" = "true" ]; then
		log_info "STATE" "Skipping interactive tunnel: $name ($hash)"
		return 0
	fi

	log_info "STATE" "Starting tunnel: $name ($hash)"

	# Start the tunnel directly without sourcing start_autossh.sh
	# This avoids the complex dependency chain
	SSH_CONFIG_DIR="${SSH_CONFIG_DIR:-/home/myuser/.ssh}"

	# Parse ports
	if echo "$remote_port" | grep -q ":"; then
		target_host=$(echo "$remote_port" | cut -d: -f1)
		target_port=$(echo "$remote_port" | cut -d: -f2)
	else
		target_host="localhost"
		target_port="$remote_port"
	fi

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

	# Create log directory if it doesn't exist
	log_dir="/tmp/autossh-logs"
	mkdir -p "$log_dir"
	log_file="$log_dir/tunnel-${hash}.log"

	# Start tunnel in background
	if [ "$direction" = "local_to_remote" ]; then
		log_info "STATE" "Starting SSH tunnel (local to remote): $local_host:$local_port -> $remote_host:$remote_port"
		autossh $ssh_opts -N -R $target_host:$target_port:$local_host:$local_port $remote_host >>"$log_file" 2>&1 &
	else
		log_info "STATE" "Starting SSH tunnel (remote to local): $local_host:$local_port <- $remote_host:$remote_port"
		autossh $ssh_opts -N -L $local_host:$local_port:$target_host:$target_port $remote_host >>"$log_file" 2>&1 &
	fi
	tunnel_pid=$!

	# Save tunnel state
	save_tunnel_state "$remote_host" "$remote_port" "$local_port" "$direction" "$name" "$hash" "$tunnel_pid"

	log_info "STATE" "Tunnel started successfully: $name ($hash, PID: $tunnel_pid)"
	return 0
}

# Function to get tunnel statistics
get_tunnel_stats() {
	local state_file=$(get_state_file)
	local total=0
	local running=0
	local stopped=0

	if [ -f "$state_file" ]; then
		while IFS=$'\t' read -r remote_host remote_port local_port direction name hash pid; do
			total=$((total + 1))
			if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
				running=$((running + 1))
			else
				stopped=$((stopped + 1))
			fi
		done <"$state_file"
	fi

	echo "Tunnel Statistics:"
	echo "  Total: $total"
	echo "  Running: $running"
	echo "  Stopped: $stopped"
}
