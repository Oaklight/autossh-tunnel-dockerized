#!/bin/sh

# config_api.sh - Configuration API functions
# This module provides functions for managing tunnel configurations via API

# Configuration file paths
CONFIG_FILE="${CONFIG_FILE:-/home/myuser/config/config.yaml}"
CONFIG_BACKUP_DIR="${CONFIG_BACKUP_DIR:-/home/myuser/config/backups}"

# Source required modules if not already loaded
if ! command -v parse_config >/dev/null 2>&1; then
	SCRIPT_DIR="$(dirname "$0")"
	. "$SCRIPT_DIR/config_parser.sh"
fi

if ! command -v json_get_field >/dev/null 2>&1; then
	SCRIPT_DIR="$(dirname "$0")"
	. "$SCRIPT_DIR/json_utils.sh"
fi

if ! command -v log_info >/dev/null 2>&1; then
	SCRIPT_DIR="$(dirname "$0")"
	. "$SCRIPT_DIR/logger.sh"
fi

if ! command -v resolve_hash_prefix >/dev/null 2>&1; then
	SCRIPT_DIR="$(dirname "$0")"
	. "$SCRIPT_DIR/state_manager.sh"
fi

#######################################
# Helper Functions
#######################################

# Function to backup config file
# Returns: Path to backup file
backup_config() {
	mkdir -p "$CONFIG_BACKUP_DIR"
	if [ -f "$CONFIG_FILE" ]; then
		local backup_file="$CONFIG_BACKUP_DIR/config_$(date +%Y%m%d%H%M%S).yaml"
		cp "$CONFIG_FILE" "$backup_file"
		log_info "CONFIG_API" "Backed up config to $backup_file"
		echo "$backup_file"
	fi
}

# Function to write a single tunnel to YAML format
# Usage: write_tunnel_yaml "name" "remote_host" "remote_port" "local_port" "direction" "interactive"
write_tunnel_yaml() {
	local name="$1"
	local remote_host="$2"
	local remote_port="$3"
	local local_port="$4"
	local direction="$5"
	local interactive="$6"

	cat <<EOF
  - name: $name
    remote_host: $remote_host
    remote_port: "$remote_port"
    local_port: "$local_port"
    direction: $direction
    interactive: $interactive
EOF
}

#######################################
# Read Operations
#######################################

# Function to read config file and convert to JSON (all tunnels)
# Returns: JSON object with tunnels array
config_to_json() {
	if [ ! -f "$CONFIG_FILE" ]; then
		echo '{"tunnels": []}'
		return
	fi

	# Build the complete JSON
	{
		echo '{"tunnels": ['
		parse_config "$CONFIG_FILE" | {
			first=true
			while IFS='	' read -r remote_host remote_port local_port direction name hash interactive; do
				if [ -z "$name" ]; then continue; fi

				if [ "$first" = "true" ]; then
					first=false
				else
					printf ","
				fi

				if [ "$interactive" = "true" ]; then
					interactive_json="true"
				else
					interactive_json="false"
				fi

				printf '{
    "name": "%s",
    "remote_host": "%s",
    "remote_port": "%s",
    "local_port": "%s",
    "direction": "%s",
    "interactive": %s,
    "hash": "%s"
  }' "$name" "$remote_host" "$remote_port" "$local_port" "$direction" "$interactive_json" "$hash"
			done
		}
		echo ""
		echo "]}"
	}
}

# Function to get a single tunnel by hash and return as JSON
# Supports hash prefix matching via resolve_hash_prefix
# Usage: get_tunnel_json_by_hash "hash_or_prefix"
# Returns: JSON object on success, error message on failure
get_tunnel_json_by_hash() {
	local input_hash="$1"

	# Resolve hash prefix to full hash
	local full_hash
	full_hash=$(resolve_hash_prefix "$input_hash" 2>&1)
	if [ $? -ne 0 ]; then
		echo "$full_hash" # This contains the error message
		return 1
	fi

	# Find the tunnel with this hash
	parse_config "$CONFIG_FILE" | while IFS='	' read -r remote_host remote_port local_port direction name hash interactive; do
		if [ "$hash" = "$full_hash" ]; then
			if [ "$interactive" = "true" ]; then
				interactive_json="true"
			else
				interactive_json="false"
			fi

			printf '{
  "name": "%s",
  "remote_host": "%s",
  "remote_port": "%s",
  "local_port": "%s",
  "direction": "%s",
  "interactive": %s,
  "hash": "%s"
}' "$name" "$remote_host" "$remote_port" "$local_port" "$direction" "$interactive_json" "$hash"
			return 0
		fi
	done

	echo "Tunnel not found: $full_hash"
	return 1
}

#######################################
# Write Operations
#######################################

# Function to write full config from JSON
# Input: JSON with {"tunnels": [...]} format
# Usage: write_config_from_json "$json_input"
write_config_from_json() {
	local json_input="$1"
	local temp_file=$(mktemp)

	# Backup existing config
	backup_config

	# Write YAML header
	echo "tunnels:" >"$temp_file"

	# Parse JSON tunnels array and write each tunnel
	# Simple JSON parsing for our specific format
	echo "$json_input" | tr -d '\n' | sed 's/\[/\n/g' | sed 's/\]/\n/g' | sed 's/},{/}\n{/g' | while read -r line; do
		# Skip lines without tunnel data
		echo "$line" | grep -q '"name"' || continue

		local name=$(json_get_field "$line" "name")
		local remote_host=$(json_get_field "$line" "remote_host")
		local remote_port=$(json_get_field "$line" "remote_port")
		local local_port=$(json_get_field "$line" "local_port")
		local direction=$(json_get_field "$line" "direction")
		local interactive=$(json_get_bool "$line" "interactive")

		# Skip if required fields are missing
		if [ -z "$name" ] || [ -z "$remote_host" ] || [ -z "$remote_port" ] || [ -z "$local_port" ]; then
			continue
		fi

		# Default values
		[ -z "$direction" ] && direction="remote_to_local"
		[ -z "$interactive" ] && interactive="false"

		write_tunnel_yaml "$name" "$remote_host" "$remote_port" "$local_port" "$direction" "$interactive" >>"$temp_file"
	done

	mv "$temp_file" "$CONFIG_FILE"
	log_info "CONFIG_API" "Config file updated: $CONFIG_FILE"
	return 0
}

# Function to add a new tunnel from JSON
# Input: JSON with single tunnel object
# Usage: add_tunnel_from_json "$json_input"
# Returns: New tunnel hash on success, error message on failure
add_tunnel_from_json() {
	local json_input="$1"

	# Extract tunnel fields
	local name=$(json_get_field "$json_input" "name")
	local remote_host=$(json_get_field "$json_input" "remote_host")
	local remote_port=$(json_get_field "$json_input" "remote_port")
	local local_port=$(json_get_field "$json_input" "local_port")
	local direction=$(json_get_field "$json_input" "direction")
	local interactive=$(json_get_bool "$json_input" "interactive")

	# Validate required fields
	if [ -z "$name" ] || [ -z "$remote_host" ] || [ -z "$remote_port" ] || [ -z "$local_port" ]; then
		echo "Missing required fields: name, remote_host, remote_port, local_port"
		return 1
	fi

	# Default values
	[ -z "$direction" ] && direction="remote_to_local"
	[ -z "$interactive" ] && interactive="false"

	# Backup existing config
	backup_config

	# If config file doesn't exist, create it
	if [ ! -f "$CONFIG_FILE" ]; then
		echo "tunnels:" >"$CONFIG_FILE"
	fi

	# Append new tunnel to config
	write_tunnel_yaml "$name" "$remote_host" "$remote_port" "$local_port" "$direction" "$interactive" >>"$CONFIG_FILE"

	# Calculate and return the new hash
	local new_hash=$(calculate_tunnel_hash "$name" "$remote_host" "$remote_port" "$local_port" "$direction" "$interactive")

	log_info "CONFIG_API" "Added new tunnel: $name ($new_hash)"
	echo "$new_hash"
	return 0
}

# Function to update a single tunnel by hash
# Input: target_hash and JSON with tunnel data
# Usage: update_tunnel_by_hash "hash" "$json_input"
# Returns: New tunnel hash on success, error message on failure
update_tunnel_by_hash() {
	local target_hash="$1"
	local json_input="$2"
	local temp_file=$(mktemp)

	# Resolve hash prefix to full hash
	local full_hash
	full_hash=$(resolve_hash_prefix "$target_hash" 2>&1)
	if [ $? -ne 0 ]; then
		echo "$full_hash"
		return 1
	fi

	# Extract new tunnel fields
	local new_name=$(json_get_field "$json_input" "name")
	local new_remote_host=$(json_get_field "$json_input" "remote_host")
	local new_remote_port=$(json_get_field "$json_input" "remote_port")
	local new_local_port=$(json_get_field "$json_input" "local_port")
	local new_direction=$(json_get_field "$json_input" "direction")
	local new_interactive=$(json_get_bool "$json_input" "interactive")

	# Default values
	[ -z "$new_direction" ] && new_direction="remote_to_local"
	[ -z "$new_interactive" ] && new_interactive="false"

	# Backup existing config
	backup_config

	# Write YAML header
	echo "tunnels:" >"$temp_file"

	# Process existing tunnels
	parse_config "$CONFIG_FILE" | while IFS='	' read -r remote_host remote_port local_port direction name hash interactive; do
		if [ -z "$name" ]; then continue; fi

		if [ "$hash" = "$full_hash" ]; then
			# Write updated tunnel
			write_tunnel_yaml "$new_name" "$new_remote_host" "$new_remote_port" "$new_local_port" "$new_direction" "$new_interactive" >>"$temp_file"
		else
			# Write existing tunnel unchanged
			write_tunnel_yaml "$name" "$remote_host" "$remote_port" "$local_port" "$direction" "$interactive" >>"$temp_file"
		fi
	done

	# Check if tunnel was found (need to re-check since we're in a subshell)
	if ! grep -q "$full_hash" "$CONFIG_FILE" 2>/dev/null && ! parse_config "$CONFIG_FILE" | grep -q "$full_hash"; then
		rm -f "$temp_file"
		echo "Tunnel not found: $full_hash"
		return 1
	fi

	mv "$temp_file" "$CONFIG_FILE"
	log_info "CONFIG_API" "Updated tunnel: $full_hash"

	# Calculate and return the new hash
	local new_hash=$(calculate_tunnel_hash "$new_name" "$new_remote_host" "$new_remote_port" "$new_local_port" "$new_direction" "$new_interactive")
	echo "$new_hash"
	return 0
}

# Function to delete a tunnel by hash
# Usage: delete_tunnel_by_hash "hash"
# Returns: 0 on success, 1 on failure with error message
delete_tunnel_by_hash() {
	local target_hash="$1"
	local temp_file=$(mktemp)

	# Resolve hash prefix to full hash
	local full_hash
	full_hash=$(resolve_hash_prefix "$target_hash" 2>&1)
	if [ $? -ne 0 ]; then
		echo "$full_hash"
		return 1
	fi

	# Backup existing config
	backup_config

	# Write YAML header
	echo "tunnels:" >"$temp_file"

	# Process existing tunnels, skip the one to delete
	parse_config "$CONFIG_FILE" | while IFS='	' read -r remote_host remote_port local_port direction name hash interactive; do
		if [ -z "$name" ]; then continue; fi

		if [ "$hash" = "$full_hash" ]; then
			continue # Skip this tunnel (delete it)
		fi

		write_tunnel_yaml "$name" "$remote_host" "$remote_port" "$local_port" "$direction" "$interactive" >>"$temp_file"
	done

	mv "$temp_file" "$CONFIG_FILE"
	log_info "CONFIG_API" "Deleted tunnel: $full_hash"
	return 0
}
