#!/usr/bin/env python3
"""Measure one deploy and a one-request-per-second external health loop."""
import argparse
import csv
import json
import subprocess
import threading
import time
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("name")
parser.add_argument("--url", action="append", default=[])
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("command", nargs=argparse.REMAINDER)
args = parser.parse_args()
command = args.command[1:] if args.command[:1] == ["--"] else args.command
args.output.mkdir(parents=True, exist_ok=True)
stop = threading.Event()
counts = {}


def sample(url, index):
    rows = []
    with (args.output / f"{args.name}.curl-{index}.csv").open("w") as stream:
        writer = csv.writer(stream)
        writer.writerow(["unix_seconds", "http_status", "curl_exit", "elapsed"])
        next_sample = time.monotonic()
        while not stop.is_set():
            started = time.monotonic()
            result = subprocess.run(
                ["curl", "--silent", "--show-error", "--max-time", "0.9",
                 "--output", "/dev/null", "--write-out", "%{http_code}", url],
                capture_output=True, text=True,
            )
            row = [time.time(), result.stdout, result.returncode,
                   time.monotonic() - started]
            rows.append(row)
            writer.writerow(row)
            stream.flush()
            next_sample += 1
            stop.wait(max(0, next_sample - time.monotonic()))
    counts[url] = {
        "requests": len(rows),
        "failures": sum(row[1] != "200" or row[2] != 0 for row in rows),
        "failure_timestamps": [row[0] for row in rows if row[1] != "200" or row[2]],
    }


threads = [threading.Thread(target=sample, args=(url, index))
           for index, url in enumerate(args.url)]
for thread in threads:
    thread.start()
started_at = time.time()
started = time.monotonic()
with (args.output / f"{args.name}.stdout").open("w") as stdout:
    with (args.output / f"{args.name}.stderr").open("w") as stderr:
        result = subprocess.run(command, stdout=stdout, stderr=stderr)
elapsed = time.monotonic() - started
stop.wait(3)
stop.set()
for thread in threads:
    thread.join()
report = {"command": command, "exit": result.returncode,
          "seconds": elapsed, "started_at": started_at, "finished_at": time.time(), "loops": counts}
(args.output / f"{args.name}.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report))
raise SystemExit(result.returncode)
