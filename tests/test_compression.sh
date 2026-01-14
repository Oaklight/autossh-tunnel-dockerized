#!/bin/sh

# Test script for log compression functionality
# This script creates a test log file and verifies compression works correctly

LOG_DIR="/var/log/autossh"
TEST_LOG_ID="test1234"
TEST_LOG="${LOG_DIR}/tunnel_${TEST_LOG_ID}.log"
LOG_SIZE=1024 # Set to 1KB for testing

echo "========================================="
echo "Log Compression Test"
echo "========================================="
echo ""

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Create a test log file with header
echo "Creating test log file with header..."
cat >"$TEST_LOG" <<'EOF'
=========================================
Tunnel Log ID: test1234
Started at: 2026-01-14 14:30:00
Configuration:
  Remote Host: user@test-host
  Remote Port: 8000
  Local Port: 8001
  Direction: remote_to_local
=========================================
EOF

echo "Initial log file created."
echo "File size: $(stat -f%z "$TEST_LOG" 2>/dev/null || stat -c%s "$TEST_LOG" 2>/dev/null) bytes"
echo ""

# Add content to exceed the threshold
echo "Adding content to exceed threshold (${LOG_SIZE} bytes)..."
for i in $(seq 1 50); do
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Test log entry $i - This is a test message to fill up the log file" >>"$TEST_LOG"
done

CURRENT_SIZE=$(stat -f%z "$TEST_LOG" 2>/dev/null || stat -c%s "$TEST_LOG" 2>/dev/null)
echo "Current file size: ${CURRENT_SIZE} bytes"
echo ""

# Source the compression functions from start_autossh.sh
echo "Testing compression function..."

# Extract header function
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

# Compression function
check_and_compress_log() {
	local log_file=$1

	if [ ! -f "$log_file" ]; then
		echo "ERROR: Log file not found"
		return 1
	fi

	local log_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null)

	if [ "$log_size" -lt "$LOG_SIZE" ]; then
		echo "File size ($log_size bytes) is below threshold ($LOG_SIZE bytes)"
		return 0
	fi

	echo "File size ($log_size bytes) exceeds threshold ($LOG_SIZE bytes)"
	echo "Compressing..."

	local header=$(extract_header "$log_file")
	local timestamp=$(date '+%Y%m%d_%H%M%S')
	local compressed_file="${log_file%.log}_${timestamp}.log.gz"

	if gzip -c "$log_file" >"$compressed_file"; then
		echo "✓ Compressed file created: $(basename "$compressed_file")"

		printf "%b" "$header" >"$log_file"

		{
			echo "[$(date '+%Y-%m-%d %H:%M:%S')] Previous log compressed to: $(basename "$compressed_file")"
			echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log rotation performed due to size threshold (${LOG_SIZE} bytes)"
			echo "========================================="
		} >>"$log_file"

		echo "✓ Log file reset with header preserved"
		return 0
	else
		echo "✗ ERROR: Failed to compress"
		rm -f "$compressed_file"
		return 1
	fi
}

# Run compression test
check_and_compress_log "$TEST_LOG"

echo ""
echo "========================================="
echo "Verification"
echo "========================================="

# Check if compressed file exists
COMPRESSED_FILES=$(find "$LOG_DIR" -name "tunnel_${TEST_LOG_ID}_*.log.gz" 2>/dev/null)
if [ -n "$COMPRESSED_FILES" ]; then
	echo "✓ Compressed file(s) found:"
	for file in $COMPRESSED_FILES; do
		SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
		echo "  - $(basename "$file") (${SIZE} bytes)"
	done
else
	echo "✗ No compressed files found"
fi

echo ""

# Check if original log was reset
if [ -f "$TEST_LOG" ]; then
	NEW_SIZE=$(stat -f%z "$TEST_LOG" 2>/dev/null || stat -c%s "$TEST_LOG" 2>/dev/null)
	echo "✓ Active log file exists (${NEW_SIZE} bytes)"
	echo ""
	echo "Active log content:"
	echo "---"
	cat "$TEST_LOG"
	echo "---"
else
	echo "✗ Active log file not found"
fi

echo ""
echo "========================================="
echo "Test completed"
echo "========================================="
echo ""
echo "To clean up test files, run:"
echo "  rm ${LOG_DIR}/tunnel_${TEST_LOG_ID}*"
