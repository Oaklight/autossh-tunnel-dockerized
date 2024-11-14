#!/bin/sh

# Load the configuration from config.yaml
CONFIG_FILE="/etc/autossh/config.yaml"

# Function to parse YAML and start autossh
start_autossh() {
    local remote_host=$1
    local remote_port=$2
    local local_port=$3

    echo "Starting SSH tunnel: localhost:$local_port -> $remote_host:$remote_port"
    autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -N -L $local_port:localhost:$remote_port $remote_host
}

# Read the config.yaml file and start autossh for each entry
while IFS=":" read -r remote_host remote_port local_port; do
    start_autossh $remote_host $remote_port $local_port &
done < <(yq e '.tunnels[] | [.remote_host, .remote_port, .local_port] | join(":")' $CONFIG_FILE)

# Wait for all background processes to finish
wait