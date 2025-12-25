#!/bin/bash

# Ensure /home/claude is owned by claude user
chown -R claude:claude /home/claude
chmod 755 /home/claude

# Start SSH daemon
/usr/sbin/sshd -D &

# Start code-server as claude user
su - claude -c "code-server --bind-addr 0.0.0.0:8080 --auth none" &

# Start wetty (web terminal) with SSL disabled (Traefik handles HTTPS)
su - claude -c "wetty --port 3000 --host 0.0.0.0 --ssh-host localhost --ssh-user claude" &

# Keep container running
wait -n
exit $?
