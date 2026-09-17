# Changelog

## 0.20.0-dev.1

The rewrite (see docs/1.0).

- **`DwAppClient.listen(channels)`**: a stream of what is published to the channels, without reading anything. Subscribed while listened to, shared with watched requests on the same channel, caller channels following a switch of account; nothing replayed across a disconnect (D-067).

- **Updates are routed by channel (D-036).** An object from a response or the
  live socket is applied only to entries whose request declares the channel it
  was published to — an entry on several of them absorbs it once. A request
  without channels hears no updates at all. The fake server carries its
  response transport by channel and, like the real server, honours a named
  live connection only for the caller's own account, looked up after the
  handler.
- **Caller channels are resolved per account (D-037):** an entry subscribes to
  `kind:<accountId>` for `DwLiveChannel.ofCaller(kind)`; signed out, it has no
  such channel.
- **A table page never inserts:** an upsert of an object not on the page reads
  the page again (coalesced), as a removal does.
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
