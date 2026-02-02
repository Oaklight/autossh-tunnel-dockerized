#!/bin/sh

# http_utils.sh - HTTP utility functions for API server
# This module provides HTTP response formatting and authentication functions

# Optional API Key(s) for Bearer token authentication
# If API_KEY is set, all requests must include "Authorization: Bearer <API_KEY>" header
# Multiple keys can be specified, separated by commas (e.g., "key1,key2,key3")
API_KEY="${API_KEY:-}"

# Function to format HTTP response
# Usage: echo "body" | response "200 OK"
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

# Function to escape string for JSON output
# Usage: json_escape "string with \"quotes\" and newlines"
json_escape() {
	local input="$1"
	echo "$input" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g'
}
