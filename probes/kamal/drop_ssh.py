#!/usr/bin/env python3
"""Drop this probe CLI's SSH child after its build step starts."""
import argparse
import json
import os
import signal
import subprocess
import time
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('pid', type=int)
parser.add_argument('events', type=Path)
parser.add_argument('record', type=Path)
args = parser.parse_args()
end = time.monotonic() + 120
while time.monotonic() < end:
    events = args.events.read_text().splitlines() if args.events.exists() else []
    if any('"event":"step_started"' in event and '"id":"build"' in event
           for event in events):
        time.sleep(3)
        rows = [line.strip().split(None, 2) for line in subprocess.check_output(
            ['ps', '-axo', 'pid=,ppid=,command='], text=True).splitlines()]
        descendants = {args.pid}
        for _ in range(10):
            descendants |= {int(pid) for pid, parent, _ in rows if int(parent) in descendants}
        victims = [int(pid) for pid, _, command in rows
                   if int(pid) in descendants and command.startswith('ssh ')
                   and '82.26.151.195' in command]
        for pid in victims:
            os.kill(pid, signal.SIGKILL)
        args.record.write_text(json.dumps({'ssh_processes_killed': len(victims),
                                          'unix_seconds': time.time()}) + '\n')
        raise SystemExit(0 if victims else 1)
    time.sleep(0.2)
raise SystemExit('No build step observed; no process was killed.')
