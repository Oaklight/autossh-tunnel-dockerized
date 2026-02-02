#!/bin/sh

# Web panel entrypoint
# This container is a pure static server - no config volume needed
# All configuration operations go through the autossh Config API

# Switch to myuser and execute the command passed as arguments
exec su-exec myuser "$@"
