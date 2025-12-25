FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    USER=claude \
    HOME=/home/claude \
    SHELL=/bin/bash

# Create claude user with sudo privileges
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    wget \
    git \
    openssh-server \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential \
    python3 \
    && useradd -m -s /bin/bash -u 1000 ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir -p /var/run/sshd

# Install Node.js (required for VSC server and Claude Code)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Install wetty (web-based terminal with HTTPS support)
RUN npm install -g wetty \
    && mkdir -p ${HOME}/.wetty

# Install VSCode Server (code-server)
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Configure SSH
RUN mkdir -p /etc/ssh && \
    ssh-keygen -A && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Set up directory ownership
RUN chown -R ${USER}:${USER} ${HOME} && \
    chmod 755 ${HOME}

# Create startup script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose ports
# 22: SSH
# 3000: wetty HTTPS
# 8080: code-server
EXPOSE 22 3000 8080

ENTRYPOINT ["/entrypoint.sh"]
