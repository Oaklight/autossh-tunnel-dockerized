# Use an official lightweight Linux image
ARG REGISTRY_MIRROR=docker.io
FROM ${REGISTRY_MIRROR}/library/alpine:3.22.0 AS base

# install dependencies
RUN apk add --no-cache \
    autossh \
    inotify-tools \
    netcat-openbsd

# create user and group
RUN addgroup -g 1000 mygroup && \
    adduser -D -u 1000 -G mygroup myuser

# copy scripts and setup permssions
COPY autossh-cli /usr/local/bin/autossh-cli
COPY scripts /usr/local/bin/scripts
COPY spinoff_monitor.sh /usr/local/bin/spinoff_monitor.sh
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /usr/local/bin/autossh-cli \
    /usr/local/bin/spinoff_monitor.sh \
    /usr/local/bin/scripts/*.sh \
    /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Set the default command
CMD ["/usr/local/bin/spinoff_monitor.sh"]