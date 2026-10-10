#!/bin/sh
set -eu
# Fill only the throwaway target, after the build's free-space check passes.
test "$(hostname -I | awk '{print $1}')" = 82.26.151.195
available=$(df -B1 --output=avail /var/lib/docker | tail -1)
filler="/opt/probe-disk-fill-$(date +%s)"
printf '%s\n' "$filler" > /opt/probe-disk-fill-current
fallocate -l "$((available - 32 * 1024 * 1024))" "$filler"
# A detached watchdog prevents a dropped observer from leaving the target full.
nohup sh -c 'sleep 180; rm -f "$1"' sh "$filler" \
  >/opt/probe-disk-watchdog.log 2>&1 </dev/null &
df -B1 /var/lib/docker
