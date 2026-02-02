#!/bin/sh

# api_server.sh - Simple API Server using netcat
# Exposes autossh-cli functionality via HTTP
#
# This is the main entry point that handles HTTP routing.
# Business logic is delegated to specialized modules.

# Source all required modules
SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/logger.sh"
. "$SCRIPT_DIR/state_manager.sh"
. "$SCRIPT_DIR/config_parser.sh"
. "$SCRIPT_DIR/json_utils.sh"
. "$SCRIPT_DIR/http_utils.sh"
. "$SCRIPT_DIR/config_api.sh"

# Server configuration
PORT="${API_PORT:-8080}"
PIPE="/tmp/autossh_api_pipe"

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
				write_config_from_json "$request_body"
				if [ $? -eq 0 ]; then
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
				result=$(add_tunnel_from_json "$request_body")
				if [ $? -eq 0 ]; then
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
				result=$(delete_tunnel_by_hash "$tunnel_hash")
				if [ $? -eq 0 ]; then
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
				result=$(update_tunnel_by_hash "$tunnel_hash" "$request_body")
				if [ $? -eq 0 ]; then
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
			result=$(delete_tunnel_by_hash "$tunnel_hash")
			if [ $? -eq 0 ]; then
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

	# Route to appropriate handler
	handle_config_routes "$method" "$path" "$request_body" && return
	handle_tunnel_control_routes "$method" "$path" && return
	handle_status_routes "$method" "$path" && return
	handle_log_routes "$method" "$path" && return

	# No route matched
	json_error "Not Found" | response "404 Not Found"
}

#######################################
# Main Entry Point
#######################################

log_info "API" "Starting API server on port $PORT..."

# Main loop
while true; do
	rm -f "$PIPE"
	mkfifo "$PIPE"

	# Use netcat to listen on the port
	cat "$PIPE" | nc -l -p "$PORT" | handle_request >"$PIPE"

	rm -f "$PIPE"
	# Prevent tight loop in case of errors
	sleep 1
done
