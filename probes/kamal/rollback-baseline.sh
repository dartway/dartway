#!/bin/sh
set -eu
# Execute on the probe target with the previously recorded immutable image ID.
previous=$1
test "$(hostname -I | awk '{print $1}')" = 82.26.151.195
cd /home/dw_admin/probe_dw
docker tag "$previous" probe_dw-server:latest
docker compose up -d --no-build --no-deps --force-recreate --wait --wait-timeout 45 server
docker compose restart nginx
