---
title: Run server commands through the process seam
affects:
  dartway_cli: "0.26.0"
  dartway_core_server: "0.23.0"
---

## Who is affected

Projects using `Process.run`, `Process.runSync`, `Process.start`, `package:process`
or `package:process_run` in server `lib/`, or implementing `DwCallContext`.

## What to change

Replace direct execution with `await ctx.process.run(executable, arguments)`. Pass the context
to provider code rather than constructing a process runner. The seam returns a
`DwProcessResult` with `exitCode`, `stdout` and `stderr`, bounds time and output, and does
not expose streaming stdin or detached children. Move lifecycle orchestration requiring
those capabilities to a standalone tool outside server `lib/`.

A custom `DwCallContext` implementation must also expose `process`, delegated to the
server context. Tests should use `DwTestServer` rather than implement their own context.

Replace handwritten external-command fakes with `DwSeamCassette` under `test/cassettes/`
attached through `server.process.useCassette`. Record with `DW_RECORD_SEAMS=1`, review the
redaction, commit, and replay offline. HTTP integrations can adopt the same mechanism through
`server.http.useCassette`. Add the skeleton's optional `seam-drift.yml` workflow if desired.

## How to check

Run `dartway check`: `forbiddenProcessRun` has no errors. Run the server's acceptance tests
without record or verify flags: unexpected external calls must fail instead of executing.
