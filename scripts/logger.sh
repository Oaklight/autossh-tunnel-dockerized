#!/bin/sh

# Unified logging function
# Usage: log [LEVEL] [COMPONENT] "Message"
log() {
	local level="$1"
	local component="$2"
	local message="$3"
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	echo "[$timestamp] [$level] [$component] $message"
}

log_info() {
	log "INFO" "$1" "$2"
}

log_warn() {
	log "WARN" "$1" "$2"
}

log_error() {
	log "ERROR" "$1" "$2"
}
