#!/bin/sh
set -eu
# Invoke on the authorized throwaway target, never on another machine.
test "$(hostname -I | awk '{print $1}')" = 82.26.151.195
date -u +%FT%TZ
df -B1 / /var/lib/docker
docker system df
docker ps -a --format '{{.Names}} {{.Image}} {{.Status}}'
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}'
docker volume ls --format '{{.Name}}'
