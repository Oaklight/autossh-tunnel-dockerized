# Use an official lightweight Linux image
FROM alpine:3.22.0 AS base

# install dependencies
RUN apk add --no-cache \
    autossh \
    inotify-tools \
    yq

# create user and group
RUN addgroup -g 1000 mygroup && \
    adduser -D -u 1000 -G mygroup myuser

# create log directory
RUN mkdir -p /var/log/autossh && \
    chown myuser:mygroup /var/log/autossh

# copy scripts and setup permssions
COPY entrypoint.sh /entrypoint.sh
COPY start_autossh.sh /start_autossh.sh
COPY spinoff_monitor.sh /spinoff_monitor.sh
RUN chmod +x /entrypoint.sh /start_autossh.sh /spinoff_monitor.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Set the default command
CMD ["/start_autossh.sh"]
