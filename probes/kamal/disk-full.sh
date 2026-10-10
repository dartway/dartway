#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
# The I fixture adds a 31-second build pause followed by a 200 MiB layer write.
python3 "$root/probes/kamal/measure.py" --output "$root/.probe-private/evidence" \
  --url https://api.probe.stageserver.ru/health baseline-I-mid-full -- \
  "$root/probes/kamal/dw" deploy run --env probe \
  --identity "$HOME/.ssh/id_ed25519_global" --progress json &
observer=$!
python3 - <<'PYWAIT'
import subprocess, time
from pathlib import Path
end = time.monotonic() + 120
while time.monotonic() < end:
    result = subprocess.run([
        'ssh', '-o', 'ConnectTimeout=5', '-i', str(Path.home()/'.ssh/id_ed25519_global'),
        'root@82.26.151.195', "ps -C sleep -o args= | grep -qx 'sleep 31'",
    ], capture_output=True, timeout=10)
    if result.returncode == 0:
        break
    time.sleep(0.5)
else:
    raise SystemExit('Actual build pause not observed; target was not filled.')
PYWAIT
ssh -i "$HOME/.ssh/id_ed25519_global" root@82.26.151.195 \
  'sh /opt/probe-disk-fill.sh' > "$root/.probe-private/evidence/baseline-I-fill.log"
set +e
wait "$observer"
result=$?
set -e
ssh -i "$HOME/.ssh/id_ed25519_global" root@82.26.151.195 \
  'if [ -f /opt/probe-disk-fill-current ]; then rm -f "$(cat /opt/probe-disk-fill-current)"; rm -f /opt/probe-disk-fill-current; fi; df -B1 /' \
  > "$root/.probe-private/evidence/baseline-I-freed.log"
exit "$result"
