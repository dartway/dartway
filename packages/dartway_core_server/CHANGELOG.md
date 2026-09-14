# Changelog

## 0.20.0-dev.1

The rewrite (see docs/1.0).

- **File uploads (D-034): the bytes never pass through the app server.**
  `DwAppServer(files: DwFileStorage(DwFileStorageConfig(...), rules: [...]))`
  for one bucket of any S3-compatible storage; `DwFileStorageConfig.fromEnvironment`
  reads `DW_STORAGE_*`. A `DwUploadRule` per purpose states visibility (no
  default), `maxBytes`, exact content types and `canUpload`; a purpose without
  a rule refuses. The server names every object
  (`<purpose>/<account>/<192 random bits>.<ext of the type>`), presigns a PUT
  bound to the declared length, type and `if-none-match: *` (no overwrite, not
  even through the same ticket), confirms by `HEAD` under the row's lock
  (missing → `dw.uploadMissing`, a refusal; another size or type →
  `dw.uploadMismatch`), and answers private files through short presigned
  GETs behind `DwFileStorage.canRead` (default: the uploader). Unfinished
  uploads count against `maxPendingUploads` per account and are removed with
  their objects by the framework job `dw.files.cleanup` once ticket and grace
  have passed.
- **`ctx.files`** (`DwFileService`): `requireOwned(fileId, purpose, field:)`
  for rows that reference a file, `publicUrls(ids)` in one query, `delete`
  (the row in the caller's transaction, the object by the retried job
  `dw.files.deleteObject` after commit). `DwCallContext` gains the getter.
- **AWS Signature Version 4 in the framework**, no S3 SDK; pinned by the AWS
  SigV4 test suite and the S3 API reference examples.
- Framework migration `20260914_000000_dw_stored_file` (`dw_stored_file`;
  `account_id` without cascade, so an account's files are deleted first and no
  object is orphaned). Without `files`, the file calls answer as incidents and
  `ctx.files` throws. `DwTestServer.connectClient` takes `storageTransport`.
