#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
python3 "$root/probes/kamal/measure.py" --output "$root/.probe-private/evidence" \
  --url https://api.probe.stageserver.ru/health baseline-F -- \
  ssh -i "$HOME/.ssh/id_ed25519_global" root@82.26.151.195 \
  'docker exec -w /probe probe_dw-server-1 /app/dartway deploy run --env probe --identity /probe-self/id_ed25519 --progress json'
