# How does the app upload a file?

A photo is megabytes, and a phone network drops in the middle of it. Sending those bytes through the
app server ties up a request for the whole upload and puts the server's memory between the phone and
the storage. DartWay sends them **straight to storage**, and the app server only decides who may
upload what and confirms what arrived.

This page is the client side. What the server declares — upload rules per purpose, sizes, types,
public or private — is [uploads on the server](../4-server/uploads.md).

## The three steps, and why you see one

`dw.files.upload(...)` does all three:

1. **Ticket.** The client sends `DwStartUpload` with the purpose, file name, content type and exact
   byte size. The server checks them against the purpose's rule and answers a `DwUploadTicket` — a
   presigned URL signed for exactly that length and type.
2. **Put.** The client `PUT`s the bytes to that URL. The app server is not involved.
3. **Confirm.** The client sends `DwFinishUpload`; the server checks what storage holds and answers
   the `DwStoredFile`.

A project command then references the file **by id** — the template's avatar is
`UpdateMyProfile(avatarFileId: DwFieldPatch.set(file.id))`. A row never stores a URL; the storage
configuration decides it.

The purpose is an enum in the project's shared package, `with DwUploadPurpose` — the example's
`ExampleUpload { avatar, chatAttachment }`, a public and a private one. Picking a
file is the app's business: the framework carries no picker plugin, and takes bytes or a stream.

## `dw.files`: the client

`dw.files` is the `DwFileClient` of the core's client.

```dart
final result = await dw.files.upload(
  ExampleUpload.chatAttachment,
  DwUploadSource.bytes(bytes),
  fileName: name,
  contentType: contentType,
  onProgress: (sent, total) => update(
    (file) => file.copyWith(progress: total == 0 ? 1 : sent / total),
  ),
); // DwCallResult<DwStoredFile>
```

(From `example/dartway_example_flutter/lib/app/chat/widgets/chat_composer.dart`.)

- **`DwUploadSource.bytes(bytes)`** for bytes in memory — what a picker hands over for a photo.
  **`DwUploadSource.stream(open, byteSize: n)`** for a stream: `open` must return a *fresh* stream
  every time, because a retry starts from the first byte. A source that yields another number of bytes
  than its `byteSize` throws `StateError` — the caller's bug, not retried.
- **The server's refusals come back as `DwCallRefused`**, as every refusal does: the ticket's
  (`DwUploadRefusal.purposeUnknown`, `tooLarge` with `maxBytes`, `typeRejected` with `allowed`, a
  caller who may not upload) and the confirmation's (`missing`, `mismatch`, `expired`).
- **The put retries on its own** with backoff after network failures, stalls (no progress for
  `callTimeout`) and storage's transient answers (`408`, `429`, `5xx`), for as long as the ticket is
  valid. An attempt whose bytes arrived while the answer was lost is recognised on the retry — storage
  refuses to overwrite the object (`412`) — and the upload goes on to confirmation.
- **When the bytes cannot be delivered, the future throws `DwUploadException`** with a
  `DwUploadFailure`: `unreachable` (the network, until the ticket expired — nothing is wrong with the
  file), `rejected` (storage refused: a misconfigured bucket, CORS, keys — carries `status` and S3's
  `storageCode`), `expired` (the ticket ran out mid-upload; a new upload gets a new ticket).
- **`onProgress(sent, total)`** is called with `(0, total)` when an attempt begins (again after a
  retry), about a hundred times per attempt at most, and `(total, total)` once storage has the file,
  before the confirmation.

### Reading a file: `getLink`

```dart
// example/dartway_example_flutter/lib/app/chat/widgets/chat_attachments_view.dart
final link = await dw.files.getLink(file.id);
if (link case DwCallOk(:final value)) {
  // value.url
}
```

`getLink(fileId)` answers a `DwFileLink`: the permanent URL of a public file (no `expiresAt`), or a
short-lived presigned one for a private file. **Fetch it when the file is about to be shown**, do not
store or watch it — a private link expires, and it is a credential. A public `DwStoredFile` also carries
its `url` directly; a private one has `url == null`.

## `dw.uploader()`: an upload slot for a screen

An avatar picker needs more than a future: progress for a ring, the refusal for a caption, a flag that
blocks a second pick. `dw.uploader()` returns a `DwUploadNotifier` — a `ValueNotifier<DwUploadState>`
the screen owns and disposes.

| State | Means |
|---|---|
| `DwUploadIdle` | Nothing uploading: before the first upload, or after `reset()`. |
| `DwUploadProgress(sentBytes, totalBytes)` | Uploading; `fraction` for a progress bar. Starts at zero while the ticket is asked for, stays at the total while the server confirms. |
| `DwUploadDone(file)` | Uploaded and confirmed. |
| `DwUploadError(error)` | Ended without a file. `error` is typed: `DwRefusalException`, `DwNotAuthenticatedException`, `DwFailedException`, `DwTimeoutException` or `DwUploadException`; `refusal` is the refusal when the server refused. |

`upload(purpose, source, fileName:, contentType:)` answers the `DwStoredFile`, or `null` when it ended in
`DwUploadError` — the state says why. A second `upload` while one runs throws `StateError` (`isBusy`
tells you first). An upload still running when the screen is disposed finishes on its own; its states
are no longer published.

**`cancel()` stops the running upload**: the transfer is aborted, nothing is confirmed, `upload`
answers `null` and the state goes back to `DwUploadIdle` — nothing is reported. The ticket stays
unfinished, and the server's cleanup removes it with whatever bytes arrived, so a user who changes
their mind about a gigabyte does not leave it in the bucket. Once the confirmation is sent the file is
theirs, and `cancel()` changes nothing. `dispose()` does not cancel: a screen that wants its upload
gone with it calls `cancel()` first. Underneath, `client.files.upload(cancel:)` takes a future that
ends the upload when it completes, with `DwUploadCancelledException`.

**What goes to error reporting, and what stays on screen.** The notifier created by `dw.uploader()`
reports to the app's error pipeline (`DwErrorSource.client`) only what an operator must see: a server
failure, storage **rejecting** an upload (`DwUploadFailure.rejected` — a bucket misconfiguration), or an
unexpected error. A refusal, a signed-out caller, a network that is down or a ticket that expired stay in
the state for the screen to show. A refused avatar is the user's problem to fix; a rejected put is ours.

### The skeleton's avatar picker

`template/dartway_starter_flutter/lib/app/profile/profile_page/widgets/avatar_picker.dart`, in full
shape:

```dart
final uploader = useMemoized(dw.uploader);
useEffect(() => uploader.dispose, [uploader]);
final upload = useValueListenable(uploader);

Future<DwCallResult<UserProfile>?> pickAndUpload() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery, /* ... */);
  if (picked == null) return null; // dismissed: not a failure
  final bytes = await picked.readAsBytes();
  final file = await uploader.upload(
    DartwayStarterUpload.avatar,
    DwUploadSource.bytes(bytes),
    fileName: picked.name.isEmpty ? 'avatar' : picked.name,
    contentType: _contentTypeOf(picked),
  );
  if (file == null) return null; // the uploader holds the refusal or the error
  return dw.command(UpdateMyProfile(avatarFileId: DwFieldPatch.set(file.id)));
}
```

and renders the state:

```dart
AppText.caption(switch (upload) {
  DwUploadError(:final refusal?) => refusalText(l10n, refusal),
  DwUploadError() => l10n.refusalUploadFailed,
  _ => l10n.profilePhotoHint,
}, textAlign: TextAlign.center),
```

What the pattern shows:

- **the upload runs inside `dw.action`** behind a `DwActionBuilder` — the second tap is blocked, and the
  profile command's own refusal or failure is handled like any action's;
- **the upload's refusal is rendered by the same `refusalText`** the actions use, under the photo, where
  the person is looking — `DwUploadRefusal.tooLarge` reads its `maxBytes`;
- **a content type the purpose does not take is the server's to refuse**; the picker only guesses it from
  the picked file, and the refusal appears under the photo.

## Related

- [Uploads on the server](../4-server/uploads.md) — purposes, rules, buckets, visibility.
- [Actions and refusal texts](actions-and-refusal-texts.md) — `refusalText` and the upload codes.
- The `dartway-uploads` skill — adding an upload purpose end to end.
