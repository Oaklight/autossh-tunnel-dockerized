#!/bin/sh

# json_utils.sh - JSON utility functions for API server
# This module provides simple JSON parsing and generation functions

# Function to extract JSON string field value
# Usage: json_get_field "$json" "field_name"
# Returns: The value of the field (without quotes)
json_get_field() {
	local json="$1"
	local field="$2"
	echo "$json" | sed -n 's/.*"'"$field"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
}

# Function to extract JSON boolean field value
# Usage: json_get_bool "$json" "field_name"
# Returns: "true" or "false"
json_get_bool() {
	local json="$1"
	local field="$2"
	echo "$json" | sed -n 's/.*"'"$field"'"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' | head -1
}

# Function to extract JSON number field value
# Usage: json_get_number "$json" "field_name"
# Returns: The numeric value
json_get_number() {
	local json="$1"
	local field="$2"
	echo "$json" | sed -n 's/.*"'"$field"'"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | head -1
}

# Function to escape string for JSON output
# Usage: json_escape "string with \"quotes\" and newlines"
json_escape() {
	local input="$1"
	echo "$input" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g'
}

# Function to generate a JSON object from key-value pairs
# Usage: json_object "key1" "value1" "key2" "value2" ...
# Note: All values are treated as strings
json_object() {
	local result="{"
	local first=true

	while [ $# -ge 2 ]; do
		local key="$1"
		local value="$2"
		shift 2

		if [ "$first" = "true" ]; then
			first=false
		else
			result="$result,"
		fi

		result="$result\"$key\":\"$value\""
	done

	result="$result}"
	echo "$result"
}

# Function to generate a tunnel JSON object
# Usage: tunnel_to_json "name" "remote_host" "remote_port" "local_port" "direction" "interactive" "hash"
tunnel_to_json() {
	local name="$1"
	local remote_host="$2"
	local remote_port="$3"
	local local_port="$4"
	local direction="$5"
	local interactive="$6"
	local hash="$7"

	# Convert interactive to boolean
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
}

# Function to generate a tunnel JSON object (compact, for arrays)
# Usage: tunnel_to_json_compact "name" "remote_host" "remote_port" "local_port" "direction" "interactive" "hash"
tunnel_to_json_compact() {
	local name="$1"
	local remote_host="$2"
	local remote_port="$3"
	local local_port="$4"
	local direction="$5"
	local interactive="$6"
	local hash="$7"

	# Convert interactive to boolean
	if [ "$interactive" = "true" ]; then
		interactive_json="true"
	else
		interactive_json="false"
	fi

	printf '{"name":"%s","remote_host":"%s","remote_port":"%s","local_port":"%s","direction":"%s","interactive":%s,"hash":"%s"}' \
		"$name" "$remote_host" "$remote_port" "$local_port" "$direction" "$interactive_json" "$hash"
}

# Function to generate a status JSON object
# Usage: status_to_json_obj "name" "status" "local_port" "remote_host" "remote_port" "hash"
status_to_json_obj() {
	local name="$1"
	local status="$2"
	local local_port="$3"
	local remote_host="$4"
	local remote_port="$5"
	local hash="$6"

	printf '{
    "name": "%s",
    "status": "%s",
    "local_port": "%s",
    "remote_host": "%s",
    "remote_port": "%s",
    "hash": "%s"
  }' "$name" "$status" "$local_port" "$remote_host" "$remote_port" "$hash"
}

# Function to generate error JSON
# Usage: json_error "Error message"
json_error() {
	local message="$1"
	local escaped_message=$(json_escape "$message")
	printf '{"error": "%s"}' "$escaped_message"
}

# Function to generate success JSON
# Usage: json_success "Success message"
json_success() {
	local message="$1"
	printf '{"status": "success", "message": "%s"}' "$message"
}
