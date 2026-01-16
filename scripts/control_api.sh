#!/bin/sh

# Simple HTTP API server for controlling autossh tunnels
# Listens on port 5001 for control commands

# Source shared tunnel utilities
. /scripts/tunnel_utils.sh

API_PORT=${API_PORT:-5002}
CONFIG_FILE="/etc/autossh/config/config.yaml"
STATUS_FILE="/tmp/tunnel_status.json"
FIFO_DIR="/tmp/api_fifos"

# Create FIFO directory
mkdir -p "$FIFO_DIR"

# Function to find tunnel by log ID
find_tunnel_by_log_id() {
	local target_log_id=$1

	yq e '.tunnels[] | [.remote_host, .remote_port, .local_port, .direction] | @tsv' "$CONFIG_FILE" |
		while IFS=$'\t' read -r remote_host remote_port local_port direction; do
			local log_id=$(generate_log_id "$remote_host" "$remote_port" "$local_port" "$direction")
			if [ "$log_id" = "$target_log_id" ]; then
				echo "$remote_host|$remote_port|$local_port|$direction"
				return 0
			fi
		done
}

# Function to restart a specific tunnel
restart_tunnel() {
	local log_id=$1

	# Find tunnel configuration
	local tunnel_info=$(find_tunnel_by_log_id "$log_id")

	if [ -z "$tunnel_info" ]; then
		echo '{"success":false,"error":"Tunnel not found"}'
		return 1
	fi

	# Parse tunnel info
	local remote_host=$(echo "$tunnel_info" | cut -d'|' -f1)
	local remote_port=$(echo "$tunnel_info" | cut -d'|' -f2)
	local local_port=$(echo "$tunnel_info" | cut -d'|' -f3)
	local direction=$(echo "$tunnel_info" | cut -d'|' -f4)

	# Use shared cleanup function from tunnel_utils.sh
	cleanup_tunnel_processes "$log_id" "$local_port" "$remote_host"

	# Create fresh log file with header (overwrite old content)
	log_id=$(create_fresh_log "$remote_host" "$remote_port" "$local_port" "$direction" "Restarted")

	# Restart the tunnel using unified start script as myuser
	su myuser -c "/scripts/start_single_tunnel.sh '$remote_host' '$remote_port' '$local_port' '$direction'" >/dev/null 2>&1

	echo "{\"success\":true,\"message\":\"Tunnel restarted successfully\",\"log_id\":\"$log_id\"}"
	return 0
}

# Function to handle HTTP request
handle_request() {
	local method=""
	local path=""
	local line

	# Read request line
	read -r line
	method=$(echo "$line" | cut -d' ' -f1 | tr -d '\r')
	path=$(echo "$line" | cut -d' ' -f2 | tr -d '\r')

	# Read and discard headers
	while read -r line; do
		line=$(echo "$line" | tr -d '\r')
		[ -z "$line" ] && break
	done

	# Route the request
	if [ "$method" = "POST" ] && echo "$path" | grep -q "^/restart/"; then
		local log_id=$(echo "$path" | sed 's|^/restart/||' | tr -d '\r\n')
		local response=$(restart_tunnel "$log_id")

		printf "HTTP/1.1 200 OK\r\n"
		printf "Content-Type: application/json\r\n"
		printf "Access-Control-Allow-Origin: *\r\n"
		printf "Connection: close\r\n"
		printf "\r\n"
		printf "%s\r\n" "$response"

	elif [ "$method" = "OPTIONS" ]; then
		printf "HTTP/1.1 204 No Content\r\n"
		printf "Access-Control-Allow-Origin: *\r\n"
		printf "Access-Control-Allow-Methods: POST, OPTIONS\r\n"
		printf "Access-Control-Allow-Headers: Content-Type\r\n"
		printf "Connection: close\r\n"
		printf "\r\n"

	elif [ "$method" = "GET" ] && [ "$path" = "/status" ]; then
		# Return status from monitor daemon's status file
		if [ -f "$STATUS_FILE" ]; then
			local status_content=$(cat "$STATUS_FILE")
			printf "HTTP/1.1 200 OK\r\n"
			printf "Content-Type: application/json\r\n"
			printf "Access-Control-Allow-Origin: *\r\n"
			printf "Connection: close\r\n"
			printf "\r\n"
			printf "%s\r\n" "$status_content"
		else
			printf "HTTP/1.1 503 Service Unavailable\r\n"
			printf "Content-Type: application/json\r\n"
			printf "Access-Control-Allow-Origin: *\r\n"
			printf "Connection: close\r\n"
			printf "\r\n"
			printf '{"error":"Status not available yet"}\r\n'
		fi

	elif [ "$method" = "GET" ] && echo "$path" | grep -q "^/logs/"; then
		# Return log content for specific tunnel
		local log_id=$(echo "$path" | sed 's|^/logs/||' | tr -d '\r\n')
		local log_file="${LOG_DIR}/tunnel_${log_id}.log"

		if [ -f "$log_file" ]; then
			# Return last 500 lines as JSON array
			printf "HTTP/1.1 200 OK\r\n"
			printf "Content-Type: application/json\r\n"
			printf "Access-Control-Allow-Origin: *\r\n"
			printf "Connection: close\r\n"
			printf "\r\n"
			printf '{"lines":['
			tail -n 500 "$log_file" | while IFS= read -r line; do
				# Escape backslashes, quotes, and control characters
				escaped=$(echo "$line" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g; s/\r/\\r/g')
				if [ "$first_line" != "done" ]; then
					printf '"%s"' "$escaped"
					first_line="done"
				else
					printf ',"%s"' "$escaped"
				fi
			done
			printf '],"log_id":"%s"}\r\n' "$log_id"
		else
			printf "HTTP/1.1 404 Not Found\r\n"
			printf "Content-Type: application/json\r\n"
			printf "Access-Control-Allow-Origin: *\r\n"
			printf "Connection: close\r\n"
			printf "\r\n"
			printf '{"error":"Log file not found"}\r\n'
		fi

	elif [ "$method" = "GET" ] && [ "$path" = "/health" ]; then
		printf "HTTP/1.1 200 OK\r\n"
		printf "Content-Type: application/json\r\n"
		printf "Connection: close\r\n"
		printf "\r\n"
		printf '{"status":"ok"}\r\n'

	else
		printf "HTTP/1.1 404 Not Found\r\n"
		printf "Content-Type: application/json\r\n"
		printf "Connection: close\r\n"
		printf "\r\n"
		printf '{"error":"Not found"}\r\n'
	fi
}

# Start the server
echo "Starting control API server on port $API_PORT..."

while true; do
	# Create unique FIFO for this request
	FIFO="$FIFO_DIR/req_$$_$(date +%s)"
	mkfifo "$FIFO" 2>/dev/null

	# Handle request using FIFO
	nc -l -p "$API_PORT" <"$FIFO" | handle_request >"$FIFO" 2>/dev/null

	# Clean up FIFO
	rm -f "$FIFO"

	# Small delay to prevent tight loop on error
	sleep 0.1
done
