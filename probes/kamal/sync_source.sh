#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
# Copy only this probe's source, never its private credentials or SDK cache.
COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata --exclude=.dart_tool --exclude=build --exclude='.git' \
  -czf "$root/.probe-private/source-update.tar.gz" \
  -C "$root/.probe-private/probe_dw" .
scp -q -i "$HOME/.ssh/id_ed25519_global" \
  "$root/.probe-private/source-update.tar.gz" root@82.26.151.195:/opt/source-update.tar.gz
ssh -i "$HOME/.ssh/id_ed25519_global" root@82.26.151.195 '
set -eu
tar -xzf /opt/source-update.tar.gz -C /opt/probe-source
cd /opt/probe-source
chown -R root:root /opt/probe-source
git add $(git ls-files --modified --others --exclude-standard)
git diff --cached --quiet || git commit -qm "chore: update throwaway probe source"
chown -R root:root /opt/probe-source.git
trap "chown -R dw_admin:dw_admin /opt/probe-source.git" EXIT
git push /opt/probe-source.git master
'
