#!/bin/bash

# Ensure /home/claude is owned by claude user
chown -R claude:claude /home/claude
chmod 755 /home/claude

# Start SSH daemon
/usr/sbin/sshd -D &

# Start code-server as claude user
su - claude -c "code-server --bind-addr 0.0.0.0:8080 --auth none" &

# Start SHELLNGN with HTTPS and no authentication
su - claude -c "shellngn --port 4200 --https --no-auth" &

# Keep container running
wait -n
exit $?
