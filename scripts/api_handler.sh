#!/bin/sh

# api_handler.sh - HTTP Request Handler for API Server
# This script is executed by socat for each incoming connection
# It handles a single HTTP request and returns the response
#
# Concurrency Safety:
# - Uses file locking (flock) for write operations to prevent race conditions
# - Read operations are lock-free for better performance
# - Write operations acquire exclusive locks on config and state files

# Source all required modules
SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/logger.sh"
. "$SCRIPT_DIR/state_manager.sh"
. "$SCRIPT_DIR/config_parser.sh"
. "$SCRIPT_DIR/json_utils.sh"
. "$SCRIPT_DIR/http_utils.sh"
. "$SCRIPT_DIR/config_api.sh"

#######################################
# File Locking for Concurrency Safety
#######################################

# Lock file paths
CONFIG_LOCK="/tmp/autossh_config.lock"
STATE_LOCK="/tmp/autossh_state.lock"

# Acquire exclusive lock for config operations
# Usage: acquire_config_lock
# Returns: 0 on success, 1 on failure (timeout)
acquire_config_lock() {
	local lock_fd=200
	local timeout=10

	# Create lock file if it doesn't exist
	touch "$CONFIG_LOCK"

	# Try to acquire lock with timeout
	exec 200>"$CONFIG_LOCK"
	if command -v flock >/dev/null 2>&1; then
		flock -w "$timeout" 200
		return $?
	else
		# Fallback: simple lock file mechanism
		local count=0
		while [ -f "${CONFIG_LOCK}.held" ] && [ $count -lt $((timeout * 10)) ]; do
			sleep 0.1
			count=$((count + 1))
		done
		if [ $count -ge $((timeout * 10)) ]; then
			return 1
		fi
		touch "${CONFIG_LOCK}.held"
		return 0
	fi
}

# Release config lock
release_config_lock() {
	if command -v flock >/dev/null 2>&1; then
		exec 200>&-
	else
		rm -f "${CONFIG_LOCK}.held"
	fi
}

# Acquire exclusive lock for state operations
acquire_state_lock() {
	local lock_fd=201
	local timeout=5

	touch "$STATE_LOCK"
	exec 201>"$STATE_LOCK"
	if command -v flock >/dev/null 2>&1; then
		flock -w "$timeout" 201
		return $?
	else
		local count=0
		while [ -f "${STATE_LOCK}.held" ] && [ $count -lt $((timeout * 10)) ]; do
			sleep 0.1
			count=$((count + 1))
		done
		if [ $count -ge $((timeout * 10)) ]; then
			return 1
		fi
		touch "${STATE_LOCK}.held"
		return 0
	fi
}

# Release state lock
release_state_lock() {
	if command -v flock >/dev/null 2>&1; then
		exec 201>&-
	else
		rm -f "${STATE_LOCK}.held"
	fi
}

#######################################
# Status API Helper Functions
#######################################

# Function to convert list output to JSON
list_to_json() {
	echo "["
	first=true
	# Skip header line
	autossh-cli list | tail -n +2 | while read -r line; do
		if [ -z "$line" ]; then continue; fi

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

		status_to_json_obj "$name" "$status" "$local_port" "$remote_host" "$remote_port" "$hash"
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

		status_to_json_obj "$name" "$status" "$local_port" "$remote_host" "$remote_port" "$hash"
	done
	echo ""
	echo "]"
}

# Function to list log files as JSON
logs_list_to_json() {
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

			printf '  {"hash": "%s", "filename": "%s", "size": "%s", "modified": "%s"}' \
				"$hash" "$filename" "$size" "$mtime"
		done
		echo ""
		echo "]"
	else
		echo "[]"
	fi
}

#######################################
# Route Handlers
#######################################

# Handle Config API routes
# Returns 0 if route was handled, 1 if not
handle_config_routes() {
	local method="$1"
	local path="$2"
	local request_body="$3"

	case "$path" in
	"/config")
		case "$method" in
		"GET")
			config_to_json | response "200 OK"
			;;
		"POST" | "PUT")
			if [ -n "$request_body" ]; then
				# Acquire lock for write operation
				if ! acquire_config_lock; then
					json_error "Server busy, please retry" | response "503 Service Unavailable"
					return 0
				fi
				write_config_from_json "$request_body"
				local result=$?
				release_config_lock
				if [ $result -eq 0 ]; then
					json_success "Configuration saved" | response "200 OK"
				else
					json_error "Failed to save configuration" | response "500 Internal Server Error"
				fi
			else
				json_error "Request body required" | response "400 Bad Request"
			fi
			;;
		*)
			json_error "Method not allowed" | response "405 Method Not Allowed"
			;;
		esac
		return 0
		;;

	"/config/new")
		if [ "$method" = "POST" ]; then
			if [ -n "$request_body" ]; then
				# Acquire lock for write operation
				if ! acquire_config_lock; then
					json_error "Server busy, please retry" | response "503 Service Unavailable"
					return 0
				fi
				result=$(add_tunnel_from_json "$request_body")
				local add_result=$?
				release_config_lock
				if [ $add_result -eq 0 ]; then
					tunnel_json=$(get_tunnel_json_by_hash "$result")
					if [ $? -eq 0 ]; then
						echo "$tunnel_json" | response "201 Created"
					else
						printf '{"status": "success", "hash": "%s"}' "$result" | response "201 Created"
					fi
				else
					json_error "$result" | response "400 Bad Request"
				fi
			else
				json_error "Request body required" | response "400 Bad Request"
			fi
		else
			json_error "Method not allowed" | response "405 Method Not Allowed"
		fi
		return 0
		;;

	/config/*/delete)
		if [ "$method" = "POST" ]; then
			tunnel_hash=$(echo "$path" | sed 's|^/config/||' | sed 's|/delete$||')
			if [ -n "$tunnel_hash" ]; then
				# Acquire lock for write operation
				if ! acquire_config_lock; then
					json_error "Server busy, please retry" | response "503 Service Unavailable"
					return 0
				fi
				result=$(delete_tunnel_by_hash "$tunnel_hash")
				local delete_result=$?
				release_config_lock
				if [ $delete_result -eq 0 ]; then
					json_success "Tunnel deleted" | response "200 OK"
				else
					json_error "$result" | response "404 Not Found"
				fi
			else
				json_error "Tunnel hash required" | response "400 Bad Request"
			fi
		else
			json_error "Method not allowed" | response "405 Method Not Allowed"
		fi
		return 0
		;;

	/config/*)
		tunnel_hash=$(echo "$path" | sed 's|^/config/||')

		case "$method" in
		"GET")
			result=$(get_tunnel_json_by_hash "$tunnel_hash")
			if [ $? -eq 0 ]; then
				echo "$result" | response "200 OK"
			else
				json_error "$result" | response "404 Not Found"
			fi
			;;
		"POST" | "PUT")
			if [ -n "$request_body" ]; then
				# Acquire lock for write operation
				if ! acquire_config_lock; then
					json_error "Server busy, please retry" | response "503 Service Unavailable"
					return 0
				fi
				result=$(update_tunnel_by_hash "$tunnel_hash" "$request_body")
				local update_result=$?
				release_config_lock
				if [ $update_result -eq 0 ]; then
					tunnel_json=$(get_tunnel_json_by_hash "$result")
					if [ $? -eq 0 ]; then
						echo "$tunnel_json" | response "200 OK"
					else
						printf '{"status": "success", "hash": "%s"}' "$result" | response "200 OK"
					fi
				else
					json_error "$result" | response "404 Not Found"
				fi
			else
				json_error "Request body required" | response "400 Bad Request"
			fi
			;;
		"DELETE")
			# Acquire lock for write operation
			if ! acquire_config_lock; then
				json_error "Server busy, please retry" | response "503 Service Unavailable"
				return 0
			fi
			result=$(delete_tunnel_by_hash "$tunnel_hash")
			local delete_result=$?
			release_config_lock
			if [ $delete_result -eq 0 ]; then
				json_success "Tunnel deleted" | response "200 OK"
			else
				json_error "$result" | response "404 Not Found"
			fi
			;;
		*)
			json_error "Method not allowed" | response "405 Method Not Allowed"
			;;
		esac
		return 0
		;;
	esac

	return 1
}

# Handle Tunnel Control routes (start/stop)
handle_tunnel_control_routes() {
	local method="$1"
	local path="$2"

	case "$path" in
	"/start")
		if [ "$method" = "POST" ]; then
			output=$(autossh-cli start 2>&1)
			json_output=$(json_escape "$output")
			printf '{"status": "success", "output": "%s"}' "$json_output" | response "200 OK"
		else
			json_error "Method not allowed" | response "405 Method Not Allowed"
		fi
		return 0
		;;

	"/stop")
		if [ "$method" = "POST" ]; then
			output=$(autossh-cli stop 2>&1)
			json_output=$(json_escape "$output")
			printf '{"status": "success", "output": "%s"}' "$json_output" | response "200 OK"
		else
			json_error "Method not allowed" | response "405 Method Not Allowed"
		fi
		return 0
		;;

	/start/*)
		if [ "$method" = "POST" ]; then
			tunnel_hash=$(echo "$path" | sed 's|^/start/||')
			if [ -n "$tunnel_hash" ]; then
				output=$(autossh-cli start-tunnel "$tunnel_hash" 2>&1)
				json_output=$(json_escape "$output")
				printf '{"status": "success", "tunnel_hash": "%s", "output": "%s"}' "$tunnel_hash" "$json_output" | response "200 OK"
			else
				json_error "Tunnel hash required" | response "400 Bad Request"
			fi
		else
			json_error "Method not allowed" | response "405 Method Not Allowed"
		fi
		return 0
		;;

	/stop/*)
		if [ "$method" = "POST" ]; then
			tunnel_hash=$(echo "$path" | sed 's|^/stop/||')
			if [ -n "$tunnel_hash" ]; then
				output=$(autossh-cli stop-tunnel "$tunnel_hash" 2>&1)
				json_output=$(json_escape "$output")
				printf '{"status": "success", "tunnel_hash": "%s", "output": "%s"}' "$tunnel_hash" "$json_output" | response "200 OK"
			else
				json_error "Tunnel hash required" | response "400 Bad Request"
			fi
		else
			json_error "Method not allowed" | response "405 Method Not Allowed"
		fi
		return 0
		;;
	esac

	return 1
}

# Handle Status/List routes
handle_status_routes() {
	local method="$1"
	local path="$2"

	case "$path" in
	"/list")
		if [ "$method" = "GET" ]; then
			list_to_json | response "200 OK"
		else
			json_error "Method not allowed" | response "405 Method Not Allowed"
		fi
		return 0
		;;

	"/status")
		if [ "$method" = "GET" ]; then
			status_to_json | response "200 OK"
		else
			json_error "Method not allowed" | response "405 Method Not Allowed"
		fi
		return 0
		;;
	esac

	return 1
}

# Handle Log routes
handle_log_routes() {
	local method="$1"
	local path="$2"

	case "$path" in
	"/logs")
		if [ "$method" = "GET" ]; then
			logs_list_to_json | response "200 OK"
		else
			json_error "Method not allowed" | response "405 Method Not Allowed"
		fi
		return 0
		;;

	/logs/*)
		if [ "$method" = "GET" ]; then
			tunnel_hash_input=$(echo "$path" | sed 's|^/logs/||')
			if [ -n "$tunnel_hash_input" ]; then
				tunnel_hash=$(resolve_hash_prefix "$tunnel_hash_input" 2>&1)
				if [ $? -ne 0 ]; then
					json_error "$tunnel_hash" | response "400 Bad Request"
				else
					log_file="/tmp/autossh-logs/tunnel-${tunnel_hash}.log"
					if [ -f "$log_file" ]; then
						log_content=$(tail -100 "$log_file" | tr -d '\r' | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
						printf '{"status": "success", "tunnel_hash": "%s", "log": "%s"}' "$tunnel_hash" "$log_content" | response "200 OK"
					else
						json_error "Log file not found for tunnel: $tunnel_hash" | response "404 Not Found"
					fi
				fi
			else
				json_error "Tunnel hash required" | response "400 Bad Request"
			fi
		else
			json_error "Method not allowed" | response "405 Method Not Allowed"
		fi
		return 0
		;;
	esac

	return 1
}

#######################################
# Main Request Handler
#######################################

# Read the request line
read -r line
line=$(echo "$line" | tr -d '\r')
method=$(echo "$line" | cut -d ' ' -f 1)
path=$(echo "$line" | cut -d ' ' -f 2)

# Variables to store headers
auth_header=""
content_length=0

# Consume headers and extract Authorization and Content-Length
while read -r header; do
	header=$(echo "$header" | tr -d '\r')
	[ -z "$header" ] && break

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
request_body=""
if [ "$content_length" -gt 0 ] 2>/dev/null; then
	request_body=$(dd bs=1 count="$content_length" 2>/dev/null)
fi

# Log request
log_info "API" "$method $path" >&2

# Handle OPTIONS requests for CORS preflight (no auth required)
if [ "$method" = "OPTIONS" ]; then
	echo "" | response "204 No Content"
	exit 0
fi

# Verify authentication for all other requests
if ! verify_auth "$auth_header"; then
	log_info "API" "Unauthorized request to $path" >&2
	response_unauthorized
	exit 0
fi

# Route to appropriate handler
handle_config_routes "$method" "$path" "$request_body" && exit 0
handle_tunnel_control_routes "$method" "$path" && exit 0
handle_status_routes "$method" "$path" && exit 0
handle_log_routes "$method" "$path" && exit 0

# No route matched
json_error "Not Found" | response "404 Not Found"
