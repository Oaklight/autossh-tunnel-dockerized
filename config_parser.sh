#!/bin/sh

# config_parser.sh - YAML configuration parser for autossh tunnels
# This module provides functions to parse YAML configuration files using pure shell

# Function to calculate MD5 hash for tunnel configuration
calculate_tunnel_hash() {
	local name="$1"
	local remote_host="$2"
	local remote_port="$3"
	local local_port="$4"
	local direction="$5"
	local interactive="$6"

	# Create a consistent string for hashing
	local hash_input="${name}|${remote_host}|${remote_port}|${local_port}|${direction}|${interactive}"

	# Calculate MD5 hash
	echo "$hash_input" | md5sum | cut -d' ' -f1
}

# Function to parse YAML and extract tunnel configurations using pure shell
parse_config() {
	local config_file=$1
	local in_tunnels=false
	local in_tunnel=false
	local name=""
	local remote_host=""
	local remote_port=""
	local local_port=""
	local direction=""
	local interactive=""

	while IFS= read -r line; do
		# Remove leading/trailing whitespace
		line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

		# Skip empty lines and comments
		if [ -z "$line" ] || [ "${line#\#}" != "$line" ]; then
			continue
		fi

		# Check if we're in the tunnels section
		if [ "$line" = "tunnels:" ]; then
			in_tunnels=true
			continue
		fi

		# If we're in tunnels section
		if [ "$in_tunnels" = true ]; then
			# Check for new tunnel entry (starts with -)
			if [ "${line#- }" != "$line" ] || [ "${line#-}" != "$line" ]; then
				# Output previous tunnel if complete
				if [ -n "$remote_host" ] && [ -n "$remote_port" ] && [ -n "$local_port" ]; then
					local tunnel_hash=$(calculate_tunnel_hash "${name:-unnamed}" "$remote_host" "$remote_port" "$local_port" "${direction:-remote_to_local}" "${interactive:-false}")
					printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$remote_host" "$remote_port" "$local_port" "${direction:-remote_to_local}" "${name:-unnamed}" "$tunnel_hash" "${interactive:-false}"
				fi
				# Reset for new tunnel
				name=""
				remote_host=""
				remote_port=""
				local_port=""
				direction=""
				interactive=""
				in_tunnel=true

				# Check if this line also contains a field (like "- name: value")
				if [ "${line#- *:}" != "$line" ]; then
					# Extract the field from the line
					field_line=$(echo "$line" | sed 's/^- *//')
					case "$field_line" in
					name:*)
						name=$(echo "$field_line" | sed 's/name:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/')
						;;
					esac
				fi
				continue
			fi

			# Parse tunnel properties
			if [ "$in_tunnel" = true ]; then
				case "$line" in
				name:*)
					name=$(echo "$line" | sed 's/name:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/')
					;;
				remote_host:*)
					remote_host=$(echo "$line" | sed 's/remote_host:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/')
					;;
				remote_port:*)
					remote_port=$(echo "$line" | sed 's/remote_port:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/')
					;;
				local_port:*)
					local_port=$(echo "$line" | sed 's/local_port:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/')
					;;
				direction:*)
					direction=$(echo "$line" | sed 's/direction:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/')
					;;
				interactive:*)
					interactive=$(echo "$line" | sed 's/interactive:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/')
					;;
				esac
			fi
		fi
	done <"$config_file"

	# Output the last tunnel if complete
	if [ -n "$remote_host" ] && [ -n "$remote_port" ] && [ -n "$local_port" ]; then
		local tunnel_hash=$(calculate_tunnel_hash "${name:-unnamed}" "$remote_host" "$remote_port" "$local_port" "${direction:-remote_to_local}" "${interactive:-false}")
		printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$remote_host" "$remote_port" "$local_port" "${direction:-remote_to_local}" "${name:-unnamed}" "$tunnel_hash" "${interactive:-false}"
	fi
}

# Function to validate configuration file
validate_config() {
	local config_file=$1

	if [ ! -f "$config_file" ]; then
		echo "Error: Config file not found: $config_file" >&2
		return 1
	fi

	# Check if file contains tunnels section
	if ! grep -q "^tunnels:" "$config_file"; then
		echo "Error: No 'tunnels:' section found in config file" >&2
		return 1
	fi

	return 0
}

# Function to count tunnels in configuration
count_tunnels() {
	local config_file=$1
	parse_config "$config_file" | wc -l
}

# Function to list tunnel names
list_tunnel_names() {
	local config_file=$1
	parse_config "$config_file" | cut -f5
}

# Function to get tunnel hashes
get_tunnel_hashes() {
	local config_file=$1
	parse_config "$config_file" | cut -f6
}

# Function to get tunnel by hash
get_tunnel_by_hash() {
	local config_file=$1
	local target_hash=$2
	parse_config "$config_file" | while IFS=$'\t' read -r remote_host remote_port local_port direction name hash; do
		if [ "$hash" = "$target_hash" ]; then
			printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$remote_host" "$remote_port" "$local_port" "$direction" "$name" "$hash"
			break
		fi
	done
}

# Function to compare two config files and find differences
compare_configs() {
	local old_config=$1
	local new_config=$2
	local temp_old=$(mktemp)
	local temp_new=$(mktemp)

	# Get hashes from both configs
	get_tunnel_hashes "$old_config" | sort >"$temp_old"
	get_tunnel_hashes "$new_config" | sort >"$temp_new"

	echo "=== Removed tunnels ==="
	comm -23 "$temp_old" "$temp_new"

	echo "=== Added tunnels ==="
	comm -13 "$temp_old" "$temp_new"

	echo "=== Unchanged tunnels ==="
	comm -12 "$temp_old" "$temp_new"

	# Cleanup
	rm -f "$temp_old" "$temp_new"
}
