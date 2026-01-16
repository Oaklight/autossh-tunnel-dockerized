#!/bin/sh

# Shared log utility functions for autossh tunnel management
# This file should be sourced by other scripts that need log management

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
