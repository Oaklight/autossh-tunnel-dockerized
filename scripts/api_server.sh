#!/bin/sh

# Simple API Server using netcat
# Exposes autossh-cli functionality via HTTP

PORT="${API_PORT:-8080}"
PIPE="/tmp/autossh_api_pipe"

# Function to format HTTP response
response() {
	local status="$1"
	local body=$(cat)
	local length=$(echo -n "$body" | wc -c)

	echo "HTTP/1.1 $status"
	echo "Content-Type: text/plain; charset=utf-8"
	echo "Content-Length: $length"
	echo "Connection: close"
	echo ""
	echo -n "$body"
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
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $method $path" >&2

	case "$path" in
	"/list")
		if [ "$method" = "GET" ]; then
			autossh-cli list | response "200 OK"
		else
			echo "Method not allowed" | response "405 Method Not Allowed"
		fi
		;;
	"/status")
		if [ "$method" = "GET" ]; then
			autossh-cli status | response "200 OK"
		else
			echo "Method not allowed" | response "405 Method Not Allowed"
		fi
		;;
	"/start")
		if [ "$method" = "POST" ]; then
			autossh-cli start | response "200 OK"
		else
			echo "Method not allowed" | response "405 Method Not Allowed"
		fi
		;;
	*)
		echo "Not Found" | response "404 Not Found"
		;;
	esac
}

echo "Starting API server on port $PORT..."

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
