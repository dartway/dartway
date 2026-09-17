# Changelog

## 0.20.0-dev.1

The rewrite (see docs/1.0).

- **Jobs know their run and announce as they go.** `ctx.job` (`DwJobAttempt`: `attempt`, `maxAttempts`, `isLastAttempt`) in a job's handler, `null` elsewhere. A non-transactional job's publications inside a `ctx.transaction` are delivered when that transaction commits, rather than when the job ends.

- **`ctx.publish(channel, item, exceptAccounts: {...})`** keeps one publication from those accounts: their live connections do not receive it, nor does a command's response when the caller is one of them. An object published twice in a call travels as its last publication, exceptions included (D-066).

- **`DwAppServer.runInContext(work)`** (and `DwTestServer.runInContext`): server-level work with a
  real `DwCallContext` — background, no caller, one transaction, effects delivered after commit and
  none on a throw. A domain service that needs a context could only be reached through a command or
  a job written for the purpose (D-065).

- **The server reads and writes its own files**: `ctx.files.read(fileId)` answers the bytes of a
  confirmed file, public or private; `ctx.files.readLink(fileId)` a short link another service can
  fetch; `ctx.files.store(purpose, accountId:, bytes:, contentType:, fileName:)` a new confirmed
  file the server made, by the purpose's rule. None asks `canRead` or `canUpload`. A stored file
  is confirmed in the caller's transaction; rolled back, it is removed with its object as an
  unfinished upload (D-062).

- **Failed jobs are no longer kept forever.** `dw.cleanup` removes a job that ran out of attempts
  once `DwServerSettings.failedJobRetention` (30 days by default) has passed since it failed.
  Such rows stay for the operator to read and re-enqueue, but nothing did either on its own, so a
  job failing on every run of a schedule added a row an hour for as long as the server lived.

- **`DwAppServer(migrationsDirectory:)`**: a server run from its sources refuses to start on a
  pending migration edited after its checksum was sealed, and says to `rehash`. The template and
  the example pass `lib/src/migrations`; a compiled server has no such directory and checks
  nothing.

- **Server modules.** `DwAppServer(modules: [...])` takes `DwServerModule`s —
  framework satellites such as push — each bringing migrations under its own
  namespace (applied after `dw`, before `app`), handlers for calls the project
  may not answer itself, jobs named `dw.<namespace>.…`, startup problems of
  its own, and `close()` on stop. `ctx.module<M>()` reaches a module's runtime
  from a handler, which is how `ctx.push` exists without a global.

- **Accounts, keys and identities without SQL (D-042 – D-050).** A project
  never queries `dw_account`, `dw_identity` or `dw_auth_key`; `ctx.accounts`
  (`DwAccountService`) covers them:
  - **session keys**: `issueKey(accountId, label:, kind: personal)` →
    `({DwSessionKeyInfo key, String token})` — the token exists only in that
    answer (stored as SHA-256; a command whose handler minted one stores no
    successful outcome, so a retry runs again); `listKeys(accountId)`;
    `revokeKey(keyId, {accountId})` → `bool`, at once in this process — the
    token cache forgets the key and live connections on it lose their
    subscriptions with `rejected`, as after a sign-out; other processes within
    `tokenCacheTtl`. Sign-in keys are `DwSessionKeyKind.app`, labelled
    `Dw-App-Version · User-Agent` (sanitised, 200 characters).
  - **`ctx.sessionKey`** (`DwSessionKeyInfo?`): the key that authenticated
    the call — its id, kind and label — on calls, channel subscription checks
    and routes. **`DwHttpRoute.get/post/any(..., auth: DwRouteAuth.optional |
    required)`** reads `Authorization: Bearer` (401 for an unknown, revoked or
    required-but-missing token; 400 for a malformed header); the default
    `none` reads nothing, as before.
  - **identities**: `listIdentities`, `listIdentitiesOf` (batch),
    `accountsMatching(fragment, {kinds})`, `moveIdentities(from, to,
    {kinds})` and `removeIdentities(accountId, {kinds})` — transactional,
    under the per-identifier locks sign-in takes, revoking nothing.
  - **built-in `DwRequestIdentifierCode` / `DwConfirmIdentifier`**: a
    signed-in caller attaches an identifier, or changes theirs (`replace`), by
    one-time code without signing in again — sign-in's normalization, limits
    (shared per identifier), `fixedCode` and `deliverCode` (`ctx.accountId` is
    the caller). Tickets are bound to their purpose and account. Another
    account's identifier is refused `dw.identifierTaken` only after the right
    code.
  - **`DwAuthConfig.onIdentifierChanged(ctx, DwIdentifierChange)`**, in the
    same transaction, for every change to an existing account's identifiers
    (confirm, move, remove); a throw rolls the change back.
- **Breaking: `onAccountCreated`'s last argument is `DwAccountOrigin`** —
  `DwSignInOrigin(registration)` or `DwToolOrigin()` from
  `DwAccountService.ensure` — instead of a registration map that was empty for
  a tool. `ensure`'s identities are unverified (`verifiedAt == null`) until
  they sign in.
- **Framework migration `20260914_220000_dw_keys_and_identities`**:
  `dw_auth_key.kind`, `label`; `dw_identity.verified_at`;
  `dw_code_ticket.purpose`, `account_id`.

- **Publications keep their channel through delivery (D-036).** The response
  transport groups what a command published by channel, filtered by the named
  live connection's subscriptions by exact channel.
- **`DwChannelRule.ofCaller(kind)` (D-037):** a connection subscribes to its
  own account's key only; handlers publish with
  `DwLiveChannel.forAccount(kind, accountId)`. `ctx.publish` / `ctx.revoke` of
  an unresolved `DwLiveChannel.ofCaller` throw `ArgumentError`.
- **Live-socket origin check compares full origins** — scheme, host and port.
  The origin the upgrade was sent to (its `Host`) is allowed;
  `DwServerSettings.allowedOrigins` entries are full origins
  (`https://app.example.com`, `http://localhost:5000`), and the server refuses
  to start with one that is not. Previously any port or scheme of an allowed
  host passed.
- **Standard reason phrases** on every status line: `dart:io` wrote
  `Status 422` / `Status 426` / `Status 429`; now `Unprocessable Content`,
  `Upgrade Required`, `Too Many Requests` (RFC 9110/6585, `413` is
  `Content Too Large`). `DwTestAnswer.reasonPhrase`.
- **File uploads (D-034): the bytes never pass through the app server.**
  `DwAppServer(files: DwFileStorage(DwFileStorageConfig(...), rules: [...]))`
  on any S3-compatible storage; `DwFileStorageConfig.fromEnvironment` reads
  `DW_STORAGE_*`. A `DwUploadRule` per purpose states visibility (no
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
- **Two buckets: public and private, each as a whole.**
  `DwFileStorageConfig(publicBucket:, publicBaseUrl:, privateBucket:)`
  (`DW_STORAGE_PUBLIC_BUCKET`, `DW_STORAGE_PUBLIC_BASE_URL`,
  `DW_STORAGE_PRIVATE_BUCKET`; `bucket` / `DW_STORAGE_BUCKET` are gone). A
  rule's visibility picks the bucket: public objects are read anonymously
  through `publicBaseUrl`, private ones only through presigned links after
  `canRead`. A public bucket needs `publicBaseUrl`; the two must differ; a
  public rule without a public bucket, or a private rule without a private
  one, fails startup. `dw_stored_file.bucket` records where each object is,
  so cleanup, `ctx.files.delete`, finishing and links address that bucket,
  and a public URL is given only for files in the configured public bucket.
- **The server checks its buckets at startup** (`verifyBuckets`, default on;
  `DW_STORAGE_VERIFY_BUCKETS=false` turns it off where storage is unreachable
  while the server starts). For each configured bucket: a signed `HEAD`, a
  probe object `_dartway/visibility-probe` written with the keys, then
  without credentials: the public probe must read back through
  `publicBaseUrl`, the private one must be refused, and neither bucket may be
  listed. Anything else refuses startup with one problem per finding.
- **`DwFileStorageSetup.provision(config)`** creates both buckets on a storage
  the project runs (MinIO in development, tests, deploy), sets the public
  bucket's policy to anonymous `s3:GetObject` only
  (`DwFileStorageSetup.publicReadPolicy`) and deletes the private bucket's
  policy. Idempotent.
- **`DwTestStorage`** (`testing.dart`): a provisioned public/private bucket
  pair for one test file on the storage of `DW_STORAGE_*`, with `config`,
  `keys(bucket)` and `drop()` — the storage counterpart of `DwTestDatabase`.
- **`ctx.files`** (`DwFileService`): `requireOwned(fileId, purpose, field:)`
  for rows that reference a file, `publicUrls(ids)` in one query (no ids
  answer empty without a query, even on a server without storage), `delete`
  (the row in the caller's transaction, the object by the retried job
  `dw.files.deleteObject` after commit). `DwCallContext` gains the getter.
- **AWS Signature Version 4 in the framework**, no S3 SDK; pinned by the AWS
  SigV4 test suite and the S3 API reference examples.
- Framework migrations `20260914_000000_dw_stored_file` and
  `20260914_180000_dw_stored_file_bucket` (`dw_stored_file`, unique by bucket
  and key;
  `account_id` without cascade, so an account's files are deleted first and no
  object is orphaned). Without `files`, the file calls answer as incidents and
  `ctx.files` throws. `DwTestServer.connectClient` takes `storageTransport`.
- **`20260914_180000_dw_stored_file_bucket` migrates a table that holds files
  (D-056).** Its first text added `bucket` `NOT NULL` outright and failed on
  any database with a stored file. The column is now added nullable, and rows
  without a bucket stop the migration with the two statements that record the
  bucket their objects are in — the single `DW_STORAGE_BUCKET` of that time,
  which no migration can know; once recorded, the column becomes `NOT NULL`.
  Databases that applied the first text keep their ledger row: the migration
  declares that text's checksum in `supersededChecksums`.
