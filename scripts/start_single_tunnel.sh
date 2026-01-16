#!/bin/sh

# Unified script to start a single SSH tunnel
# Usage: start_single_tunnel.sh <remote_host> <remote_port> <local_port> <direction>

# Source shared tunnel utilities
. /scripts/tunnel_utils.sh

remote_host=$1
remote_port=$2
local_port=$3
direction=${4:-remote_to_local}

LOG_SIZE=${LOG_SIZE:-102400}

# Generate unique log ID
log_id=$(generate_log_id "$remote_host" "$remote_port" "$local_port" "$direction")
log_file="${LOG_DIR}/tunnel_${log_id}.log"

# Parse ports
if echo "$remote_port" | grep -q ":"; then
	target_host=$(echo "$remote_port" | cut -d: -f1)
	target_port=$(echo "$remote_port" | cut -d: -f2)
else
	target_host="localhost"
	target_port="$remote_port"
fi

if echo "$local_port" | grep -q ":"; then
	local_host=$(echo "$local_port" | cut -d: -f1)
	local_port=$(echo "$local_port" | cut -d: -f2)
else
	local_host="localhost"
fi

# Start the tunnel in background (removed setsid/nohup to keep it in container's process tree)
if [ "$direction" = "local_to_remote" ]; then
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting tunnel (local to remote): $local_host:$local_port -> $remote_host:$remote_port" >>"$log_file"
	autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -o "ExitOnForwardFailure=yes" -o "SetEnv TUNNEL_ID=${log_id}" -N -R $target_host:$target_port:$local_host:$local_port $remote_host >>"$log_file" 2>&1 &
else
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting tunnel (remote to local): $local_host:$local_port <- $remote_host:$remote_port" >>"$log_file"
	autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -o "ExitOnForwardFailure=yes" -o "SetEnv TUNNEL_ID=${log_id}" -N -L $local_host:$local_port:$target_host:$target_port $remote_host >>"$log_file" 2>&1 &
fi

echo "Tunnel ${log_id} started successfully"
