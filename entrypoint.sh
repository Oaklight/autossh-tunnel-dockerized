#!/bin/sh

# Load PUID and PGID from environment variables
PUID=${PUID:-1000}
PGID=${PGID:-1000}

case "$PUID" in
'' | *[!0-9]*)
	echo "ERROR: PUID must be a numeric user ID (got '$PUID')" >&2
	exit 1
	;;
esac

case "$PGID" in
'' | *[!0-9]*)
	echo "ERROR: PGID must be a numeric group ID (got '$PGID')" >&2
	exit 1
	;;
esac

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

# Export WebSocket server environment variables if set
for _var in WS_PORT WS_MAX_CONNECTIONS WS_IDLE_TIMEOUT WS_MAX_DURATION WS_ALLOWED_ORIGINS; do
	eval "[ -n \"\$$_var\" ] && export $_var"
done

# Modify the existing user and group to match PUID and PGID.
# OpenSSH refuses to start when getpwuid() cannot resolve the runtime UID,
# so the container cannot simply run with docker --user for arbitrary UIDs.
if [ "$(id -u myuser)" != "$PUID" ] || [ "$(id -g myuser)" != "$PGID" ]; then
	sed -i "s/^myuser:x:[0-9]*:[0-9]*:/myuser:x:$PUID:$PGID:/" /etc/passwd
	sed -i "s/^mygroup:x:[0-9]*:/mygroup:x:$PGID:/" /etc/group
fi

# Ensure state file directory exists and is writable
mkdir -p /tmp
chmod 777 /tmp

# Ensure log directory exists with proper permissions
mkdir -p /tmp/autossh-logs
chmod 777 /tmp/autossh-logs

# Clean up old log files on container start
rm -f /tmp/autossh-logs/*.log

# Clean up state file on container start to ensure accuracy
# The state file will be recreated with actual running tunnels
rm -f /tmp/autossh_tunnels.state
touch /tmp/autossh_tunnels.state
chmod 666 /tmp/autossh_tunnels.state
chown myuser:mygroup /tmp/autossh_tunnels.state

# Also ensure log directory is owned by myuser
chown -R myuser:mygroup /tmp/autossh-logs

# Ensure home directory has proper ownership after PUID/PGID change
# (needed for interactive auth socket directory creation)
chown myuser:mygroup /home/myuser

# Ensure config directory has proper ownership
# (Docker creates bind-mount directories as root if they don't exist on the host)
if [ -d /etc/autossh/config ]; then
	chown -R myuser:mygroup /etc/autossh/config
fi

# Quote one argument so it can be embedded in a shell command string.
shell_quote() {
	printf "'"
	printf '%s' "$1" | sed "s/'/'\\\\''/g"
	printf "'"
}

# Switch to myuser and execute the command passed as arguments.
# BusyBox su replaces su-exec. Its option parser reads dash-prefixed words
# after the user name, so the whole command is passed as one quoted string
# to "sh -c". su execs that shell, which execs the command, keeping it PID 1.
command=""
for arg in "$@"; do
	command="$command $(shell_quote "$arg")"
done
exec su myuser -s /bin/sh -c "exec$command"
