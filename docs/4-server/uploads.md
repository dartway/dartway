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
`chat/$roomId`. Omit it and the object sits at the bucket root.

## The object name

You do not name the object; the framework does, and the name is 16 secure random bytes behind a
readable timestamp. **The randomness is not decoration.** The bucket serves anonymous `GetObject`,
so a name anyone can guess from a neighbouring one is a file anyone can read — withholding the
listing protects nothing when the keys enumerate themselves. A guessable name is also a name two
uploads can collide on, and an overwrite in object storage leaves no trace on either side: the first
file simply stops existing.

`path` is therefore the knob to reach for when you want uploads grouped or scoped; the name itself is
not. If you do replace `DwFileUploadHandler.defaultUploadNameTemplate`, keep a random segment in it,
and leave the extension off — the upload call appends the extension of the bytes it actually sends,
which is not always the extension of the file that was picked (most images are converted to JPEG on
the way).

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

`verifyUpload` records a `DwCloudFile` row — object path, bucket, size, mime type, the uploading user
and the public URL — so the file is queryable afterwards rather than being a URL nobody can account
for. The endpoint requires a signed-in user; anonymous uploads are not a thing.
