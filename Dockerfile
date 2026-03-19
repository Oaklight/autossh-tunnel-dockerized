# WebSocket server builder stage
ARG REGISTRY_MIRROR=docker.io
FROM ${REGISTRY_MIRROR}/library/golang:1.24-alpine AS ws-builder
ARG GOPROXY
WORKDIR /app
COPY ws-server .
RUN rm -f go.mod go.sum && \
    if [ -n "$GOPROXY" ]; then export GOPROXY="$GOPROXY"; fi && \
    go mod init ws-server && go mod tidy && go mod download
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -trimpath -o ws-server .

# Use an official lightweight Linux image
FROM ${REGISTRY_MIRROR}/library/alpine:3.22.0 AS base

ARG VERSION=dev

# install dependencies
RUN apk add --no-cache \
    autossh \
    flock \
    inotify-tools \
    netcat-openbsd \
    socat \
    su-exec

# create user and group
RUN addgroup -g 1000 mygroup && \
    adduser -D -u 1000 -G mygroup myuser

# copy scripts and setup permssions
COPY autossh-cli /usr/local/bin/autossh-cli
COPY scripts /usr/local/bin/scripts
COPY spinoff_monitor.sh /usr/local/bin/spinoff_monitor.sh
COPY entrypoint.sh /entrypoint.sh
COPY --from=ws-builder /app/ws-server /usr/local/bin/ws-server

RUN chmod +x /usr/local/bin/autossh-cli \
    /usr/local/bin/spinoff_monitor.sh \
    /usr/local/bin/ws-server \
    /usr/local/bin/scripts/*.sh \
    /entrypoint.sh

RUN echo "$VERSION" > /etc/autossh-version

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Set the default command
CMD ["/usr/local/bin/spinoff_monitor.sh"]
