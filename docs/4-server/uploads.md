# Uploads: how does a file get from a phone into storage, safely?

**The bytes never pass through the app server.** The client asks the server for a place to upload
one file, sends the bytes straight to S3-compatible storage with a presigned `PUT`, and tells the
server it is done. The server names every object, binds the size and type into the upload's
signature, checks what arrived, and records the file. A project row stores a file id, never a URL.

Every rule here closes a way uploads go wrong: a client naming the key (and overwriting someone
else's file), everything public-read, reservations piling up without end, an object that never
arrived crashing the confirmation (D-034).

## The flow

1. **`DwStartUpload(purpose, fileName, contentType, byteSize)`** — a signed-in command. The server
   finds the purpose's rule, checks the size and type against it, runs its `canUpload`, checks the
   account's pending uploads, builds the key `<purpose>/<account>/<192 random bits>.<ext>` in the
   bucket of the rule's visibility, records an unconfirmed `dw_stored_file` row and answers a
   **`DwUploadTicket`**: `id`, `uploadUrl`, `headers`, `expiresAt`.
2. **`PUT uploadUrl`** with exactly `headers` and the bytes, before `expiresAt`. The signature
   covers the exact length, the content type and `if-none-match: *`, so storage refuses a body of
   another size or type, and the URL can never overwrite an object — not by a second upload of the
   same ticket, not after the file was confirmed. A retry of an upload that did arrive answers
   `412`, which the client reads as "already stored".
3. **`DwFinishUpload(ticketId)`** — only the uploading account; someone else's ticket reads as
   `dw.notFound`. The server locks the row, checks expiry, asks storage for the object by `HEAD`
   and compares size and type with the ticket. It answers a **`DwStoredFile`**: `id`, `purpose`,
   `fileName`, `contentType`, `byteSize`, and `url` for a public file. Finishing a finished file
   answers the file again.
4. A command of the project puts the file id on its row, after `ctx.files.requireOwned`.

**`DwGetFileLink(fileId)`** is a single request that answers a **`DwFileLink`**: `id`, `url`, and
`expiresAt` for a private file. It is a request, not a command, so no signed URL is ever stored for
idempotency; fetch it when the file is about to be shown. `fileName` is only a display name — the
key is built from nothing the client sends.

The client side — the uploader, progress, retries — is [uploads on the client](../3-flutter/uploads-client.md).

## Purposes and rules

A purpose is an enum in the shared package, so client and server name the same purposes:

```dart
enum DartwayStarterUpload with DwUploadPurpose {
  avatar;

  static const int avatarMaxBytes = 5 * 1024 * 1024;
  // …
}
```

(`template/dartway_starter_shared/lib/src/dartway_starter_upload.dart`: the server's rule and the
app's picker read the same limits.)

The server declares one `DwUploadRule` per purpose. From
`template/dartway_starter_server/lib/src/files.dart`:

```dart
List<DwUploadRule> get appUploadRules => [
  DwUploadRule(
    DartwayStarterUpload.avatar,
    // Shown to anyone who sees the member, by URL: a photo is not private.
    visibility: DwFileVisibility.public,
    maxBytes: DartwayStarterUpload.avatarMaxBytes,
    contentTypes: DartwayStarterUpload.avatarContentTypes,
    // Any member. The command that puts a photo on a profile checks it is the
    // caller's own finished upload (`ctx.files.requireOwned`).
    canUpload: (ctx) async => true,
  ),
];
```

| Field | Meaning |
|---|---|
| `purpose` | the `DwUploadPurpose` value; its name is the key's first segment, so it must be an identifier (letters, digits, `_`, starting with a letter) |
| `visibility` | `DwFileVisibility.public` or `private` — **required**: whether a file is public is a decision, never a default |
| `maxBytes` | the largest file; bound into the signature, so storage refuses a larger body even from a client that lies |
| `contentTypes` | the accepted MIME types, exactly (`image/jpeg`); lower-case, without parameters. Also decides the key's extension |
| `canUpload` | whether the caller may upload for this purpose; runs after the size and type checks, inside the start command's transaction |

A purpose without a rule refuses every upload with `dw.uploadPurposeUnknown`. Every file belongs to
an account: uploading always requires sign-in.

## The two buckets

Files live in two buckets of one storage (D-038b), and a rule's visibility picks the bucket:

- the **public bucket** is readable anonymously — its objects, not its listing — and its files are
  served from `publicBaseUrl` (the bucket itself, or a CDN in front of it). A public file's URL is
  permanent and costs no call;
- the **private bucket** has no policy: nothing reads it without a signature. Its files are read
  through `DwGetFileLink` — after the read check — by links valid for `linkLifetime`.

A bucket is public or private as a whole, never by key prefix: a prefix policy is one mistyped
resource away from making every file public, and a storage console shows a bucket's access, not a
prefix's.

Who reads a private file is `DwFileStorage.canRead(ctx, DwFileRecord file)`. Without it, only the
uploader. A `false` answers `dw.forbidden` to a signed-in caller and `401` to an anonymous one, who
may be allowed after signing in. The example lets chat members read chat attachments
(`example/dartway_example_server/lib/src/example_files.dart`):

```dart
Future<bool> exampleCanRead(DwCallContext ctx, DwFileRecord file) async =>
    await canReadChatAttachment(ctx, file) ?? file.accountId == ctx.accountId;
```

`DwFileRecord` carries `id`, `accountId`, `purpose`, `visibility`, `fileName`, `contentType`,
`byteSize`, `createdAt`, `confirmedAt`, and `isFor(purpose)`.

### The startup probe

With `verifyBuckets` on (the default), the server checks both buckets before it opens the database,
and refuses to start on any mismatch:

- each bucket exists and accepts the configured keys (signed `HEAD` and `PUT` of a probe object,
  `_dartway/visibility-probe`, left in place);
- an object of the public bucket reads anonymously at `publicBaseUrl`;
- an object of the private bucket does not read anonymously;
- neither bucket lists its keys anonymously.

A private file behind a public bucket is already leaked; a public bucket that does not read means
no photo opens. Both are configurations a server must not serve on. Turn the probe off
(`DW_STORAGE_VERIFY_BUCKETS=false`) only where the server cannot reach storage while it starts —
the `dartway deploy` MinIO stack, which verifies from outside once the stack is up.

### `DwFileStorageSetup.provision`

```dart
await DwFileStorageSetup.provision(config);
```

Creates both buckets where missing, gives the public one an anonymous-read policy for its objects
(not its listing) and deletes the private one's policy. Idempotent: an existing bucket keeps its
objects. For a storage the project owns wholly — MinIO in development, in tests, in a deploy. For a
bucket someone administers with policies of their own, configure it by hand and let the startup
probe say whether it is right. The skeleton's `bin/server.dart` provisions when
`DW_STORAGE_PROVISION=true`.

## Configuration

```dart
DwFileStorage appFileStorage(DwFileStorageConfig config) =>
    DwFileStorage(config, rules: appUploadRules);
```

passed as `DwAppServer(files: …)` (`template/dartway_starter_server/lib/src/files.dart`).

`DwFileStorageConfig`:

| Field | Environment (`DW_STORAGE_…`) | Meaning |
|---|---|---|
| `endpoint` | `ENDPOINT` (required) | the storage API, reachable **from clients**, since they upload to it directly |
| `region` | `REGION` | `us-east-1` by default |
| `accessKey`, `secretKey` | `ACCESS_KEY`, `SECRET_KEY` (required) | held by the server only; clients see presigned URLs for one object at a time |
| `publicBucket` | `PUBLIC_BUCKET` | required when a rule is public |
| `publicBaseUrl` | `PUBLIC_BASE_URL` | required with a public bucket |
| `privateBucket` | `PRIVATE_BUCKET` | required when a rule is private |
| `pathStyle` | `PATH_STYLE` | `true`: `endpoint/bucket/key`, what MinIO serves without DNS setup |
| `verifyBuckets` | `VERIFY_BUCKETS` | the startup probe, on by default |

`DwFileStorageConfig.fromEnvironment(env, {prefix: 'DW_STORAGE_'})` reports every missing or
malformed key at once. Which buckets are needed is the rules' business, so neither is required
there; the server names the missing one at startup. The skeleton's `appStorageConfig` fills in
development defaults — bucket names after the project, the public base URL on the endpoint — and
answers `null` without `DW_STORAGE_ENDPOINT`, so the server runs without uploads.

`DwFileStorage`:

| Field | Default | Meaning |
|---|---|---|
| `rules` | required | one per purpose |
| `canRead` | uploader only | who reads a private file |
| `ticketLifetime` | 15 min | how long an upload URL accepts the upload; short, since whoever holds it can put the object |
| `uploadGrace` | 15 min | how long after expiry an upload may still be finished (a large upload started just before), and kept before cleanup |
| `linkLifetime` | 10 min | how long a private link works |
| `maxPendingUploads` | 10 | unfinished uploads an account may hold with live tickets; one more is refused `dw.tooManyRequests` until the oldest ticket expires. Without it one account could reserve storage without end between cleanups |
| `cleanupInterval` | 10 min | how often unfinished uploads are looked for |
| `requestTimeout` | 30 s | the longest a storage request may take |

Lifetimes are between one second and seven days, the longest a presigned URL can live. Without
`files`, the server still has `dw_stored_file`; the file calls fail as incidents (a deployment
mistake, not a protocol skew) and `ctx.files` throws.

## `ctx.files`

A row references a file by id (`avatarFileId`). `ctx.files` is the `DwFileService`:

| Method | What it does |
|---|---|
| `requireOwned(fileId, purpose, {field})` | the caller's confirmed file of that purpose as a `DwStoredFile`; otherwise refuses `dw.fileNotOwned` on `field` — one code whether the file is absent, someone else's, unfinished or of another purpose, so a caller learns nothing about files that are not theirs |
| `publicUrls(fileIds)` | the URLs of the confirmed public files among the ids, in one query; private, unfinished and absent ids are not in the answer |
| `delete(fileId)` | deletes the row in the caller's transaction and enqueues the object's deletion in the same transaction — retried until storage confirms, so a crash after the commit cannot leave the object behind. Answers whether the file existed. Throws in a request |

**Check every file id a client sends.** A file id is a number anyone can type; without
`requireOwned`, a member could put someone else's private document on their own profile. From the
skeleton's `UpdateMyProfile` (`template/dartway_starter_server/lib/src/handlers/profile_handlers.dart`):

```dart
DwCallHandler.command<UpdateMyProfile, UserProfile>(
  access: DwAccessRule.signedIn,
  handle: (ctx, command) async {
    final current = (await ctx.db.userProfiles.findById(
      (await ctx.profile).id!,
      lock: DwRowLock.forUpdate,
    ))!;
    final previousAvatar = current.avatarFileId;
    final avatar = command.avatarFileId;
    if (avatar case DwSetField(:final value)) {
      // Only the caller's own finished avatar upload: a file id is a number
      // anyone can type.
      await ctx.files.requireOwned(
        value,
        DartwayStarterUpload.avatar,
        field: 'avatarFileId',
      );
    }
    final updated = await ctx.db.userProfiles.update(
      current.copyWith(
        firstName: command.firstName?.trim(),
        lastName: switch (command.lastName) {
          DwSetField(:final value) when value.trim().isEmpty =>
            const DwFieldPatch.clear(),
          DwSetField(:final value) => DwFieldPatch.set(value.trim()),
          final other => other,
        },
        gender: command.gender,
        avatarFileId: avatar,
      ),
    );
    // The photo it replaced is nobody's any more: its object goes once this
    // transaction commits, rather than staying in the bucket for ever.
    if (previousAvatar != null && previousAvatar != updated.avatarFileId) {
      await ctx.files.delete(previousAvatar);
    }
    return publishProfile(ctx, updated);
  },
),
```

Turn ids into URLs when rows become data objects, for the whole list at once
(`template/dartway_starter_server/lib/src/objects.dart`) — never store a URL on a row: the storage
configuration decides it, and a private file has none.

## Refusals

| Code | When |
|---|---|
| `dw.uploadPurposeUnknown` (field `purpose`) | no rule for the purpose |
| `dw.uploadTooLarge` (field `byteSize`, `maxBytes`) | over the rule's limit |
| `dw.uploadTypeRejected` (field `contentType`, `allowed`) | a type the rule does not accept |
| `dw.forbidden` | `canUpload` said no; or `canRead` said no to a signed-in caller |
| `dw.tooManyRequests` (`retryAfter`) | `maxPendingUploads` reached |
| `dw.uploadMissing` | finishing before the object is in storage; the ticket stays valid, so upload and finish again |
| `dw.uploadMismatch` | the stored object is another size or type than the ticket; the ticket is dead and the object is removed with the other unconfirmed uploads |
| `dw.uploadExpired` | finishing past the ticket's lifetime and grace; start a new upload |
| `dw.fileNotOwned` | `requireOwned` |
| `dw.notFound` | finishing someone else's ticket; a link to a file that does not exist or is unconfirmed |
| `dw.invalid` | `DwStartUpload.validate()`: empty purpose, a file name that is empty, longer than 255 characters or holds control characters or path separators, a malformed type, a size below one |

The codes are `DwUploadRefusal` values, separate from `DwCoreRefusal`, so a project switching
exhaustively over the core codes keeps compiling.

## Cleanup

`dw.files.cleanup` runs every `cleanupInterval`: unfinished uploads past their ticket lifetime and
grace are removed — object first, then row — in short batches of their own transactions.
`dw.files.deleteObject` deletes the object of a file removed with `ctx.files.delete`, retried up to
ten times ([jobs](jobs.md)).

`dw_stored_file` does not cascade from `dw_account`: deleting the rows would orphan their objects
where nothing could find them. Delete an account's files through `ctx.files` first.

## Not built

- **No multipart upload**: one `PUT` per file, so the storage's single-request limit is the largest
  file.
- **No cancel**: an abandoned upload stays pending until its ticket expires, counts against
  `maxPendingUploads` until then, and is removed by cleanup after its grace.
- **Browser uploads are cross-origin** to the storage, so both buckets' CORS configuration must
  allow `PUT` from the app's origin with the headers `content-type` and `if-none-match`. The
  framework does not configure it, and no test covers a browser upload (D-035).

## Related

- [Handlers and the call context](handlers-and-context.md) — where `ctx.files` is used.
- [Testing](../5-tooling/testing.md) — `DwTestStorage` provisions a pair of buckets per run.
- [Deploy](../5-tooling/deploy.md) — the MinIO the deploy runs.
