#!/bin/sh

# Load PUID and PGID from environment variables
PUID=${PUID:-1000}
PGID=${PGID:-1000}

# Export autossh-cli environment variables if set
# These are used by autossh-cli to locate config and state files
if [ -n "$AUTOSSH_CONFIG_FILE" ]; then
	export AUTOSSH_CONFIG_FILE
fi
if [ -n "$SSH_CONFIG_DIR" ]; then
	export SSH_CONFIG_DIR
fi
if [ -n "$AUTOSSH_STATE_FILE" ]; then
	export AUTOSSH_STATE_FILE
fi

# Modify the existing user and group to match PUID and PGID
if [ "$(id -u myuser)" != "$PUID" ] || [ "$(id -g myuser)" != "$PGID" ]; then
	sed -i "s/^myuser:x:[0-9]*:[0-9]*:/myuser:x:$PUID:$PGID:/" /etc/passwd
	sed -i "s/^mygroup:x:[0-9]*:/mygroup:x:$PGID:/" /etc/group
fi

# Ensure state file directory exists and is writable
mkdir -p /tmp
chmod 777 /tmp
rm -f /tmp/autossh_tunnels.state

# Switch to myuser and execute the command passed as arguments
# Build command string manually for ash shell compatibility
cmd=""
for arg in "$@"; do
    # Simple escaping for shell arguments
    escaped_arg=$(printf '%s' "$arg" | sed "s/'/'\\\\''/g")
    cmd="$cmd '$escaped_arg'"
done
exec su myuser -c "$cmd"
