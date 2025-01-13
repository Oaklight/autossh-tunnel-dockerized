#!/bin/sh

# Load the configuration from config.yaml
CONFIG_FILE="/etc/autossh/config/config.yaml"

# Function to parse YAML and extract tunnel configurations
parse_config() {
    local config_file=$1
    yq e '.tunnels[] | [.remote_host, .remote_port, .local_port] | @tsv' "$config_file"
}

# Function to start autossh
start_autossh() {
    local remote_host=$1
    local remote_port=$2
    local local_port=$3

    if echo "$remote_port" | grep -q ":"; then
        target_host=$(echo "$remote_port" | cut -d: -f1)
        target_port=$(echo "$remote_port" | cut -d: -f2)
    else
        target_host="localhost"
        target_port="$remote_port"
    fi

    echo "Starting SSH tunnel: localhost:$local_port -> $remote_host:$remote_port"
    autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -N -L $local_port:$target_host:$target_port $remote_host
}

# Read the config.yaml file and start autossh for each entry
while IFS=$'\t' read -r remote_host remote_port local_port; do
    start_autossh "$remote_host" "$remote_port" "$local_port" &
done < <(parse_config "$CONFIG_FILE")

# Wait for all background processes to finish
wait