#!/bin/sh

# Shared utility functions for autossh tunnel management
# This file provides common functions for:
# - Log file management (creation, ID generation)
# - Process cleanup (killing autossh/SSH processes, releasing ports)
# This file should be sourced by other scripts that need these utilities

LOG_DIR="/var/log/autossh"

# Function to generate a unique log ID based on tunnel configuration
generate_log_id() {
	local remote_host=$1
	local remote_port=$2
	local local_port=$3
	local direction=$4
	local config_string="${remote_host}:${remote_port}:${local_port}:${direction}"
	echo -n "$config_string" | md5sum | cut -c1-8
}

# Function to create a fresh log file with header
# This overwrites any existing log file
create_fresh_log() {
	local remote_host=$1
	local remote_port=$2
	local local_port=$3
	local direction=$4
	local action=${5:-"Started"} # Default to "Started", can be "Restarted"

	local log_id=$(generate_log_id "$remote_host" "$remote_port" "$local_port" "$direction")
	local log_file="${LOG_DIR}/tunnel_${log_id}.log"

	# Create fresh log file with header (overwrite existing)
	{
		echo "========================================="
		echo "Tunnel Log ID: ${log_id}"
		echo "${action} at: $(date '+%Y-%m-%d %H:%M:%S')"
		echo "Configuration:"
		echo "  Remote Host: ${remote_host}"
		echo "  Remote Port: ${remote_port}"
		echo "  Local Port: ${local_port}"
		echo "  Direction: ${direction}"
		echo "========================================="
	} >"$log_file"

	echo "$log_id"
}

# Function to cleanup tunnel processes and release ports
# This is a shared utility used by both startup and restart operations
# Usage: cleanup_tunnel_processes [log_id] [local_port] [remote_host]
#   - If log_id is provided: cleanup specific tunnel by TUNNEL_ID
#   - If local_port is provided: cleanup processes using that port
#   - If remote_host is provided: cleanup SSH connections to that host
cleanup_tunnel_processes() {
	local log_id=$1
	local local_port=$2
	local remote_host=$3

	# Extract actual port number if in host:port format
	local actual_port="$local_port"
	if [ -n "$local_port" ] && echo "$local_port" | grep -q ":"; then
		actual_port=$(echo "$local_port" | cut -d: -f2)
	fi

	# Step 1: Kill autossh process by TUNNEL_ID if provided
	if [ -n "$log_id" ]; then
		pkill -9 -f "TUNNEL_ID=${log_id}" 2>/dev/null
	fi

	# Step 2: Kill processes using the specific port if provided
	if [ -n "$actual_port" ]; then
		local pids=$(lsof -ti :${actual_port} 2>/dev/null)
		if [ -n "$pids" ]; then
			echo "$pids" | xargs kill -9 2>/dev/null
		fi
	fi

	# Step 3: Kill SSH connections to remote host if provided
	if [ -n "$remote_host" ]; then
		pkill -9 -f "ssh.*${remote_host}" 2>/dev/null
	fi

	# Step 4: Short wait for cleanup
	sleep 2

	# Step 5: Verify port is free if port was provided
	if [ -n "$actual_port" ]; then
		local port_check=0
		while [ $port_check -lt 3 ]; do
			if ! netstat -tuln 2>/dev/null | grep -q ":${actual_port} "; then
				return 0
			fi
			sleep 1
			port_check=$((port_check + 1))
		done
	fi

	return 0
}

# Function to cleanup all autossh processes (used during container startup)
# This is more aggressive and cleans up everything
cleanup_all_autossh_processes() {
	echo "Cleaning up all autossh processes..."

	# Kill all autossh processes
	pkill -9 -f "autossh" 2>/dev/null

	# Kill all SSH processes that might be holding ports
	pkill -9 -f "ssh -" 2>/dev/null

	# Wait for processes to terminate
	sleep 2

	# Verify all autossh processes are gone
	local max_wait=5
	local waited=0
	while pgrep -f "autossh" >/dev/null 2>&1 && [ $waited -lt $max_wait ]; do
		echo "Waiting for old autossh processes to terminate..."
		sleep 1
		waited=$((waited + 1))
	done

	return 0
}
