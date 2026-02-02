#!/bin/sh

# Simple API Server using netcat
# Exposes autossh-cli functionality via HTTP

# Source the logger module
SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/logger.sh"
. "$SCRIPT_DIR/state_manager.sh"
. "$SCRIPT_DIR/config_parser.sh"

PORT="${API_PORT:-8080}"
PIPE="/tmp/autossh_api_pipe"
CONFIG_FILE="${CONFIG_FILE:-/home/myuser/config/config.yaml}"
CONFIG_BACKUP_DIR="${CONFIG_BACKUP_DIR:-/home/myuser/config/backups}"

# Optional API Key(s) for Bearer token authentication
# If API_KEY is set, all requests must include "Authorization: Bearer <API_KEY>" header
# Multiple keys can be specified, separated by commas (e.g., "key1,key2,key3")
API_KEY="${API_KEY:-}"

# Function to format HTTP response
response() {
	local status="$1"
	local body=$(cat)
	local length=$(echo -n "$body" | wc -c)

	echo "HTTP/1.1 $status"
	echo "Content-Type: application/json; charset=utf-8"
	echo "Content-Length: $length"
	echo "Access-Control-Allow-Origin: *"
	echo "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS"
	echo "Access-Control-Allow-Headers: Content-Type, Authorization"
	echo "Connection: close"
	echo ""
	echo -n "$body"
}

# Function to send 401 Unauthorized response
response_unauthorized() {
	local body='{"error": "Unauthorized", "message": "Valid Bearer token required"}'
	local length=$(echo -n "$body" | wc -c)

	echo "HTTP/1.1 401 Unauthorized"
	echo "Content-Type: application/json; charset=utf-8"
	echo "Content-Length: $length"
	echo "Access-Control-Allow-Origin: *"
	echo "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS"
	echo "Access-Control-Allow-Headers: Content-Type, Authorization"
	echo "WWW-Authenticate: Bearer"
	echo "Connection: close"
	echo ""
	echo -n "$body"
}

# Function to verify Bearer token
# Returns 0 if valid or no API_KEY is set, 1 if invalid
# Supports multiple API keys separated by commas
verify_auth() {
	local auth_header="$1"

	# If no API_KEY is configured, allow all requests
	if [ -z "$API_KEY" ]; then
		return 0
	fi

	# Check if Authorization header is present and valid
	if [ -z "$auth_header" ]; then
		return 1
	fi

	# Extract token from "Bearer <token>" format
	local token=$(echo "$auth_header" | sed -n 's/^Bearer //p')

	if [ -z "$token" ]; then
		return 1
	fi

	# Check against each API key (comma-separated)
	local IFS=','
	for key in $API_KEY; do
		# Trim whitespace from key
		key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
		if [ "$token" = "$key" ]; then
			return 0
		fi
	done

	return 1
}

#######################################
# Config API Helper Functions
#######################################

# Function to read config file and convert to JSON (all tunnels)
config_to_json() {
	if [ ! -f "$CONFIG_FILE" ]; then
		echo '{"tunnels": []}'
		return
	fi

	local result='{"tunnels": ['
	local first=true
	local tunnels=""

	# Read all tunnels into a variable first to avoid subshell issues
	tunnels=$(parse_config "$CONFIG_FILE")

	echo "$tunnels" | while IFS='	' read -r remote_host remote_port local_port direction name hash interactive; do
		if [ -z "$name" ]; then continue; fi

		if [ "$first" = "true" ]; then
			first=false
		else
			printf ","
		fi

		# Convert interactive to boolean string
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

# Function to backup config file
backup_config() {
	mkdir -p "$CONFIG_BACKUP_DIR"
	if [ -f "$CONFIG_FILE" ]; then
		local backup_file="$CONFIG_BACKUP_DIR/config_$(date +%Y%m%d%H%M%S).yaml"
		cp "$CONFIG_FILE" "$backup_file"
		log_info "API" "Backed up config to $backup_file"
		echo "$backup_file"
	fi
}

# Function to extract JSON field value
# Usage: json_get_field "$json" "field_name"
json_get_field() {
	local json="$1"
	local field="$2"
	echo "$json" | sed -n 's/.*"'"$field"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
}

# Function to extract JSON boolean field value
json_get_bool() {
	local json="$1"
	local field="$2"
	echo "$json" | sed -n 's/.*"'"$field"'"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' | head -1
}

# Function to write a single tunnel to YAML format
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

# Function to write full config from JSON
# Input: JSON with {"tunnels": [...]} format
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
	log_info "API" "Config file updated: $CONFIG_FILE"
	return 0
}

# Function to add a new tunnel from JSON
# Input: JSON with single tunnel object
add_tunnel_from_json() {
	local json_input="$1"
	local temp_file=$(mktemp)

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

	log_info "API" "Added new tunnel: $name ($new_hash)"
	echo "$new_hash"
	return 0
}

# Function to update a single tunnel by hash
# Input: target_hash and JSON with tunnel data
update_tunnel_by_hash() {
	local target_hash="$1"
	local json_input="$2"
	local temp_file=$(mktemp)
	local found=false

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
			found=true
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
	log_info "API" "Updated tunnel: $full_hash"

	# Calculate and return the new hash
	local new_hash=$(calculate_tunnel_hash "$new_name" "$new_remote_host" "$new_remote_port" "$new_local_port" "$new_direction" "$new_interactive")
	echo "$new_hash"
	return 0
}

# Function to delete a tunnel by hash
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

	# Check if tunnel exists
	local tunnel_exists=false
	parse_config "$CONFIG_FILE" | while IFS='	' read -r remote_host remote_port local_port direction name hash interactive; do
		if [ "$hash" = "$full_hash" ]; then
			tunnel_exists=true
			break
		fi
	done

	# Backup existing config
	backup_config

	# Write YAML header
	echo "tunnels:" >"$temp_file"

	# Process existing tunnels, skip the one to delete
	local deleted=false
	parse_config "$CONFIG_FILE" | while IFS='	' read -r remote_host remote_port local_port direction name hash interactive; do
		if [ -z "$name" ]; then continue; fi

		if [ "$hash" = "$full_hash" ]; then
			deleted=true
			continue # Skip this tunnel (delete it)
		fi

		write_tunnel_yaml "$name" "$remote_host" "$remote_port" "$local_port" "$direction" "$interactive" >>"$temp_file"
	done

	mv "$temp_file" "$CONFIG_FILE"
	log_info "API" "Deleted tunnel: $full_hash"
	return 0
}

#######################################
# Existing API Helper Functions
#######################################

# Function to convert list output to JSON
list_to_json() {
	echo "["
	first=true
	# Skip header line
	autossh-cli list | tail -n +2 | while read -r line; do
		if [ -z "$line" ]; then continue; fi

		# Parse line: name status local -> remote:port (hash)
		# Example: my-tunnel NORMAL 8080 -> example.com:80 (abc123hash)

		name=$(echo "$line" | awk '{print $1}')
		status=$(echo "$line" | awk '{print $2}')
		local_port=$(echo "$line" | awk '{print $3}')
		remote_host=$(echo "$line" | awk '{print $5}' | cut -d: -f1)
		remote_port=$(echo "$line" | awk '{print $5}' | cut -d: -f2)
		hash=$(echo "$line" | awk '{print $6}' | tr -d '()')

		if [ "$first" = "true" ]; then
			first=false
		else
			echo ","
		fi

		printf '  {
    "name": "%s",
    "status": "%s",
    "local_port": "%s",
    "remote_host": "%s",
    "remote_port": "%s",
    "hash": "%s"
  }' "$name" "$status" "$local_port" "$remote_host" "$remote_port" "$hash"
	done
	echo ""
	echo "]"
}

# Function to convert status output to JSON
status_to_json() {
	echo "["
	first=true
	# Skip header line and "Managed tunnels:" line if present
	autossh-cli status | grep -v "Tunnel Status" | grep -v "Managed tunnels:" | while read -r line; do
		if [ -z "$line" ]; then continue; fi
		if echo "$line" | grep -q "No managed tunnels found"; then continue; fi

		# Parse line: name status local -> remote:port (hash)

		name=$(echo "$line" | awk '{print $1}')
		status=$(echo "$line" | awk '{print $2}')
		local_port=$(echo "$line" | awk '{print $3}')
		remote_host=$(echo "$line" | awk '{print $5}' | cut -d: -f1)
		remote_port=$(echo "$line" | awk '{print $5}' | cut -d: -f2)
		hash=$(echo "$line" | awk '{print $6}' | tr -d '()')

		if [ "$first" = "true" ]; then
			first=false
		else
			echo ","
		fi

		printf '  {
    "name": "%s",
    "status": "%s",
    "local_port": "%s",
    "remote_host": "%s",
    "remote_port": "%s",
    "hash": "%s"
  }' "$name" "$status" "$local_port" "$remote_host" "$remote_port" "$hash"
	done
	echo ""
	echo "]"
}

#######################################
# Request Handler
#######################################

# Function to handle incoming requests
handle_request() {
	# Read the request line
	read -r line
	line=$(echo "$line" | tr -d '\r')
	method=$(echo "$line" | cut -d ' ' -f 1)
	path=$(echo "$line" | cut -d ' ' -f 2)

	# Variables to store headers
	local auth_header=""
	local content_length=0

	# Consume headers and extract Authorization and Content-Length
	while read -r header; do
		header=$(echo "$header" | tr -d '\r')
		[ -z "$header" ] && break

		# Extract headers (case-insensitive)
		case "$header" in
		Authorization:* | authorization:*)
			auth_header=$(echo "$header" | sed 's/^[Aa]uthorization:[[:space:]]*//')
			;;
		Content-Length:* | content-length:*)
			content_length=$(echo "$header" | sed 's/^[Cc]ontent-[Ll]ength:[[:space:]]*//')
			;;
		esac
	done

	# Read request body if Content-Length > 0
	local request_body=""
	if [ "$content_length" -gt 0 ] 2>/dev/null; then
		request_body=$(dd bs=1 count="$content_length" 2>/dev/null)
	fi

	# Log request
	log_info "API" "$method $path" >&2

	# Handle OPTIONS requests for CORS preflight (no auth required)
	if [ "$method" = "OPTIONS" ]; then
		echo "" | response "204 No Content"
		return
	fi

	# Verify authentication for all other requests
	if ! verify_auth "$auth_header"; then
		log_info "API" "Unauthorized request to $path" >&2
		response_unauthorized
		return
	fi

	#######################################
	# Config API Routes
	#######################################

	# GET /config - Get all tunnel configurations
	# GET /config/{hash} - Get single tunnel configuration
	# POST /config - Replace all configurations (full replacement)
	# PUT /config - Replace all configurations (RESTful alias)
	# POST /config/new - Add new tunnel
	# POST /config/{hash} - Update single tunnel
	# PUT /config/{hash} - Update single tunnel (RESTful alias)
	# DELETE /config/{hash} - Delete tunnel (RESTful)
	# POST /config/{hash}/delete - Delete tunnel (POST alias)

	case "$path" in
	"/config")
		case "$method" in
		"GET")
			# Get all tunnel configurations
			config_to_json | response "200 OK"
			;;
		"POST" | "PUT")
			# Replace all configurations
			if [ -n "$request_body" ]; then
				write_config_from_json "$request_body"
				if [ $? -eq 0 ]; then
					echo '{"status": "success", "message": "Configuration saved"}' | response "200 OK"
				else
					echo '{"error": "Failed to save configuration"}' | response "500 Internal Server Error"
				fi
			else
				echo '{"error": "Request body required"}' | response "400 Bad Request"
			fi
			;;
		*)
			echo '{"error": "Method not allowed"}' | response "405 Method Not Allowed"
			;;
		esac
		;;

	"/config/new")
		if [ "$method" = "POST" ]; then
			# Add new tunnel
			if [ -n "$request_body" ]; then
				result=$(add_tunnel_from_json "$request_body")
				if [ $? -eq 0 ]; then
					# Get the newly created tunnel
					tunnel_json=$(get_tunnel_json_by_hash "$result")
					if [ $? -eq 0 ]; then
						echo "$tunnel_json" | response "201 Created"
					else
						echo "{\"status\": \"success\", \"hash\": \"$result\"}" | response "201 Created"
					fi
				else
					echo "{\"error\": \"$result\"}" | response "400 Bad Request"
				fi
			else
				echo '{"error": "Request body required"}' | response "400 Bad Request"
			fi
		else
			echo '{"error": "Method not allowed"}' | response "405 Method Not Allowed"
		fi
		;;

	/config/*/delete)
		# POST /config/{hash}/delete - Delete tunnel (POST alias)
		if [ "$method" = "POST" ]; then
			tunnel_hash=$(echo "$path" | sed 's|^/config/||' | sed 's|/delete$||')
			if [ -n "$tunnel_hash" ]; then
				result=$(delete_tunnel_by_hash "$tunnel_hash")
				if [ $? -eq 0 ]; then
					echo '{"status": "success", "message": "Tunnel deleted"}' | response "200 OK"
				else
					json_error=$(echo "$result" | sed 's/"/\\"/g')
					echo "{\"error\": \"$json_error\"}" | response "404 Not Found"
				fi
			else
				echo '{"error": "Tunnel hash required"}' | response "400 Bad Request"
			fi
		else
			echo '{"error": "Method not allowed"}' | response "405 Method Not Allowed"
		fi
		;;

	/config/*)
		# Extract hash from path
		tunnel_hash=$(echo "$path" | sed 's|^/config/||')

		case "$method" in
		"GET")
			# Get single tunnel configuration
			result=$(get_tunnel_json_by_hash "$tunnel_hash")
			if [ $? -eq 0 ]; then
				echo "$result" | response "200 OK"
			else
				json_error=$(echo "$result" | sed 's/"/\\"/g')
				echo "{\"error\": \"$json_error\"}" | response "404 Not Found"
			fi
			;;
		"POST" | "PUT")
			# Update single tunnel
			if [ -n "$request_body" ]; then
				result=$(update_tunnel_by_hash "$tunnel_hash" "$request_body")
				if [ $? -eq 0 ]; then
					# Get the updated tunnel
					tunnel_json=$(get_tunnel_json_by_hash "$result")
					if [ $? -eq 0 ]; then
						echo "$tunnel_json" | response "200 OK"
					else
						echo "{\"status\": \"success\", \"hash\": \"$result\"}" | response "200 OK"
					fi
				else
					json_error=$(echo "$result" | sed 's/"/\\"/g')
					echo "{\"error\": \"$json_error\"}" | response "404 Not Found"
				fi
			else
				echo '{"error": "Request body required"}' | response "400 Bad Request"
			fi
			;;
		"DELETE")
			# Delete tunnel (RESTful)
			result=$(delete_tunnel_by_hash "$tunnel_hash")
			if [ $? -eq 0 ]; then
				echo '{"status": "success", "message": "Tunnel deleted"}' | response "200 OK"
			else
				json_error=$(echo "$result" | sed 's/"/\\"/g')
				echo "{\"error\": \"$json_error\"}" | response "404 Not Found"
			fi
			;;
		*)
			echo '{"error": "Method not allowed"}' | response "405 Method Not Allowed"
			;;
		esac
		;;

	#######################################
	# Existing API Routes
	#######################################

	"/list")
		if [ "$method" = "GET" ]; then
			list_to_json | response "200 OK"
		else
			echo '{"error": "Method not allowed"}' | response "405 Method Not Allowed"
		fi
		;;
	"/status")
		if [ "$method" = "GET" ]; then
			status_to_json | response "200 OK"
		else
			echo '{"error": "Method not allowed"}' | response "405 Method Not Allowed"
		fi
		;;
	"/start")
		if [ "$method" = "POST" ]; then
			output=$(autossh-cli start 2>&1)
			# Escape quotes and newlines for JSON
			json_output=$(echo "$output" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
			echo "{\"status\": \"success\", \"output\": \"$json_output\"}" | response "200 OK"
		else
			echo '{"error": "Method not allowed"}' | response "405 Method Not Allowed"
		fi
		;;
	"/stop")
		if [ "$method" = "POST" ]; then
			output=$(autossh-cli stop 2>&1)
			# Escape quotes and newlines for JSON
			json_output=$(echo "$output" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
			echo "{\"status\": \"success\", \"output\": \"$json_output\"}" | response "200 OK"
		else
			echo '{"error": "Method not allowed"}' | response "405 Method Not Allowed"
		fi
		;;
	/start/*)
		if [ "$method" = "POST" ]; then
			# Extract tunnel hash from path
			tunnel_hash=$(echo "$path" | sed 's|^/start/||')
			if [ -n "$tunnel_hash" ]; then
				output=$(autossh-cli start-tunnel "$tunnel_hash" 2>&1)
				# Escape quotes and newlines for JSON
				json_output=$(echo "$output" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
				echo "{\"status\": \"success\", \"tunnel_hash\": \"$tunnel_hash\", \"output\": \"$json_output\"}" | response "200 OK"
			else
				echo '{"error": "Tunnel hash required"}' | response "400 Bad Request"
			fi
		else
			echo '{"error": "Method not allowed"}' | response "405 Method Not Allowed"
		fi
		;;
	/stop/*)
		if [ "$method" = "POST" ]; then
			# Extract tunnel hash from path
			tunnel_hash=$(echo "$path" | sed 's|^/stop/||')
			if [ -n "$tunnel_hash" ]; then
				output=$(autossh-cli stop-tunnel "$tunnel_hash" 2>&1)
				# Escape quotes and newlines for JSON
				json_output=$(echo "$output" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
				echo "{\"status\": \"success\", \"tunnel_hash\": \"$tunnel_hash\", \"output\": \"$json_output\"}" | response "200 OK"
			else
				echo '{"error": "Tunnel hash required"}' | response "400 Bad Request"
			fi
		else
			echo '{"error": "Method not allowed"}' | response "405 Method Not Allowed"
		fi
		;;
	/logs/*)
		if [ "$method" = "GET" ]; then
			# Extract tunnel hash (or prefix) from path
			tunnel_hash_input=$(echo "$path" | sed 's|^/logs/||')
			if [ -n "$tunnel_hash_input" ]; then
				# Resolve hash prefix to full hash
				tunnel_hash=$(resolve_hash_prefix "$tunnel_hash_input" 2>&1)
				if [ $? -ne 0 ]; then
					# Error resolving hash prefix
					json_error=$(echo "$tunnel_hash" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
					echo "{\"error\": \"$json_error\"}" | response "400 Bad Request"
				else
					log_file="/tmp/autossh-logs/tunnel-${tunnel_hash}.log"
					if [ -f "$log_file" ]; then
						# Read last 100 lines of log file and properly escape for JSON
						# Remove carriage returns, escape quotes, backslashes, and newlines
						log_content=$(tail -100 "$log_file" | tr -d '\r' | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
						echo "{\"status\": \"success\", \"tunnel_hash\": \"$tunnel_hash\", \"log\": \"$log_content\"}" | response "200 OK"
					else
						echo "{\"error\": \"Log file not found for tunnel: $tunnel_hash\"}" | response "404 Not Found"
					fi
				fi
			else
				echo '{"error": "Tunnel hash required"}' | response "400 Bad Request"
			fi
		else
			echo '{"error": "Method not allowed"}' | response "405 Method Not Allowed"
		fi
		;;
	"/logs")
		if [ "$method" = "GET" ]; then
			# List all available log files
			log_dir="/tmp/autossh-logs"
			if [ -d "$log_dir" ] && ls "$log_dir"/tunnel-*.log >/dev/null 2>&1; then
				echo "["
				first=true
				for log_file in "$log_dir"/tunnel-*.log; do
					filename=$(basename "$log_file")
					hash=$(echo "$filename" | sed 's/tunnel-//;s/.log$//')
					size=$(du -h "$log_file" | cut -f1)
					mtime=$(stat -c %y "$log_file" 2>/dev/null || stat -f %Sm "$log_file" 2>/dev/null || echo "unknown")

					if [ "$first" = "true" ]; then
						first=false
					else
						echo ","
					fi

					printf '  {
	   "hash": "%s",
	   "filename": "%s",
	   "size": "%s",
	   "modified": "%s"
	 }' "$hash" "$filename" "$size" "$mtime"
				done
				echo ""
				echo "]"
			else
				echo "[]"
			fi | response "200 OK"
		else
			echo '{"error": "Method not allowed"}' | response "405 Method Not Allowed"
		fi
		;;
	*)
		echo '{"error": "Not Found"}' | response "404 Not Found"
		;;
	esac
}

log_info "API" "Starting API server on port $PORT..."

# Main loop
while true; do
	rm -f "$PIPE"
	mkfifo "$PIPE"

	# Use netcat to listen on the port
	# Input to nc comes from the pipe (response)
	# Output from nc goes to handle_request
	# handle_request writes to the pipe
	cat "$PIPE" | nc -l -p "$PORT" | handle_request >"$PIPE"

	rm -f "$PIPE"
	# Prevent tight loop in case of errors
	sleep 1
done
