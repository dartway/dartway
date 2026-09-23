---
name: dartway-uploads
description: >-
  File uploads in a DartWay project (DartWay projects): a purpose in the shared enum
  (`with DwUploadPurpose`), its `DwUploadRule` on the server (visibility picks the public or the
  private bucket; maxBytes; contentTypes; canUpload), `DwFileStorage(canRead:)` for private files,
  a row that stores the file id (`@DwForeignKey('dw_stored_file')`) and a command that checks it with
  `ctx.files.requireOwned`, public URLs resolved in batch with `ctx.files.publicUrls`, private files
  read through `dw.files.getLink`, deletion with `ctx.files.delete`; the app side with
  `dw.uploader()` (progress, refusal, file) or `dw.files.upload`; local MinIO and `DW_STORAGE_*`
  (`DW_STORAGE_PROVISION`, the startup bucket check); tests with `DwTestStorage` on the server and
  `DwFakeStorage` in widget tests. Use when a feature needs a photo, a document or an attachment,
  when an upload is refused or fails, or when a file does not open by its URL.
---

# DartWay — file uploads (`dartway-uploads`)

**The bytes never pass through the app server.** An upload is three steps, and the framework does
all three:

1. the app sends `DwStartUpload` (purpose, name, content type, exact size); the server checks them
   against the purpose's rule and answers a ticket — a presigned `PUT` to storage for a key it builds
   itself (`<purpose>/<account>/<random>.<ext>`), signed for that exact size and type, refusing an
   overwrite;
2. the app puts the bytes straight to storage by that URL;
3. the app sends `DwFinishUpload`; the server checks what storage holds (size and type) and records
   the file as confirmed in the framework's `dw_stored_file` table.

What the project writes is everything around that: **what the file is for, who may upload it, who
may read it, and which row points at it.**

**The skeleton ships one purpose end to end — the profile photo.** Read it before adding one: the
purpose enum in `__SHARED_PKG__`, its rule and the storage configuration in `__SERVER_PKG__/lib/src/`,
the profile command that checks the file id and deletes the replaced photo, the mapper that turns
file ids into URLs, the photo picker on the profile page, the server acceptance test on real storage
and the widget test on a fake one.

---

## 1. The purpose — `__SHARED_PKG__`

A purpose is a value of the project's upload enum, mixed with `DwUploadPurpose`. It lives in the
contract because both sides name it: the app uploads *for* it, the server has a rule *for* it.

```dart
/// What an uploaded file is for. The server declares one rule per purpose.
enum AppUpload with DwUploadPurpose {
  /// A scanned invoice. Private: read only by its owner, through a link.
  invoiceScan;

  /// The server's rule and the app's picker read the same numbers, so a file
  /// the server would refuse is not sent.
  static const int invoiceScanMaxBytes = 10 * 1024 * 1024;
  static const Set<String> invoiceScanContentTypes = {
    'application/pdf',
    'image/jpeg',
    'image/png',
  };
}
```

- **The name is the first segment of every object key** and is stored with every file. It must be
  an identifier (letters, digits, `_`, starting with a letter), and **renaming a purpose that has
  files is a data change**: existing files keep the old name, stop matching `isFor`, and fail
  `requireOwned`. Add a new value instead, or migrate `dw_stored_file.purpose` in SQL.
- **Limits as shared constants**, read by both the rule and the app: the app can say "too large"
  before uploading, and the two numbers cannot part.
- **Content types are exact, lower-case MIME types without parameters** (`image/jpeg`). The app
  sends one of them; the rule compares exactly.

## 2. The rule — `__SERVER_PKG__`

One `DwUploadRule` per purpose, in the list the server's `DwFileStorage` is built with. The skeleton
keeps the list, the storage and its environment defaults in one file under `lib/src/`; add the rule
there.

```dart
DwUploadRule(
  AppUpload.invoiceScan,
  // Private: the private bucket, read only through a link after canRead.
  visibility: DwFileVisibility.private,
  maxBytes: AppUpload.invoiceScanMaxBytes,
  contentTypes: AppUpload.invoiceScanContentTypes,
  // Who may upload at all. Whether the file may go onto a particular invoice
  // is the command's check, not this one.
  canUpload: (ctx) async => true,
),
```

- **`visibility` is the whole decision about where a file goes, and it is required.**
  `DwFileVisibility.public` — the public bucket, a permanent URL anyone holding it can open
  (a profile photo, a product picture). `DwFileVisibility.private` — the private bucket, read only
  through a short presigned link after the read rule (documents, anything personal). Choose private
  unless the file is meant to be seen by whoever has the link.
- **`maxBytes` and `contentTypes` are enforced twice**: the start command refuses
  (`dw.uploadTooLarge` with `maxBytes`, `dw.uploadTypeRejected` with `allowed`), and both are signed
  into the URL, so storage refuses a lying client too.
- **`canUpload`** runs after the size and type checks, inside the start command's transaction;
  `false` refuses `dw.forbidden`. The caller is always signed in — every file belongs to an account.
  It answers "may this caller upload for this purpose at all", nothing finer: the file is not yet
  attached to anything.
- **A purpose without a rule refuses every upload** (`dw.uploadPurposeUnknown`) — the symptom of a
  rule forgotten, or of an app built against another server.

The server validates the declaration as it starts and refuses to start listing every problem: a
purpose name that is not an identifier, two rules for one purpose, a public rule without a public
bucket, a private one without a private bucket.

**Document the rule in a doc comment above it**: why public or private, who may upload and why.
That comment is where the next reader — and `dartway-finish` — looks for the rule's intent.

## 3. Who reads a private file — `canRead`

Private files are read with `DwGetFileLink`. The storage takes one read rule for all private
purposes:

```dart
DwFileStorage(config, rules: uploadRules, canRead: canReadFile);
```

- **Without `canRead`, only the account that uploaded a file may read it.** Often that is exactly
  right; write a rule only when others must read it (a manager, the other side of a conversation).
- **One function answers for every private purpose**, so branch on `file.isFor(AppUpload.…)` and
  end with the default for purposes it does not know:

```dart
/// A scanned invoice is readable by its owner while the invoice exists;
/// every other private file only by its uploader.
Future<bool> canReadFile(DwCallContext ctx, DwFileRecord file) async {
  if (file.isFor(AppUpload.invoiceScan)) {
    final accountId = ctx.accountId;
    if (accountId == null) return false;
    final invoice = await ctx.db.invoices.findFirst(
      where: (t) => t.scanFileId.equals(file.id),
    );
    return invoice != null && invoice.ownerAccountId == accountId;
  }
  return file.accountId == ctx.accountId;
}
```

A `false` answers `dw.forbidden` to a signed-in caller and `unauthenticated` to an anonymous one.
Public files are never asked: their URL is public anyway, so `canRead` is no protection for them —
if it has to be, the purpose is private.

`DwFileRecord` gives the rule what it decides on: `accountId` (the uploader), `purpose`,
`visibility`, `fileName`, `contentType`, `byteSize`, `createdAt`, `confirmedAt`.

## 4. The row stores the file id, and the command checks it

A project row references a confirmed file **by id**, never by URL: which URL a file has is decided
by the storage configuration, and a stored URL is wrong the day that changes.

```dart
/// The scan attached to the invoice. A file deleted from under it leaves the
/// invoice without a scan rather than failing the delete.
@DwForeignKey('dw_stored_file', onDelete: DwOnDelete.setNull)
final int? scanFileId;
```

`onDelete: DwOnDelete.setNull` for an optional file on a row that outlives it;
`DwOnDelete.cascade` for a row that *is* the attachment (a row per attached file). Then
`dart run dartway_cli:dartway generate` and a migration (`dartway-migrations`); `dw_stored_file` is the framework's table
and exists in every database.

**A file id arriving in a command is a number anyone can type.** Before writing it onto a row, check
it is the caller's own confirmed file of the expected purpose:

```dart
await ctx.files.requireOwned(
  command.scanFileId,
  AppUpload.invoiceScan,
  field: 'scanFileId',
);
```

It answers the `DwStoredFile`, or refuses `dw.fileNotOwned` on that field — deliberately the same
code for a file that is absent, someone else's, unfinished or of another purpose, so the caller
learns nothing about files that are not theirs. Skip it and one member can put another member's
private document on their own row and read it through the row's rules.

An optional file on an update command travels as `DwFieldPatch<int>` (keep / set / clear), as the
skeleton's profile photo does; check `requireOwned` only on `DwSetField`.

## 5. Showing files

**Public files: resolve URLs in batch, in the mapper that builds the data objects.**

```dart
final fileIds = {for (final row in rows) ?row.photoFileId};
final urls = fileIds.isEmpty
    ? const <int, String>{}
    : await ctx.files.publicUrls(fileIds);
// … photoUrl: urls[row.photoFileId]
```

One query for the whole list, never one per row. The answer holds only confirmed public files; a
private, unfinished or absent id is simply not in the map. Asking with no ids works on a server
without storage; asking with ids there throws `StateError` — hence the `isEmpty` guard.

The data object carries the URL (`String? photoUrl`), not the id: the app shows it with an ordinary
network image.

**Private files: the data object carries the id** (and what a list shows — name, size, type), and
the app asks for a link **when the file is about to be opened**:

```dart
final link = await dw.files.getLink(invoice.scanFileId!);
if (link case DwCallOk(:final value)) {
  // value.url, valid until value.expiresAt
}
```

A private link is short-lived (`DwFileStorage.linkLifetime`, ten minutes by default). Do not store
it, do not put it into a data object, and do not `ref.watch` a `DwGetFileLink` request — it would be
cached past its expiry. For a public file `getLink` answers its permanent URL without `expiresAt`.

## 6. Replacing and deleting

```dart
if (previous != null && previous != updated.scanFileId) {
  await ctx.files.delete(previous);
}
```

`ctx.files.delete` removes the `dw_stored_file` row **in the command's transaction** and the object
**after the commit**, by a framework job retried until storage confirms. So a rolled-back command
deletes nothing, and a crash after the commit does not leave the object behind. It throws in a
request (reads have no side effects), and answers whether the file existed.

**Delete the file a command replaces or clears**; otherwise it stays in the bucket for ever, owned
by nobody. The foreign key's `onDelete` decides what happens to rows still pointing at it.

**A file uploaded and then abandoned** — a page left without saving — is confirmed and held by no
row, and no framework cleanup takes it: the framework does not know which rows reference a file.
When the flow allows it, give the app a command that releases it: `requireOwned` (it is the
caller's), check that no row holds it, then `ctx.files.delete`.

**Name, size or type of files a list shows** (`intro.mp4 · 894 MB`): `ctx.files.describe(fileIds)`,
one query for the page — never read `dw_stored_file` with SQL; its columns are the framework's.

**The server works on a file itself with `ctx.files.read(fileId)`, `ctx.files.readLink(fileId)` and
`ctx.files.store(purpose, accountId:, bytes:, contentType:, fileName:)`** — a model reading a private
photo, a generated image kept for its owner. They ask no `canRead`/`canUpload`: the server is the
reader and the writer. **Never make a file public so that server code can reach it** — health data,
documents and photos stay private and are read this way. Never pass what `read` or `readLink` answers
to a caller who may not read the file.

**Unfinished uploads clean themselves up**: a ticket never finished is removed with its object by a
framework job after `ticketLifetime` + `uploadGrace` (fifteen minutes each by default). An account
holding `maxPendingUploads` (ten) unfinished uploads is refused `dw.tooManyRequests` until one expires.

## 7. The app — `__FLUTTER_PKG__`

**For a screen, `dw.uploader()`** — one upload slot, a `ValueListenable<DwUploadState>`:

```dart
final uploader = useMemoized(dw.uploader);
useEffect(() => uploader.dispose, [uploader]);
final upload = useValueListenable(uploader);

// in the action:
final file = await uploader.upload(
  AppUpload.invoiceScan,
  DwUploadSource.bytes(bytes),
  fileName: pickedName,
  contentType: pickedContentType,
);
if (file == null) return null; // the state holds the refusal or the error
return dw.command(AttachInvoiceScan(invoiceId: invoiceId, scanFileId: file.id));
```

(Without hooks: create it in `initState`, dispose it in `dispose`.)

- **States**: `DwUploadIdle` → `DwUploadProgress(sentBytes, totalBytes)` (`fraction` for a
  progress bar) → `DwUploadDone(file)` or `DwUploadError(error)`. Render them with a switch; a
  second `upload` while one runs throws `StateError`, so disable the trigger while
  `upload is DwUploadProgress`.
- **A refusal is shown, not reported**: `DwUploadError.refusal` is non-null when the server said no;
  render it through the app's refusal text like any other code. The app's refusal text must cover
  `DwUploadRefusal` (the skeleton's switch over the framework's enums already does, and its test
  fails when a code has no text).
- **Failures worth an operator are reported for you**: a server failure, storage rejecting the put
  (a misconfigured bucket), an unexpected error go to the app's error reporting; a refusal, a
  signed-out caller and a network that is down stay in the state.
- **Upload, then reference.** The upload gives a `DwStoredFile`; a project command puts its id onto
  a row. Both belong in one `dw.action`, so the button shows one busy state and one notification.
- **Picking the file is the app's**: the framework carries no picker plugin. Take the content type
  from the picker (fall back to the extension), and check the size against the shared constant
  before uploading when the picker can say it.
- **A user who changes their mind**: `uploader.cancel()` aborts the transfer and confirms nothing;
  `upload` answers `null` and the state is `DwUploadIdle` again. The server's cleanup takes the
  unfinished ticket and its bytes. Offer it on any upload large enough to watch; `dispose()` does
  not cancel.
- **Retries are built in**: the put is retried after network failures, stalls and storage's
  transient answers for as long as the ticket is valid; an attempt whose answer was lost is
  recognised on the retry. Do not wrap it in a retry of your own.

**Outside a screen** (a queue, a share extension): `dw.files.upload(purpose, source, fileName:,
contentType:, onProgress:)` answers a `DwCallResult<DwStoredFile>`.

`DwUploadSource.bytes(bytes)` for what is in memory; `DwUploadSource.stream(...)` for a large file,
with an `open` callback that returns a **fresh** stream on every call — a retry starts from the first
byte.

---

## 8. Storage locally — MinIO and `DW_STORAGE_*`

`docker compose up -d` in `__SERVER_PKG__` starts MinIO beside Postgres: the S3 API on
`127.0.0.1:8100`, its web console on `8101` (the root user and password are in
`docker-compose.yaml`). The server reads its storage from the environment (`dartway-run` has the
whole environment):

| Variable | Meaning |
|---|---|
| `DW_STORAGE_ENDPOINT` | The S3 API. **Unset: the server runs without uploads** — framework file calls fail as incidents, `ctx.files` throws `StateError` |
| `DW_STORAGE_ACCESS_KEY`, `DW_STORAGE_SECRET_KEY` | Required with the endpoint |
| `DW_STORAGE_PUBLIC_BUCKET`, `DW_STORAGE_PRIVATE_BUCKET` | Bucket names; the skeleton defaults them to names derived from the project |
| `DW_STORAGE_PUBLIC_BASE_URL` | Where public files are served from; the skeleton defaults it to `<endpoint>/<public bucket>` (path style) |
| `DW_STORAGE_REGION`, `DW_STORAGE_PATH_STYLE` | `us-east-1` and path style by default — what MinIO serves |
| `DW_STORAGE_VERIFY_BUCKETS` | The startup check, on by default |
| `DW_STORAGE_PROVISION=true` | The skeleton's `bin/server.dart` creates both buckets and sets their access before starting (`DwFileStorageSetup.provision`). **For a storage the project owns only** — it deletes the private bucket's policy |

**The server checks the buckets before it serves**, and refuses to start on any mismatch: each bucket
exists and accepts the keys, an object of the public bucket reads anonymously at the public base URL,
an object of the private bucket does not, and neither bucket can be listed anonymously. A private
file behind a public bucket is already leaked, so this is not a warning. The refusal names the bucket
and what answered what.

**Traps:**

- **The endpoint must be reachable from the client, not only from the server.** The app puts bytes
  to the presigned URL and opens public URLs itself, and the host is part of the signature, so it
  cannot be rewritten on the way. `http://127.0.0.1:8100` works for a desktop app, a browser and the
  iOS simulator on the same machine; an Android emulator or a phone cannot reach it. For those, set
  `DW_STORAGE_ENDPOINT` to an address both the server and the device reach (the machine's LAN
  address) and restart the server.
- **A browser uploads cross-origin**, so both buckets' CORS configuration must allow `PUT` from the
  app's origin with the headers `content-type` and `if-none-match`. A storage somebody else
  administers needs this set by hand.
- **MinIO not running while `DW_STORAGE_ENDPOINT` is set** fails the startup check ("could not be
  checked at …"): start `docker compose`, or unset the endpoint to run without uploads.
- **A deployed storage the server reaches only through something that starts after it** cannot be
  probed at startup; that is the one case for `DW_STORAGE_VERIFY_BUCKETS=false`, with the same check
  run from outside afterwards.

Never print the storage keys, and never log an upload URL or a private link: each is a credential
for one object.

---

## 9. Tests

The level follows the behaviour (`dartway-testing`).

**The rules — server acceptance on real storage.** `dart run dartway_cli:dartway test` starts a MinIO for the run and
passes `DW_STORAGE_ENDPOINT` / `_ACCESS_KEY` / `_SECRET_KEY`; each test file provisions its own pair
of buckets:

```dart
late DwTestStorage storage;

setUpAll(() async {
  storage = await DwTestStorage.create(prefix: 'invoice-test');
  // build the server with storage.config, start it with DwTestServer.start
});
tearDownAll(() async {
  // stop the server first, then:
  await storage.drop();
});
```

`storage.config` has both buckets and the startup check on, so the server under test verifies them
as in production. What deserves a test: the file lands in the bucket its visibility names
(`storage.keys(storage.publicBucket)` / `privateBucket`); another member's file id is refused
`DwUploadRefusal.notOwned`; a type or size outside the rule is refused before storage sees it; a
private file's link is refused to someone `canRead` says no to (`client.files.getLink`); a replaced
file disappears — call `wakeJobs()` on the test server after the command and wait until an anonymous
`GET` of its URL stops answering `200`, because deletion runs in a job after the commit. Upload with
the real client (`client.files.upload`) — the three steps are the framework's and are exercised for
free.

**The screen — a widget test on `DwFakeStorage`.** It stands beside the fake server, answers the
framework's file calls and stores puts in memory:

```dart
final storage = DwFakeStorage(fakeServer);
// build the test core with storageTransport: storage.transport
```

- what was uploaded: `storage.files` (confirmed `DwStoredFile`s), `storage.objects`, `storage.puts`;
  what the app asked: `fakeServer.callsOf<DwStartUpload>()`;
- a refusal: `storage.refuseStart = (command) => DwCallRefusal(DwUploadRefusal.tooLarge, field: 'byteSize')`,
  then assert the refusal text is on screen and no project command was sent;
- the network: `failPuts`, `loseAnswers`, `answerStatuses`, `chunkDelay` (to watch progress);
- the picker is a platform plugin: replace its platform interface instance in the test, as the
  skeleton's profile test does.

## Checklist

- [ ] The purpose is a value of the shared upload enum; its limits are shared constants.
- [ ] One `DwUploadRule`, with a doc comment: visibility chosen on purpose, `maxBytes`,
      `contentTypes`, `canUpload`.
- [ ] A private purpose: `canRead` answers for it, or "only the uploader" is what is wanted.
- [ ] The row stores the id with `@DwForeignKey('dw_stored_file', onDelete: …)`; migration written.
- [ ] Every command taking a file id calls `ctx.files.requireOwned` with the purpose and the field.
- [ ] Public URLs resolved in one `publicUrls` call per batch; private files opened through `getLink`
      at the moment of opening; no URL stored on a row.
- [ ] A replaced or cleared file is deleted with `ctx.files.delete`.
- [ ] The app renders `DwUploadError.refusal` through the refusal text; the trigger is disabled
      while uploading; the uploader is disposed.
- [ ] Server acceptance on `DwTestStorage` for the rules; widget test on `DwFakeStorage` for the screen.
