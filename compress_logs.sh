#!/bin/sh

# Log compression script for autossh tunnels
# Compresses log files when they exceed a specified size while preserving the header block

LOG_DIR="/var/log/autossh"
# Default log size threshold: 100KB (102400 bytes)
# This keeps recent status entries for web monitoring while preventing log bloat
# You can override this by setting LOG_SIZE environment variable
LOG_SIZE=${LOG_SIZE:-102400}

# Function to extract header block from log file
extract_header() {
	local log_file=$1
	local header=""
	local in_header=0

	while IFS= read -r line; do
		if echo "$line" | grep -q "^========================================="; then
			if [ $in_header -eq 0 ]; then
				in_header=1
				header="${header}${line}\n"
			else
				header="${header}${line}\n"
				break
			fi
		elif [ $in_header -eq 1 ]; then
			header="${header}${line}\n"
		fi
	done <"$log_file"

	printf "%b" "$header"
}

# Function to compress a log file
compress_log() {
	local log_file=$1
	local log_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null)

	# Check if file size exceeds threshold
	if [ "$log_size" -lt "$LOG_SIZE" ]; then
		return 0
	fi

	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Compressing log file: $log_file (size: $log_size bytes)"

	# Extract header block
	local header=$(extract_header "$log_file")

	# Generate timestamp for compressed file
	local timestamp=$(date '+%Y%m%d_%H%M%S')
	local compressed_file="${log_file%.log}_${timestamp}.log.gz"

	# Compress the log file
	if gzip -c "$log_file" >"$compressed_file"; then
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Created compressed file: $compressed_file"

		# Recreate log file with header only
		printf "%b" "$header" >"$log_file"

		# Add compression notice to the new log file
		{
			echo "[$(date '+%Y-%m-%d %H:%M:%S')] Previous log compressed to: $(basename "$compressed_file")"
			echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log rotation performed due to size threshold (${LOG_SIZE} bytes)"
			echo "========================================="
		} >>"$log_file"

		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log file reset with header preserved"
	else
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to compress $log_file"
		rm -f "$compressed_file"
		return 1
	fi
}

# Function to check and compress all log files
check_and_compress_logs() {
	if [ ! -d "$LOG_DIR" ]; then
		echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log directory not found: $LOG_DIR"
		return 1
	fi

	# Find all active log files (not already compressed)
	find "$LOG_DIR" -name "tunnel_*.log" -type f | while read -r log_file; do
		compress_log "$log_file"
	done
}

# Main execution
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting log compression check (threshold: $LOG_SIZE bytes)"
check_and_compress_logs
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log compression check completed"
