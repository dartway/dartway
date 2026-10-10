#!/usr/bin/env python3
"""Sign in to the disposable template using its log-only code delivery."""
import json
import re
import subprocess
import uuid
from pathlib import Path

root = Path(__file__).resolve().parents[2]
private = root / ".probe-private"


def call(kind, data):
    return json.loads(subprocess.check_output([
        "curl", "--silent", "--show-error", "--max-time", "15",
        "-H", "Content-Type: application/json", "-H", "Dw-Protocol: 3",
        "-H", "Dw-Contract-Version: 0.1.0", "-H", "Dw-App-Version: 0.1.0+1",
        "-H", "Dw-Idempotency-Key: " + str(uuid.uuid4()),
        "--data", json.dumps(data), "https://api.probe.stageserver.ru/dw/" + kind,
    ]))


ticket = call("DwRequestCode", {"kind": "email", "identifier": "probe@stageserver.ru"})
(private / "ticket.json").write_text(json.dumps(ticket))
logs = subprocess.check_output([
    "ssh", "-i", str(Path.home() / ".ssh/id_ed25519_global"), "root@82.26.151.195",
    "docker logs probe_dw-server-1 2>&1 | tail -100",
], text=True)
code = re.findall(r"Sign-in code for probe@stageserver.ru: (\d+)", logs)[-1]
# Only the private file receives the ticket, code, and session token.
response = call("DwVerifyCode", {"ticketId": ticket["result"]["id"], "code": code, "registration": {"terms": "true", "firstName": "Probe"}})
(private / "session-response.json").write_text(json.dumps(response))
if response.get("status") != "ok":
    raise SystemExit("Sign-in refused; private response saved.")
(private / "session.json").write_text(json.dumps(response["result"]))
(private / "session.json").chmod(0o600)
print("Signed in; session saved privately.")
