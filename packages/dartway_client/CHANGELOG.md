# Changelog

## 0.21.0-dev.4

- Nothing changed here; the family moves in lockstep with `dartway_core_server`.

## 0.21.0-dev.3

- Nothing changed here; the family moves in lockstep with `dartway_core_server`.

## 0.21.0-dev.2

- Nothing changed here; the family moves in lockstep with `dartway_core_server` (#310, D-087).

## 0.21.0-dev.1

- **A browser upload no longer stalls and restarts on a large file** (#309). `DwAppClient` picks `XMLHttpRequest` for storage puts on the web by default now — `fetch` (still `DwHttpStorageTransport`'s implementation, still the default off the web) reads the whole request body before sending it, so its progress jumped to the end immediately and the client's stall watchdog, seeing nothing more, aborted a transfer that was still going. `DwStoragePut` gained `reportSent`, the seam a transport uses to report bytes actually reaching the network separately from reading its body; existing custom transports need no change — before the first call, progress still comes from reading the body, exactly as before this existed. `DwXhrStorageTransport` calls `reportSent(0)` before it reads anything, since it too has to read the whole body into memory before it can send it (a browser cannot stream a request body into `XMLHttpRequest`) — without that call the read itself would still read as progress, the same jump-to-the-end this exists to fix, just from the fallback path instead of from `fetch`. See D-088 for the fuller account, including a first version of the fix that made a silent, fully-accepted-but-never-answered connection *worse* on `dart:io`, caught in review before merging.

## 0.20.0

- First publication of the rewrite to pub.dev.

## 0.20.0-dev.4

- `DwFakeServer` answers a malformed `Dw-Contract-Version` as the real server does — a malformed call (`400`), and a `protocolError` close on the socket — rather than as an old app.
- **Calls and the live socket carry the contract version** of the protocol the client is built with (#296). **BREAKING (testing):** `DwFakeServer.minAppBuild` is `DwFakeServer.contractVersion` — set a newer breaking line to play a server that moved on. Migration note: `docs/migrations/2026-09-24-contract-version.md`.

## 0.20.0-dev.3

- Nothing changed here; the family moves in lockstep with `dartway_core_flutter`.

## 0.20.0-dev.2

- **An upload can be cancelled** (#284): `files.upload(cancel:)` takes a future; when it completes before the confirmation is sent, the put is aborted — mid-transfer, before the ticket answers, or during the wait before a retry — nothing is confirmed, and the upload ends with `DwUploadCancelledException`. The ticket stays unfinished, and the server's cleanup removes it with whatever bytes arrived: a cancelled gigabyte no longer finishes on its own and stays in the bucket.

## 0.20.0-dev.1

The rewrite (see docs/1.0).

- **`DwAppClient.deleteAccount()`**: sends `DwDeleteMyAccount` and ends the session once the server confirms (D-072).

- **A value newer than the build puts the client out of date** (D-071): an enum name the build does not know, in a call result, a watched request or a live update, switches the client to `dw.updateRequired` — the update screen — instead of failing the call or the list.

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
