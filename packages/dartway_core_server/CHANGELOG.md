# Changelog

## 0.21.0-dev.4

- **BREAKING: jobs are typed. `DwJobKind<P>(name, encode:, decode:)` is what a job is; `DwQueuedJob<P>(kind, handle: (ctx, P payload) …)` is how it runs; `ctx.jobs.enqueue(kind, payload)` replaces `enqueue(String name, Map payload)`** (D-092). The `DwJobDefinition(...)` constructor is gone; `DwJobKind.withoutPayload(name)` is a `DwJobKind<void>` enqueued with `null`. Every project spelled each payload as a map at every enqueue and cast it back in every handler (`payload['runId']! as int`), and named jobs by string constants in three conventions. Migration note: `docs/migrations/2026-09-25-typed-jobs.md`.

## 0.21.0-dev.3

- **`DwAccessRule.resource<C, R>(load:, allows:)` and `ctx.accessed<R>()`** (D-090): the access rule that reads the row a call names, decides whether the caller may reach it, and hands it to the handler. Absent and not the caller's are both `dw.notFound`. It replaces `signedIn` with the ownership check written inline — 132 handlers of one project, and three diverging answers there to "is this person in this chat". A rule written for another call class fails the startup, as `check` does.
- **BREAKING: `DwAuthConfig.accountDeletion` is required — `DwAccountDeletion.byMember` answers `DwDeleteMyAccount`, `byOperator` refuses it `dw.forbidden`** (D-089). The framework used to answer the command in every project, and two of them learned it had gone live only when their pin moved; each switched it off by refusing inside `onAccountDeleting`, which refused the operator's own `ctx.accounts.deleteAccount` as well. Migration note: `docs/migrations/2026-09-24-account-deletion-choice.md`.

## 0.21.0-dev.2

- **`testing.dart` carries what every project's harness copied from the skeleton**: `DwCountingTransport` (real HTTP, posts counted per wire name, the last answer kept), `DwRecordingConnector` (the real live socket, every frame kept — `updatesOn`, `refusalsOf`, `closuresOf` a channel) and `dwWaitUntil(condition, reason:)`, the polling wait that throws a `TimeoutException` naming its reason. u90, Molodey and Studio each carried a copy, and the copies drifted.
- **BREAKING: `DwAuthConfig.fixedCode` is gone; `generateCode` and `deliverCode` are independent, and `deliverCode` now runs after the ticket's transaction has committed** (#310, D-087). `generateCode(ctx, kind, identifier, accountId)` decides the code — `null` (the default) draws `codeLength` random digits, exported as `dwRandomCode`; `deliverCode(ctx, kind, identifier, code, accountId)` now runs **always**, whatever the code is, and decides for itself whether to send it. The framework used to infer "do not send" from "the code was not random" — a fixed code that also had to be sent (a default code out of a project's own settings, SMS turned on for it) could not be expressed without working around `deliverCode` entirely. Separately, `deliverCode` no longer runs inside the transaction that writes the ticket: a project's `deliverCode` is commonly an HTTP call to a provider, and running it under the identifier's advisory lock held a pooled connection for as long as the call took — one slow provider could exhaust the pool for the whole server. The ticket is written, and counted against the limit, before delivery runs; a `deliverCode` that throws or refuses no longer undoes it. Migration note: `docs/migrations/2026-09-24-generate-deliver-code-split.md`.
- **Internal: a duplicate send of the same idempotency key, arriving while `deliverCode` is still running, now replays the ticket its own transaction already committed instead of re-running `_requestCode` and meeting its own resend-delay refusal.** Not a new public API — a slow delivery used to leave a window where a duplicate send re-ran `_requestCode`, hit the ticket's own resend-delay refusal, and that refusal's `dw_command_outcome` row raced the real answer's — whichever finished writing first stood forever, so a client retrying with the same key could get stuck reading "too many requests" for a code that had, in fact, gone out. `_requestCode` now records the ticket from inside its own transaction, before `deliverCode` runs, through an internal hook (`DwRuntimeContext.recordProvisionalOutcome`) no project handler can reach. If the handler then throws once that row exists: a refusal upserts it into a refused outcome (a plain update would miss a row that itself rolled back with a transaction the handler's post-write work still threw inside of); anything else removes it (an incident is never stored under the idempotency key at all, so a later resend runs the handler again — and meets the ticket's own resend-delay refusal, correctly, since the ticket is real either way).
- **A refusal from `_validate` or `_check` is no longer stored under the idempotency key.** Both moved out of the transaction/try they used to run inside, as part of the above; a validation or access-check refusal is a pure function of the call's own input, so a replay refuses identically anyway — but a project reading `dw_command_outcome` directly (nothing in this repository does) would no longer find a row for one. Transactional commands: only `_validate`'s refusal is affected — `_check` still runs, and is still recorded, inside the transaction.

## 0.21.0-dev.1

- Nothing changed here; the family moves in lockstep with `dartway_client`, fixed for #309.

## 0.20.0

- First publication of the rewrite to pub.dev.

## 0.20.0-dev.4

- **BREAKING: `DwServerSettings.minAppBuild` is gone** (#296, D-084). A server compares the client's contract version with its protocol's, by breaking line; the minimum is raised in the pull request that breaks the contract, never in an environment (`DW_MIN_APP_BUILD`). `DwTestServer` sends its protocol's contract version; `liveEndpointWith(contract:, withoutContract:)` names another. Migration note: `docs/migrations/2026-09-24-contract-version.md`.

## 0.20.0-dev.3

- Nothing changed here; the family moves in lockstep with `dartway_core_flutter`.

## 0.20.0-dev.2

- **`ctx.files.describe(fileIds)`** (#285): what the confirmed files among the ids are, as `DwStoredFile`s — name, size, content type, purpose, a public file's URL — in one query. A screen listing what rows hold read `dw_stored_file` with SQL for it, bound to columns that are the framework's. `delete` now says it is also how a confirmed file nothing references is let go of.
- **`DwFirstAdministrator.kindOf` defaults to `DwIdentifierKind.of`** (#283), the same rule, now shared.
- **`DwAppServer(startup: [...])` — work done at every start, after the migrations and before the port opens** (D-079). A `DwStartupStep` runs in a background context and one transaction (`ctx.db`, `ctx.accounts`, `ctx.publish`, `ctx.jobs`), states its configuration problems to `validate()` before anything opens, and stops the start when it throws — in a deployment, with the previous server still serving. `DwFirstAdministrator` is the case every project has: it brings the account named by `DW_ADMIN_IDENTIFIER` (was `APP_BOOTSTRAP_ADMIN`, and the name is now the framework's) into existence and hands it to the project's `grant`, which gives its own admin role. Every project used to carry its own sixty lines of this and call them by hand after `start()`.
- **`DwLocalEnvironment.overlay(Platform.environment)`** (D-078): a project's entry points read `deploy/config.yaml > local` (committed: the development database and storage the team shares) and `deploy/secrets.yaml > local` (git-ignored: what is this developer's own) into their environment, in one visible line. A real environment variable still wins, and a deployed server has neither file — `.dockerignore` keeps `deploy/` out of every image — so the deployed path is unchanged. It ends the block of `DW_DATABASE_*` that every project copied into a launch configuration, a README and a shell profile. It costs `yaml` as a dependency: the parser is carried into a production binary that never calls it.

## 0.20.0-dev.1

The rewrite (see docs/1.0).

- **A call that takes the `unknown` of an open enum to a write is answered `dw.updateRequired`** (D-071, #274). It used to leave the guard's throw to the generic catch: a 500 with an incident id for the caller and an alert for the operator, on an input the framework refuses on purpose. The build sending `unknown` back is older than the data it is writing and cannot correct its input, only update. Outside a call — a job, a module, a subscription — the same throw is still a failure.
- **The seam for external sign-in** (D-073, in progress): `DwAccountService.signInWithExternalIdentity(provider:, subject:)` signs in — or creates — the account of an identity a provider proved, with `DwAuthConfig.onExternalAccountCreated` for the project's row, and `accountOfExternalIdentity` to look one up. The verification of a provider's token lives in `dartway_auth_providers_server`.

- **Deleting an account** (D-072, nothing of the person left in the framework's tables — code tickets addressed to their identifiers and the outcomes of their commands go with the account, rather than waiting for the cleanup): `DwDeleteMyAccount` and `DwAccountService.deleteAccount` — `DwAuthConfig.onAccountDeleting` for the project's rows, then the account's files, keys (sessions end) and the account with its identities, in one transaction.

- **`DW_MIGRATE_ONLY=true` makes `DwAppServer.start()` a one-off migration** that serves nothing and ends the process (0, or non-zero with the reason); `DwAppServer.migrate()` does the same without ending it. `dartway deploy` migrates this way between stopping the old server and starting the new one (D-070).

- **`DwCallHandler.command(recordsSuccess: false)`** skips storing a successful outcome under the idempotency key, for a command whose own unique keys make a repeat harmless and which is sent often (analytics batches); refusals are still recorded.

- **A job runner claims only the jobs its process declares.** During a deployment the old server claimed a recurring job the new one had just added — due at once — and threw on the unknown name, stopping every job of that process while the row stayed due; a queued job of a kind only the new code enqueues was marked failed for good. Both now wait for a process that declares them; queued jobs nobody here declares are logged at start.

- **A finished upload with no object is logged** (#224): the refusal `DwUploadRefusal.missing` now leaves a warning with the file id, expected size and type, bucket and key — the only server-side trace when an upload that reported success left nothing in the bucket.

- **Alerts have a ceiling across signatures** (#257): `DwServerSettings.alertsPerMinute` (10). Past it an incident is only logged, and the next alert carries how many were held back — many different failures at once no longer exhaust Telegram's 20-a-minute limit and lose alerts to its refusals.

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
