#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
# The G fixture adds RUN sleep 12 to ensure the disconnect happens in a build.
python3 "$root/probes/kamal/measure.py" --output "$root/.probe-private/evidence" \
  --url https://api.probe.stageserver.ru/health baseline-G-drop -- \
  "$root/probes/kamal/dw" deploy run --env probe \
  --identity "$HOME/.ssh/id_ed25519_global" --progress json &
observer=$!
python3 "$root/probes/kamal/drop_ssh.py" "$observer" \
  "$root/.probe-private/evidence/baseline-G-drop.stdout" \
  "$root/.probe-private/evidence/baseline-G-interruption.json"
wait "$observer"
