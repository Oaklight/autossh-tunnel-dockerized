#!/bin/sh

# Load the configuration from config.yaml
CONFIG_FILE="/etc/autossh/config/config.yaml"

# Function to parse YAML and extract tunnel configurations
parse_config() {
    local config_file=$1
    yq e '.tunnels[] | [.remote_host, .remote_port, .local_port, .direction] | @tsv' "$config_file"
}

# Function to start autossh
start_autossh() {
    local remote_host=$1
    local remote_port=$2
    local local_port=$3
    local direction=${4:-remote_to_local}  # 设置默认值为 remote_to_local

    if echo "$remote_port" | grep -q ":"; then
        target_host=$(echo "$remote_port" | cut -d: -f1)
        target_port=$(echo "$remote_port" | cut -d: -f2)
    else
        target_host="localhost"
        target_port="$remote_port"
    fi

    # Parse local_port to extract local_host and local_port
    if echo "$local_port" | grep -q ":"; then
        local_host=$(echo "$local_port" | cut -d: -f1)
        local_port=$(echo "$local_port" | cut -d: -f2)
    else
        local_host="localhost"
    fi

    if [ "$direction" = "local_to_remote" ]; then
        echo "Starting SSH tunnel (local to remote): $local_host:$local_port -> $remote_host:$remote_port"
        autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -N -R $target_host:$target_port:$local_host:$local_port $remote_host
    else
        echo "Starting SSH tunnel (remote to local): $local_host:$local_port <- $remote_host:$remote_port"
        autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -N -L $local_port:$target_host:$target_port $remote_host
    fi
}

# Read the config.yaml file and start autossh for each entry
while IFS=$'\t' read -r remote_host remote_port local_port direction; do
    start_autossh "$remote_host" "$remote_port" "$local_port" "$direction" &
done < <(parse_config "$CONFIG_FILE")

# Wait for all background processes to finish
wait