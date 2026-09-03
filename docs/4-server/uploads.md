# Files and images

Uploads are one call on the client and one config entry on the server. There is no file layer in
between: what you store on a model is an ordinary URL field that travels the same CRUD path as every
other field.

## On the client

```dart
onTap: dw.action((_) async {
  final imageUrl = await DwFileUploadHandler.pickAndUploadImageUrl();
  if (imageUrl == null) return; // the picker was dismissed — not a failure
  await dw.repo.saveModel(userProfile.copyWith(imageUrl: imageUrl));
}, onSuccessNotification: l10n.profilePhotoUpdated),
```

`pickAndUploadImageUrl` opens the picker, uploads the bytes and returns the public URL. Neighbouring
forms exist when you need more: `pickAndUploadImage()` returns a `DwCloudFile` (size, mime type), and
`uploadXFileToServer(xFile:)` takes a file you already have — from a camera, a drop target, a share
intent.

Every one of them takes an optional `path` — the folder inside the bucket the object lands in, `avatars` or
`chat/$roomId`. Omit it and the object sits under your own segment at the bucket root.

When you already hold the bytes, `uploadBytesToServer` takes them plus `folder`, a required
`fileExtension` describing what the bytes are, and an optional `fileName`.

## The object name

**You do not name the object, and you cannot.** The server does, from what you send: the folder,
your user id, a UTC timestamp, the file name you suggested and the extension of the bytes.

```
avatars/u123/2026-09-03T14-22-07_photo.jpg
```

This is not a matter of style. The endpoint used to sign an upload for whatever key the client
asked for, which meant a signed-in user who knew somebody else's key could overwrite the object
behind it — and object storage reports an overwrite on neither side, so the first file simply stops
existing. Any check the client performs is a check on a device; the guarantee has to be a key the
client does not choose.

Three consequences worth knowing:

- **The folder is a hint, not a boundary.** It is sanitised into plain path segments — `..`, leading
  slashes, backslashes and control characters do not survive — and capped at four levels deep. Your
  own `u<id>` segment is inserted after it either way.
- **The suggested name is sanitised too**, and it is what the object downloads as: these URLs are
  public and direct, so there is no `Content-Disposition` to set and the browser saves the file
  under the last path segment.
- **The extension is a separate argument from the name**, because the two disagree. Most images are
  converted to JPEG on the way out, so the picked file is `.heic` while the bytes are `.jpg` — and
  the recorded mime type is read off the key.

Uniqueness is held by the `dw_cloud_file` table, not by the name: the row is written when the
server hands out the description, a unique index on `(bucket, path)` refuses a key already issued,
and the endpoint tries the next candidate.

Wrap it in `dw.action`: an upload is slow, and `DwActionBuilder` supplies the `busy` flag and blocks
the second tap for free.

## On the server

Storage is optional and configured through `DwCore.init`:

```dart
cloudStorageConfig: passwords.containsKey(DwConfigurationKeys.dwCloudStorageEndpoint)
    ? DwCloudStorageConfig.fromEnv(passwords)
    : null,
```

The keys live in `config/passwords.yaml` per run mode:

```yaml
development:
  dwCloudStorageRegion: 'us-east-1'
  dwCloudStorageEndpoint: 'localhost'
  dwCloudStoragePort: '8100'
  dwCloudStorageUseSSL: 'false'
  dwCloudStorageAccessKey: 'dartway_dev'
  dwCloudStorageSecretKey: 'dartway_dev_storage_pw'
  dwCloudStorageBucket: 'uploads'
```

An app that never configures storage still has the upload endpoint mounted; calling it says what is
missing rather than failing on a null check.

## Local development

`docker compose up -d` starts a Minio container next to Postgres, and a one-shot `minio_init` that
creates the bucket and opens it for reading. DartWay's storage speaks S3 through the minio client, so
what runs locally is the same code path production takes — not a stand-in that behaves differently
once deployed.

The endpoint in the config is **what the browser and the device resolve**, because public URLs are
built from it (`http://localhost:8100/uploads/<object>`). That is why it is `localhost` in
development and a real host in production, and why a bucket that is not readable shows up as an image
that will not load rather than as an error on upload.

Ports: the S3 API is on **8100** and the Minio console on **8101**. Deliberately not 9000/9001, and
deliberately not 9100 — Flutter DevTools binds 9100, so a Flutter developer with DevTools open would
have hit a collision on their first run.

## What is stored

An upload is two calls, and the server owns both ends.

`getUploadDescription` builds the key, writes a `DwCloudFile` row for it — bucket, path, public URL,
file name, the uploading user — and answers with a `DwUploadTicket`: the signed description, plus
the id of that row. The row is a **reservation** at this point, with no size and no `verifiedAt`.

`verifyUpload` takes that id, not a path. It stats the object, fills in the size and stamps
`verifiedAt`, and it answers `null` when the reservation is unknown, belongs to somebody else, or
holds no bytes yet — so a caller has nothing to name but its own upload. A row that never gets a
size is an upload that never landed.

The endpoint requires a signed-in user with a profile; anonymous uploads are not a thing, and the
key is built from that id.
