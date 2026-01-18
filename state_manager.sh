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

	if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
		echo "Stopping tunnel: $name ($hash, PID: $pid)"
		kill "$pid" 2>/dev/null || true
		sleep 1
		# Force kill if still running
		if kill -0 "$pid" 2>/dev/null; then
			echo "Force stopping tunnel: $name ($hash)"
			kill -9 "$pid" 2>/dev/null || true
		fi
	fi

	remove_tunnel_from_state "$hash"
}

# Function to cleanup all managed tunnels
cleanup_managed_tunnels() {
	local state_file=$(get_state_file)
	echo "Cleaning up managed tunnels..."

	if [ -f "$state_file" ]; then
		while IFS=$'\t' read -r remote_host remote_port local_port direction name hash pid; do
			if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
				echo "Stopping tunnel: $name ($hash)"
				kill "$pid" 2>/dev/null || true
			fi
		done <"$state_file"

		# Wait a moment for graceful shutdown
		sleep 2

		# Force kill any remaining processes
		while IFS=$'\t' read -r remote_host remote_port local_port direction name hash pid; do
			if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
				echo "Force stopping tunnel: $name ($hash)"
				kill -9 "$pid" 2>/dev/null || true
			fi
		done <"$state_file"
	fi

	# Clear state file
	>"$state_file"
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
				echo "Removing dead process from state: $name ($hash, PID: $pid)"
			fi
		done <"$state_file"

		mv "$temp_file" "$state_file"
	fi

	rm -f "$temp_file"
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
