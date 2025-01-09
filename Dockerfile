# Use an official lightweight Linux image
FROM alpine:3.20.2 AS base

# Install necessary packages
RUN apk add --no-cache autossh

# Download yq and make it executable
RUN apk add --no-cache curl && \
    curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/bin/yq && \
    chmod +x /usr/bin/yq && \
    apk del curl  # Remove curl after use

ENV PUID=1000
ENV PGID=1000

# Create a non-root user and set up the environment, default UID and GID is PUID and PGID
RUN addgroup -g ${PGID} mygroup && \
    adduser -u ${PUID} -G mygroup -D myuser

# Create a directory for autossh configuration
RUN mkdir /etc/autossh && chown myuser:mygroup /etc/autossh

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh

# Make the entrypoint script executable
RUN chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
