#!/bin/sh
set -eu
# Execute after baseline removal. Certificate copies remain only on the target.
test "$(hostname -I | awk '{print $1}')" = 82.26.151.195
cd /opt/probe-registry
umask 077
mkdir -p auth
if [ ! -f password ]; then openssl rand -hex 32 > password; fi
# Password on stdin, never argv or a repository file.
docker run --rm -i --entrypoint htpasswd httpd:2-alpine -niB probe \
  < password > auth/htpasswd
chmod 755 auth
chmod 644 auth/htpasswd
docker compose -p probe_registry -f registry.compose.yml up -d
