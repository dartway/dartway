# Changelog

## 0.20.0-dev.1

The rewrite (see docs/1.0).

- **`client.files`** (`DwFileClient`): `upload(purpose, DwUploadSource.bytes(...)
  | DwUploadSource.stream(open, byteSize:), fileName:, contentType:,
  onProgress:)` → `DwCallResult<DwStoredFile>` — ticket, a streamed PUT straight
  to storage, confirmation; `getLink(fileId)`. The PUT is retried after
  network failures, stalls (no progress for `callTimeout`) and `408`/`429`/`5xx`
  while the ticket is valid; a retry meeting `412` knows an earlier attempt
  arrived and goes on to confirm. Bytes that cannot be delivered end in
  `DwUploadException` (`unreachable`, `rejected`, `expired`); a source yielding
  another length than declared is a `StateError`, not retried. Progress is
  reported per hundredth of the file, and — in a browser, whose fetch reads the
  body first — jumps to the end before the transfer.
- `DwStorageTransport` (seam) with `DwHttpStorageTransport` (`package:http`,
  abortable) and `DwMemoryStorageTransport`; `DwAppClient(storageTransport:)`.
- `testing.dart`: `DwFakeStorage` — the file calls on a `DwFakeServer` and an
  in-memory storage holding puts to their ticket, with knobs for failed puts,
  lost answers, storage statuses and slow reads. `DwFakeServer.newClient`
  takes `storageTransport`.
