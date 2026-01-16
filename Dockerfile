# Use an official lightweight Linux image
FROM alpine:3.22.0 AS base

# install dependencies
RUN apk add --no-cache \
    autossh \
    inotify-tools \
    yq \
    netcat-openbsd

# create user and group
RUN addgroup -g 1000 mygroup && \
    adduser -D -u 1000 -G mygroup myuser

# create log directory
RUN mkdir -p /var/log/autossh && \
    chown myuser:mygroup /var/log/autossh

# copy scripts and setup permssions
COPY entrypoint.sh /entrypoint.sh
COPY scripts/ /scripts/
RUN chmod +x /entrypoint.sh /scripts/*.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Set the default command
CMD ["/scripts/start_autossh.sh"]
