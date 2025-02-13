#!/bin/sh

# start the configuration file monitoring in the background
/spinoff_monitor.sh &

# Load PUID and PGID from environment variables
PUID=${PUID:-1000}
PGID=${PGID:-1000}

# Modify the existing user and group to match PUID and PGID
if [ "$(id -u myuser)" != "$PUID" ] || [ "$(id -g myuser)" != "$PGID" ]; then
    sed -i "s/^myuser:x:[0-9]*:[0-9]*:/myuser:x:$PUID:$PGID:/" /etc/passwd
    sed -i "s/^mygroup:x:[0-9]*:/mygroup:x:$PGID:/" /etc/group
fi

# Switch to myuser and execute the command passed as arguments
exec su myuser -c "$@"
