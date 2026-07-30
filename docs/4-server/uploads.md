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
