# Use an official lightweight Linux image
FROM alpine:3.20.2 AS base

# Install necessary packages
RUN apk add --no-cache autossh

# Download yq and make it executable
RUN apk add --no-cache curl && \
    curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/bin/yq && \
    chmod +x /usr/bin/yq && \
    apk del curl  # Remove curl after use

# Create a non-root user and set up the environment
RUN adduser -D myuser

# Create a directory for autossh configuration
RUN mkdir /etc/autossh && chown myuser:myuser /etc/autossh

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh

# Make the entrypoint script executable
RUN chmod +x /entrypoint.sh

# Switch to the non-root user
USER myuser

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]