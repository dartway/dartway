---
name: dartway-uploads
description: >-
  File uploads: a purpose in the shared enum, its DwUploadRule (visibility → public or private bucket,
  maxBytes, contentTypes, canUpload), canRead for private files, a row storing the file id checked
  with ctx.files.requireOwned, URLs in batch with publicUrls, private links with dw.files.getLink,
  deletion, server-side reads and writes, dw.uploader() in the app, local storage and DW_STORAGE_*,
  and the tests on DwTestStorage and DwFakeStorage. Use when a feature needs a photo, a document or
  an attachment, when an upload is refused or fails, or when a file does not open.
---

# DartWay — file uploads (`dartway-uploads`)

**The bytes never pass through the app server**: the app sends `DwStartUpload`, puts the bytes to a
presigned URL for a key the server built, and sends `DwFinishUpload`; the server records the confirmed
file in `dw_stored_file`. The project writes **what the file is for, who may upload and read it, and
which row points at it**. The skeleton's profile photo is the worked case, end to end: the purpose in
`__SHARED_PKG__/lib/src/<prefix>_upload.dart`, the rule in
`__SERVER_PKG__/lib/src/profile/profile_access.dart`, the command and the mapper in `profile_handlers.dart`
and `profile_objects.dart`, the picker in
`__FLUTTER_PKG__/lib/app/profile/profile_page/widgets/avatar_picker.dart`, and the tests.

## 1. The purpose and its rule

A value of the project's upload enum (`dartway-contract`), its limits as constants on the enum so the
app's picker and the server's rule read the same numbers. The name is the first segment of every object
key: renaming a purpose that has files is a data change — add a value instead. Content types are exact
lower-case MIME types.

One `DwUploadRule` per purpose, in the `_access.dart` of the feature it belongs to, handed to
`DwFileStorage` by the server's library (`core/` imports no feature), with a doc comment saying why:

- **`visibility`** decides the bucket: `DwFileVisibility.public` — a permanent URL for whoever holds it
  (a profile photo); `.private` — a short link after `canRead` (documents, anything personal). Private
  unless the file is meant to be seen by anyone with the link.
- `maxBytes` and `contentTypes` are enforced at the start command and signed into the URL.
- `canUpload(ctx)` — may this caller upload for this purpose at all; the file is attached to nothing
  yet. A purpose without a rule refuses every upload; the server refuses to start on an inconsistent
  declaration.

**`canRead`** — `DwFileStorage(config, rules:, canRead:)` — one function for every private purpose;
without it only the uploader reads a file. A feature answers for its purpose in its `_access.dart`
(a membership through `ctx.membershipOf`, `dartway-access`), `null` for others, and the library's
`canReadFile` asks each, then falls back to the uploader — as the example does:
[`chat_access.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_server/lib/src/chat/chat_access.dart)
(`ChatAttachments.canRead`, branching on `file.isFor(…)`) and `canReadFile` in
[`dartway_example_server.dart`](https://github.com/dartway/dartway/blob/master/example/dartway_example_server/lib/dartway_example_server.dart).
Public files are never asked.

## 2. The row, the command, showing it

- A row references a file **by id** — `@DwForeignKey('dw_stored_file', onDelete: DwOnDelete.setNull)`
  for an optional file, `cascade` for a row that is the attachment — never by URL.
- **A file id in a command is a number anyone can type**: before writing it,
  `await ctx.files.requireOwned(command.scanFileId, AcmeUpload.invoiceScan, field: 'scanFileId')` — the
  caller's own confirmed file of that purpose, else `dw.fileNotOwned`. On a `DwFieldPatch<int>`, only for
  a new value.
- **Public URLs in batch**, in the `_objects` mapper: `ctx.files.publicUrls(fileIds)` once per list
  (guard the empty set); the data object carries the URL. **Private files**: the data object carries the
  id; the app asks `dw.files.getLink(id)` when opening, inside `dw.action` — never stored, never watched.
  Names and sizes for a list: `ctx.files.describe(fileIds)` — never SQL on `dw_stored_file`.
- **A replaced or cleared file is deleted**: `ctx.files.delete(previous)` — the row in the command's
  transaction, the object by a job after commit. `delete` and `store` run in a command, a job or a hook;
  in a request they throw. A file uploaded and abandoned stays until a command of
  the project releases it (`requireOwned`, no row holds it, `delete`).
- The server works on a file itself with `ctx.files.read`, `readLink` and `store(purpose, accountId:,
  bytes:, contentType:, fileName:)` — no rule asked. Never make a file public so server code can reach it,
  and never pass what `read` or `readLink` answer to a caller who may not read the file.

## 3. The app

`dw.uploader()` is one upload slot, a `ValueListenable<DwUploadState>`, held in hooks:

```dart
final uploader = useMemoized(dw.uploader);
useEffect(() => uploader.dispose, [uploader]);
final upload = useValueListenable(uploader);
```

In the feature's `logic/` function the button's `dw.action` runs, upload then reference — one busy state,
one notification:

```dart
final file = await uploader.upload(AcmeUpload.invoiceScan, DwUploadSource.bytes(bytes),
    fileName: pickedName, contentType: pickedContentType);
if (file == null) return null; // the state holds the refusal or the error
return dw.command(AttachInvoiceScan(invoiceId: invoiceId, scanFileId: file.id));
```

States: `DwUploadIdle` → `DwUploadProgress` (`fraction`) → `DwUploadDone` or `DwUploadError`; disable the
trigger while uploading. `DwUploadError.refusal` is shown through the refusal text; failures are reported
for you. `uploader.cancel()` aborts — offer it on any upload large enough to watch; `dispose()` does
not cancel. Retries are built in; never wrap them in your own. The picker is the app's: take the content type
from it and check the size first. Outside a screen: `dw.files.upload(…)`. A large file is
`DwUploadSource.stream(() => file.openRead(), byteSize: size)` — the function returns a fresh stream on
every call, since a retry starts from the first byte.

## 4. Storage locally

`docker compose up -d` in `__SERVER_PKG__` starts RustFS (S3 on `127.0.0.1:8100`, console `8101`).
`DW_STORAGE_ENDPOINT` unset: the server runs without uploads. `DW_STORAGE_PROVISION=true` creates and
configures both buckets — only on a storage the project owns. The server probes the buckets at start and
refuses on any mismatch; never loosen the probe (`DW_STORAGE_VERIFY_BUCKETS=false` only for a deployed
storage reachable only through something that starts after the server, checked from outside instead). The endpoint must be reachable **from the device** (it
is signed into every URL): a phone or an Android emulator needs the machine's LAN address. A browser
uploads cross-origin: the buckets' CORS allows `PUT` with `content-type` and `if-none-match`. Never log
a key, an upload URL or a private link.

## 5. Tests

- **Server** (`dartway-testing`): `DwTestStorage.create(prefix:)` per file, `storage.config` into the
  server factory, `storage.drop()` after stopping; upload with the real client (`client.files.upload`). Test that the file lands in its visibility's bucket
  (`storage.keys(…)`), another member's id is refused, a type or size outside the rule is refused, a
  private link is refused where `canRead` says no, and a replaced file disappears (`wakeJobs()`, then
  wait for its URL to stop answering `200`).
- **Screen**: `DwFakeStorage(fakeServer)`, its `transport` handed to the core's `storageTransport:`; `storage.files`, `puts`;
  `refuseStart` for a refusal; `failPuts`, `loseAnswers`, `chunkDelay` for the network; replace the
  picker's platform interface as the skeleton's profile page test does.
