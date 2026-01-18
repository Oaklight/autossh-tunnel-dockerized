#!/bin/sh

# config_parser.sh - YAML configuration parser for autossh tunnels
# This module provides functions to parse YAML configuration files using pure shell

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
					# Skip interactive tunnels for now (they need special handling)
					if [ "$interactive" != "true" ]; then
						printf "%s\t%s\t%s\t%s\t%s\n" "$remote_host" "$remote_port" "$local_port" "${direction:-remote_to_local}" "${name:-unnamed}"
					else
						echo "Skipping interactive tunnel: ${name:-unnamed}" >&2
					fi
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
		if [ "$interactive" != "true" ]; then
			printf "%s\t%s\t%s\t%s\t%s\n" "$remote_host" "$remote_port" "$local_port" "${direction:-remote_to_local}" "${name:-unnamed}"
		else
			echo "Skipping interactive tunnel: ${name:-unnamed}" >&2
		fi
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
