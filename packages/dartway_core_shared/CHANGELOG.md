# Changelog

## 0.20.0-dev.1

The rewrite (see docs/1.0).

- **File uploads (D-034): the wire half.** `DwUploadPurpose` — the mixin a
  project's purposes enum takes, as channels take `DwChannelKind`. Built into
  `DwWireProtocol.core`: `DwStartUpload` → `DwUploadTicket` (a presigned PUT,
  the headers it is bound to, its expiry), `DwFinishUpload` → `DwStoredFile`
  (with a `url` only when public), `DwGetFileLink` → `DwFileLink` (a single
  request: a read, retried freely, stores no outcome). `DwStartUpload`
  validates on both sides — a display name without control characters or path
  separators, a lower-case MIME type without parameters, a positive size — and
  carries nothing the server decides: the object key is built by the server.
  `DwUploadRefusal` holds the upload codes (`dw.uploadPurposeUnknown`,
  `dw.uploadTooLarge`, `dw.uploadTypeRejected`, `dw.uploadMissing`,
  `dw.uploadMismatch`, `dw.uploadExpired`, `dw.fileNotOwned`) in an enum of
  its own, so a project's exhaustive switch over `DwCoreRefusal` still
  compiles. Ticket and link `toString` leave the presigned URL out.
