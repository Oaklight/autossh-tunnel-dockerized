#!/bin/sh

# Simple API Server using netcat
# Exposes autossh-cli functionality via HTTP

# Source the logger module
SCRIPT_DIR="$(dirname "$0")"
. "$SCRIPT_DIR/logger.sh"

PORT="${API_PORT:-8080}"
PIPE="/tmp/autossh_api_pipe"

# Function to format HTTP response
response() {
	local status="$1"
	local body=$(cat)
	local length=$(echo -n "$body" | wc -c)

	echo "HTTP/1.1 $status"
	echo "Content-Type: application/json; charset=utf-8"
	echo "Content-Length: $length"
	echo "Access-Control-Allow-Origin: *"
	echo "Access-Control-Allow-Methods: GET, POST, OPTIONS"
	echo "Access-Control-Allow-Headers: Content-Type"
	echo "Connection: close"
	echo ""
	echo -n "$body"
}

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

# Function to handle incoming requests
handle_request() {
	# Read the request line
	read -r line
	line=$(echo "$line" | tr -d '\r')
	method=$(echo "$line" | cut -d ' ' -f 1)
	path=$(echo "$line" | cut -d ' ' -f 2)

	# Consume headers
	while read -r header; do
		header=$(echo "$header" | tr -d '\r')
		[ -z "$header" ] && break
	done

	# Log request
	log_info "API" "$method $path" >&2

	# Handle OPTIONS requests for CORS preflight
	if [ "$method" = "OPTIONS" ]; then
		echo "" | response "204 No Content"
		return
	fi

	case "$path" in
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
			# Extract tunnel hash from path
			tunnel_hash=$(echo "$path" | sed 's|^/logs/||')
			if [ -n "$tunnel_hash" ]; then
				log_file="/tmp/autossh-logs/tunnel-${tunnel_hash}.log"
				if [ -f "$log_file" ]; then
					# Read last 100 lines of log file and properly escape for JSON
					# Remove carriage returns, escape quotes, backslashes, and newlines
					log_content=$(tail -100 "$log_file" | tr -d '\r' | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
					echo "{\"status\": \"success\", \"tunnel_hash\": \"$tunnel_hash\", \"log\": \"$log_content\"}" | response "200 OK"
				else
					echo "{\"error\": \"Log file not found for tunnel: $tunnel_hash\"}" | response "404 Not Found"
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
