# Changelog

## 0.20.0-dev.1

The rewrite (see docs/1.0).

- **Identity and session key DTOs (D-042, D-045).** Built into
  `DwWireProtocol.core`: `DwRequestIdentifierCode(kind, identifier)` →
  `DwCodeTicket` and `DwConfirmIdentifier(ticketId, code, replace)` →
  `DwIdentityInfo` — attach or change an identifier by one-time code while
  signed in; data objects `DwIdentityInfo` (id, accountId, kind, value,
  createdAt, verifiedAt) and `DwSessionKeyInfo` (id, accountId, kind, label,
  createdAt, lastUsedAt, revokedAt — never a token); `DwSessionKeyKind { app,
  personal }`; `DwAuthRefusal.identifierTaken` (`dw.identifierTaken`), a
  separate enum from `DwCoreRefusal`.

- **Updates carry their channel (D-036).** A response's `updates` are grouped
  by channel wire name, then by type —
  `{"bookings:7": {"SessionBooking": [...]}, "schedule": {"ClubSession": [...]}}`
  — and collapse by (channel, type, id): `DwUpdateTransport(Iterable<(String,
  DwWireObject)>)`, `channels`, `objectsOn(channel)`. One channel's type groups
  are `DwChannelUpdates`, the body of a live `upd` message, which names its
  channel beside them. The channel is the only fact that says whose data an
  object is: routed by type alone, a member's profile in an admin's answer
  landed in the admin's own "my profile".
- **Caller channels (D-037).** `DwLiveChannel.ofCaller(kind)` — a channel keyed
  by whoever watches — for "my" requests, which carry no account id;
  `resolvedFor(accountId)` and `DwLiveChannel.forAccount(kind, accountId)`.
  An unresolved caller channel has no `wireName` (throws `StateError`).
- **`DwTableRequest` refetches on a new matching object (D-037).** Default
  `matches ? upsert : remove` (new `matches`, default every object): an object
  on the page is replaced in place; one not on the page, one that stops
  matching and a deletion read the page again, so the total and the paging
  stay true.
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
