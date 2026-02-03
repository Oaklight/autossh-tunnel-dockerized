ARG REGISTRY_MIRROR=docker.io
FROM ${REGISTRY_MIRROR}/ubuntu:22.04

# Update and install dependencies
RUN apt-get update && apt-get install -y \
    openssh-server \
    libpam-google-authenticator \
    sudo \
    iproute2 \
    vim \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Configure SSHD
RUN mkdir /var/run/sshd

# Copy custom configs
COPY config/sshd_config /etc/ssh/sshd_config
COPY config/pam.d/sshd /etc/pam.d/sshd

# Setup user and authenticator
COPY scripts/setup_user.sh /usr/local/bin/setup_user.sh
RUN chmod +x /usr/local/bin/setup_user.sh && /usr/local/bin/setup_user.sh

# Expose port
EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]