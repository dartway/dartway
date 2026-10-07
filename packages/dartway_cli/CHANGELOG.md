# Changelog

## 0.24.0

- Deploy output is masked on the target by literal stored secret value (at least 6 characters),
  including URL percent-encoded forms, before stdout/stderr reach human logs or JSON progress.
  Covers fresh and resumed steps, direct runs, setup and checks (#437).

- **Breaking — safe framework updates** (#427, #441): `update --plan` reads an exact committed target
  without project edits; writes require its full `--target` SHA. The proposed analyzer plugin
  source must resolve through pub before installation or configuration edits. Existing git/path
  choices and project rules survive. Migration completion is explicitly verified per note in
  `.dartway/migrations.json`, with applied/not-applicable dispositions and evidence. Locks and
  toolkit installs never complete notes; unknown baselines and partial completion remain visible.
  Preflight preserves native diagnostic settings and resolves only the selected dependency
  source using native dependency YAML; ambiguous sources, pub-only hosted map forms and sources
  that fail native YAML resolution are rejected before project edits.
- `generate`/`check` carry `--contract-base` through one resolved generator invocation;
  `projectContractVersion` is an error for incompatible or unverified generated project contracts.
  Direct execution of the resolved generator prevents implicit pub/lock writes during checks.

- One toolkit supports Codex and Claude. `create`, `setup-ai` and `update`
  accept `--agent codex|claude|both` (default `both`, recorded for updates).
  Root owner instructions are preserved; managed blocks connect both agents
  to `.agents/DARTWAY.md`. Skills install for each selected agent from one source.
  The common manifest is `.agents/dartway-toolkit.json`; old install choices
  are retained. Claude permissions remain separate.

- **`deploy run` asks Let's Encrypt before it replaces anything** (dartway/dartway#433, D-123): the
  `certificate` step runs right after the data volume guard, through the proxy the previous deploy
  left running, so a Let's Encrypt failure stops the deploy with the previous version still serving
  instead of after the server was replaced and before the proxy restart. With no proxy running — a
  first deploy, a stand that is down — it asks nothing, and the new step `certificate-started-proxy`,
  before the proxy restart, issues the certificate; on a routine deploy that step finds every host
  covered and asks nothing either. **The coverage check works again**: it read `certbot certificates`
  for a `Domains:` line that certbot 5 prints as `Identifiers:`, so every certificate looked empty and
  every deploy asked to extend one that already named every host; the hosts are now read from the
  served certificate itself with `openssl`. A host added to the configuration no longer needs `setup`
  first: the rendered port-80 server now comes before the `nginx.d/http` snippets, so it is the
  default for any name a project's own port-80 server does not claim, from the deploy after the one
  that renders it. `deploy_certificate_docker_test.dart` proves both against the pinned images.

- **The toolkit `dartway update` installs asks four questions before a test is written**:
  `dartway-testing` holds a gate — what the test protects, which credible regression turns it red, why
  existing coverage misses it (one owner test per contract, at the tier that owns it), which production
  caller uses the seam it needs — and the junk shapes that fail it; a bugfix's test is red on the unfixed
  code for the bug's reason, once, at the owner boundary. `dartway-finish`, `dartway-plan` and
  `dartway-feature-scaffold` point at the gate instead of asking for a test per layer or per handler.

- **The toolkit `dartway update` installs states every rule once** (dartway/dartway#392, D-121):
  `CLAUDE.md` is the seven laws and a law table with one row per rule, naming its failing checks and
  the skill that owns it; each skill holds only its own topic, task-first, with pointers instead of
  restatements; `/dartway-checkup` runs the gates and `check` first and reads only the skills its
  findings point at. About a third of the words it had. Two stale instructions went with the copies:
  the uploads skill's `initState` fallback and the navigation skill's `notifyListeners`, both banned.
  A new test, `docs_paths_test.dart`, fails on an `example/…`, `template/…` or `__*_PKG__/…` path in
  `toolkit/` or `docs/` that does not resolve.

- **`dartway check` fails an app that disposes its router** (dartway/dartway#407, D-120):
  `routerDisposedByApp`, an error, in the state inspector — `<x>.router.dispose`, called or torn off
  (`ref.onDispose(router.router.dispose)`), anywhere in the Flutter package's `lib/` but generated
  code. `DwAppRouter` disposes itself with its provider now, and the line every project wrote before
  would dispose it a second time. The law table gains the row "The router owns its lifetime".

- **BREAKING: `dartway check` holds how server features import and write one another**
  (dartway/dartway#382, D-118). Four new errors, in their own inspector (`dw_feature_imports.dart`):
  `coreImportsFeature` — a file of `core/` importing a feature or the package's library;
  `featureImportCycle` — features importing each other in a cycle, by any `import`/`export`/`part`
  (`package:` or relative, conditional alternatives included), one finding per knot with its
  shortest cycle and the import behind each step; `featureImportOutsideSurface` — a feature
  importing another's file that is not its `_rows`, `_access`, `_objects`, `_publications` or
  `_changes` (or a `<part>` of one), or the package's library; `foreignRowWrite` — a
  `<handle>.<table>.insert`/`update`/`delete`/`upsert`… (`ctx.db`, a transaction's handle, any
  other) of a table whose row class another feature
  declares (read from the generated schema and the row classes), from a feature or from `core/`.
  `changes` joins the closed file set of a server feature: `<feature>_changes.dart` is how another
  feature writes its rows. The server's library file, `migrations/`, `bin/` and `test/` are not
  judged. The skeleton and the example follow: `ProfileCallContext`/`ProfileAccess` in
  `profile/profile_access.dart`, the sign-in hooks (`AccountAuth`) and the first administrator in a
  new `account/` feature, every foreign write through `ProfileChanges`, `ScheduleChanges`,
  `BookingsChanges`, upload rules and the example's push audience in their features' `_access.dart`.
  Migration note: `docs/migrations/2026-09-30-feature-import-graph.md`. In the example,
  `BookSession` takes the spot first (`ScheduleChanges.takeSpot` locks the session and refuses a
  missing or full one) and then checks the start and a spot already held, so a full session that
  already started is refused as full rather than as started.
- What `deploy` sends over stdin — the values of the `secret` commands, the rendered compose and
  nginx files of `deploy setup`, the script of every remote deploy step — no longer crashes on
  `SocketException: Broken pipe` when the remote command exits without reading it (`ssh` that could
  not connect, a script stopped by `set -e`): the command's own exit code and stderr are reported.
  The output is read while the input is written, so a command that echoes a large input no longer
  deadlocks (dartway/dartway#400).
- `dartway check` reads Dart source through one scanner (dartway/dartway#403): every detector that
  blanks comments and strings — the route names, the declaration outline, the clock, the
  environment and HTTP client, inline ownership, the Flutter state and UI rules, the data
  lifecycle, the feature imports, the uniformity rules, unused feature files and the UI kit's text
  constants — uses `dw_dart_source.dart` instead of its own copy, and its edge cases (raw and
  triple-quoted strings, nested interpolation with quotes and braces, `$name`, nested block
  comments, `//` inside a string) are one fixture suite. No finding changes over the skeleton, the
  example and the three projects on the framework. Some source that no project holds is now read
  correctly: a quote or brace inside `${…}` no longer ends the string, block comments nest, a `//`
  inside a string no longer hides the rest of its line from `unusedFeatureFile`, a name used only
  inside an interpolation keeps its file alive, an environment read inside an interpolation in
  `bin/` is reported, a plain and a raw literal side by side are one SQL string, a literal inside a
  block comment is not a UI kit text constant, and a literal in a conditional import's condition
  is not a URI.

## 0.23.0

- **BREAKING: `dartway check` holds the shared package to the server's features, and file length
  to the server and the shared package** (dartway/dartway#383, D-119). New error
  `invalidSharedLayout` (`dw_shared_layout.dart`): the shared package's `lib/src/` holds
  `<feature>.dart`, or a flat folder `<feature>/` of `<feature>_<part>.dart` parts only (a part never
  exactly a layer name, no `<feature>/<feature>.dart`), `<feature>` a feature folder of the server's
  `lib/src/` read in the same run, plus `<prefix>_channel`, `_refusal`, `_upload`, `_protocol` and
  `_push_category.dart` (the prefix the package's name without `_shared`); a feature as a file and a
  folder at once is a finding; `lib/` holds the library (directives only), `generated/` (files with
  a generator's header only) and `src/`; a hand-written file named `*.dw.dart`, `*.g.dart` or
  `*.freezed.dart` is a finding. A finding names
  the owner of a near miss (`issue_process.dart` → `src/issues/issues_process.dart`) and the name of
  a misnamed protocol file. Without a server package names are not matched, and the run says so.
  `fileLong` (over 200 lines, info) and `fileTooLong` (over 350, warning) now also judge every file of
  the server's and the shared package's `lib/` (`dw_package_file_size.dart`), passing over generated
  code (by name and header), the server's migrations and, on the server, seed data — directives and
  top-level `const`s each a `New<Entity>Row(…)` draft or a collection of drafts only. Tests are not
  measured. The template's shared package
  moves `AuthIdentifier` and `RegistrationKeys` into `profile.dart` and `app_protocol.dart` to
  `dartway_starter_protocol.dart`; the example's `news.dart` and `settings.dart` become `content.dart`,
  `people.dart` becomes `profile.dart`, `chat.dart` splits into `chat/chat_channels.dart` and
  `chat/chat_messages.dart`, and its server's `chat_handlers.dart` into `chat_handlers.dart` and
  `chat_messages_handlers.dart` (`chatMessagesHandlers`). Migration note: `docs/migrations/2026-09-30-shared-mirrors-server-features.md`.

## 0.22.0

- **BREAKING: `dartway check` holds one shape for imports, tests and spacing, in every package**
  (dartway/dartway#391, #379, #396). Five new errors and a warning, in a section of their own:
  `relativeImport` — a relative `import`/`export` in `lib/` of the Flutter, server or shared package
  (generated files passed over); `testLayout` — a test that mirrors no `lib/` path
  (`test/<path>_test.dart` for `lib/<path>.dart`, `test/<path>/<folder>_acceptance_test.dart` for a
  whole folder), a helper outside `test/support/`, or a test inside it; `testHarnessBypassed` — a
  `ProviderScope`/`DwFakeServer` built by a widget test, a `DwTestServer.start`/`DwAppServer` by a
  server test, outside `test/support/`; `rawSpacing` — a number in a spacer `SizedBox`, a `Gap` or an
  `EdgeInsets.*` or a `spacing:`/`runSpacing:`/`mainAxisSpacing:`/`crossAxisSpacing:` outside
  `ui_kit/`, where the kit's `AppSpace` steps go; `lintsPluginMissing` — the Flutter package does not
  enable the `dartway_lints` plugin, or names neither a version nor a path; and `docCommentLanguage`
  (warning) — a doc comment in `lib/` in another script than the language `setup-ai --language`
  recorded, those the skeleton wrote excepted. `dartway check --fix` rewrites relative imports to
  `package:` (sorting the import block) and moves root-level acceptance tests to
  `test/src/<feature>/`, before checking; `--type` and `--dir` narrow it. `dartway update` enables the
  `dartway_lints` plugin in a Flutter package without it, or raises its caret, pinned to the channel
  as `create` pins it (`--framework-path` pins a checkout by path); a `plugins:` section it cannot
  edit safely is left alone, with the lines to add printed instead. Migration note:
  `docs/migrations/2026-09-30-imports-tests-spacing.md`.

## 0.21.0

- **BREAKING: four new errors in `dartway check` — one way to show a read, wait, open a dialog and
  go to a screen** (dartway/dartway#390, D-116), in their own inspector
  (`dw_flutter_ui_rules.dart`) over every file of the Flutter package's `lib/` but generated code.
  `forbiddenRequestRead`: the `AsyncValue` of `ref.watch(dw.request|pages|table|window(…))` taken
  apart outside `logic/` and the widget-free files of `core/` — a member of it, chained or through
  its bound name (with or without `final`, typed or not, per block; `.value`, `.when(`,
  `.hasError`, a project's own `.section(`), a `switch` or `case` over it, a `.select` of the read,
  the values a `ref.listen` over it hands its callback. `forbiddenProgressIndicator`:
  `CircularProgressIndicator`, `LinearProgressIndicator`, `RefreshProgressIndicator` or
  `CupertinoActivityIndicator` outside `ui_kit/`. `forbiddenNavigationCall`: `showDialog`,
  `showModalBottomSheet`, `showCupertino…` and siblings, `Navigator.push…` and page routes outside
  `ui_kit/` and `core/router/`, and `Navigator.pop`, `GoRouter.of(…).pop`, `context.pop` anywhere.
  `sentinelId`: a route parameter set to `0`/`-1` (`…Params.<name>.set(0)`).
  Read on the source with comments and strings blanked. The skeleton follows: its reads are
  `DwReadBuilder`, its kit has `AppProgressIndicator` and `showAppDialog`, and the core hands the
  kit's loading and failed views to `DwFlutterConfig`. Migration note:
  `docs/migrations/2026-09-30-reads-lists-dialogs-routes.md`.

## 0.20.0

- **BREAKING: two new errors in `dartway check` — one way to hold state and one way to send a
  command** (dartway/dartway#389, D-114). `forbiddenStateHolder`: a `StatefulWidget`
  (`ConsumerStatefulWidget`, `StatefulHookWidget`, …) with its `State` and `setState`, a
  `StatefulBuilder`, or a `ChangeNotifier`/`ValueNotifier` held as state, anywhere in the Flutter
  package's `lib/` but generated code. A class marked `// dw:allow-stateful <reason>` on the line
  above is passed over and listed after the tally (`🔓 Allowed by dw:allow-stateful`); a marker
  with no reason, or on no class, is a finding. `forbiddenCommandCall`: `dw.command` outside a
  feature's `logic/` and `core/` (app-wide wiring) or inside a `try` that catches; a widget running `<Feature>Commands` outside
  `dw.action`, or reading `DwCallOk`/`DwCallRefused`/`DwCallFailed`/`valueOrThrow` outside
  `logic/` and `core/`. Both read the source with comments and strings blanked; refusal text
  built outside the catalogue is stated in the toolkit, not checked. The skeleton
  follows: its kit fields are hooks, the identifier change is an `IdentityChangeController`, the
  sign-in notifier is `AuthController`, the analytics saves are `AnalyticsDashboardCommands`, and
  the router state carries the one marker. Migration note:
  `docs/migrations/2026-09-30-flutter-state-and-commands.md`.

## 0.19.0

- **Four new errors: a project's data has one pattern per problem** (dartway/dartway#388).
  `migrationChangesData` — an `INSERT`, `UPDATE` or `DELETE` in `lib/src/migrations/m*.dart` outside
  `m.backfill(…)`; `workAfterServerStart` — `bin/server.dart` awaiting, or reaching `.db`,
  `.accounts` or `runInContext`, after `start()`; `settingsKeyValueTable` — a row class with a unique
  `String key` beside a `String value`; `fieldPatchMatched` — `DwSetField`, `DwClearField` or
  `DwKeepField` named in the server, shared or Flutter package (`lib/`, `bin/`, `test/`). Migration
  note: `docs/migrations/2026-09-30-seeds-settings-patches.md`.
  A project adopting these names its latest migration under `deploy/config.yaml` > `migrations` >
  `dataChecksAfter` (a new project-level key of that file); only later migrations are judged. A
  write into a framework `dw_*` table is refused in any migration, `m.backfill` included.

## 0.18.0

- **BREAKING: new error check `redundantBangAllowed`** — the server and the shared package's
  `analysis_options.yaml` (or a local file it includes) must raise the analyzer's
  `unnecessary_non_null_assertion` to an error. A stored row's id is `int` now, and `row.id!` hides
  the `!` that guards a real null (dartway/dartway#384, D-113).

## 0.17.0

- **A new warning in `dartway check`: `inlineOwnershipCheck`** (dartway/dartway#387, D-112). In a
  server `*_handlers.dart`, a handler under any rule but a resource rule (`signedIn`, a role check)
  — or a helper of the same file it calls — that compares a row's owner field (`…ProfileId`,
  `authorId`, `ownerId`, `senderId`, `accountId`, …) with the caller and refuses
  `notFound`/`forbidden` (or answers `null` from a `single` handler) is the check
  `DwAccessRule.resource` makes once. A project rule that builds a resource rule counts as one. A
  warning: it reads the shape of the code, and does not fail the run. Migration note:
  `docs/migrations/2026-09-30-ownership-through-access-rules.md`.

## 0.16.0

- **Two new errors in `dartway check`: `forbiddenEnvironmentRead` and `forbiddenHttpClient`**
  (dartway/dartway#386). `Platform.environment` in a server package's `lib/` outside
  `lib/src/core/environment.dart` — and in its `bin/` outside `DwLocalEnvironment.overlay(…)`, or a
  map read there by a variable's name (`env['PORT']`) — and `HttpClient(` or an import of
  `package:http/…` in its `lib/`, fail the check: the environment is read once into
  `AppEnvironment` (`DwEnvironmentReader`), and an outbound request is `ctx.http`. Comments and
  strings are passed over, interpolations are not; `test/` is not judged. A project with either fails
  `dartway check` until it moves — see `docs/migrations/2026-09-29-environment-and-outbound-http.md`.

## 0.15.0

- **New error, `forbiddenDateTimeNow`: the server's `lib/` reads the time as `ctx.now`**
  (dartway/dartway#385). `DateTime.now` and `DateTime.timestamp` — called, torn off or inside an
  interpolation — and `package:clock`'s `clock.now()` where it is imported, prefixed or not, fail
  `dartway check` anywhere under `lib/`, the factory file included; comments and strings are passed
  over, `bin/` and `test/` are not judged. The server's clock is the
  one tests set (`DwTestClock`) and the job queue runs by. Migration note:
  `docs/migrations/2026-09-29-server-clock-and-caller-offset.md`.

## 0.14.0

- **BREAKING: `dartway check` holds the inside of a server feature** (dartway/dartway#381, D-109).
  A feature folder `lib/src/<feature>/` holds `<feature>_<kind>.dart` or
  `<feature>_<part>_<kind>.dart`, the kind one of `feature`, `rows`, `handlers`, `objects`,
  `publications`, `jobs`, `access`, `routes`, and one optional, flat `logic/` subfolder for
  everything else, whose files carry no kind's suffix; a layer-named folder (`domain`, `rows`, `handlers`, `services`,
  `models`, `objects`, `repositories`, `utils`, `helpers`, …) is refused at any depth of `lib/src/`
  (`invalidServerFeatureFile`, new error). And each kind is held by what a file declares: handlers
  only in `*_handlers.dart`, row classes only in `*_rows.dart`, job kinds and definitions only in
  `*_jobs.dart`, `DwHttpRoute`s only in `*_routes.dart`, `DwServerFeature` only in `<feature>_feature.dart`, a named function that publishes
  only in `*_publications.dart`, a named function that takes a row and builds a data object only in
  `*_objects.dart` — and none of them in `core/` (`misplacedServerCode`, new error). Read from the
  source with comments and strings blanked; a closure a handler or a hook runs is not a
  declaration, so publishing inline from a handler stays legal. `helpers`, `repositories` and
  `utils` join the layer names refused at the top of `src/` too (`invalidTopLevelLayout`).
  Migration note: `docs/migrations/2026-09-29-server-feature-closed-file-set.md`.

## 0.13.0

- **The checker's advice names `lib/ui_kit/` for a visual building block** (`notAFeature`,
  `unusedFeatureFile`): `lib/shared/` now holds non-visual helpers only, as the toolkit's feature
  law says (dartway/dartway#380). Wording only; no check changed.
- **BREAKING: the bundled storage is RustFS, not MinIO — `storage: minio` in `deploy/config.yaml`
  becomes `storage: bundled`** (dartway/dartway#331, D-094). MinIO's community edition stopped
  publishing images, and every registry that used to serve them (Docker Hub, quay.io) now answers an
  anonymous pull with `401`; `dartway deploy run` failed on a fresh host at the step that started it,
  and `dartway test`/`dartway_core_server`'s file suites failed the same way on a clean machine. The
  rendered compose services are renamed `storage`/`storage-init` (were `minio`/`minio-init`), the
  data volume is renamed `<project>_storage_data`, and `storage-init` is a generic, pinned S3 client
  (`amazon/aws-cli:2.31.13`) rather than MinIO's own — it sets bucket CORS through the S3 API
  (`put-bucket-cors`) on both buckets instead of the server-wide environment variable MinIO's
  community edition needed in its place. Migration note:
  `docs/migrations/2026-09-26-storage-minio-to-rustfs.md`.
- **`dartway deploy check` resolves every pinned base image against its registry** (`images-resolve`,
  new remote check): a manifest `HEAD`, with the anonymous bearer token the registry's own
  `WWW-Authenticate` challenge asks for — the same handshake `docker pull` performs, without pulling
  a layer. Catches a vanished tag (Postgres, nginx, certbot, and with `storage: bundled` the storage
  and its init image) before `deploy run` reaches the step that actually pulls it, which is where
  this exact failure used to surface for MinIO, well after the images that build locally had already
  succeeded. Resolved through `registry_mirror` exactly as the renderer resolves them into the
  compose file, so the check asks about what `run` actually pulls, not the upstream name behind a
  mirror that serves it instead; a transient answer (no route, a timeout, a rate limit, a 5xx of the
  registry's own) is reported as a note rather than failing the deploy over this machine's own
  network.
- **`deploy run` refuses to start a stack that would create an expected data volume empty beside a
  data volume of the same project that already holds real state** (`data-volumes`, new step, right
  after the compose configuration is checked and before anything is built). `deploy setup` has run
  this guard since the volume rename above; `run` did not, so a server only ever `run` again after a
  config change — never `setup` again — could start `storage: bundled`'s volume empty, have
  `storage-init` write its probes into it, watch the outside checks read those probes and pass, and
  serve every real file as a 404 from then on. Passes once the expected volume exists, whatever else
  is still on the server beside it: an old volume from before the change is the rollback copy, and
  neither command asks for it to be removed before passing.
- **`deploy setup` no longer fails the "Deployment user" step when a group named like `deploy_user`
  already exists** (#328). DigitalOcean's Ubuntu 24.04 image ships an empty system group `admin`
  (no user); the plain `adduser` setup ran refuses to create a same-named group over it. Setup now
  reuses the existing group with `--ingroup`, unless the group is one a sudoers rule already grants
  privileges to (`%admin` on Ubuntu's stock sudoers; `%sudo` on both Debian's and Ubuntu's) —
  joining one of those would hand the "unprivileged" deploy user a path to root, so setup refuses
  instead and asks for a `deploy_user` that does not collide with it. This guard alone does not fix
  a config that sets `deploy_user: admin` explicitly on such a host — that still refuses, by design.
- **`deploy_user` is optional in `deploy/config.yaml`, defaulting to `dw_admin`** (#328). This is
  what actually closes #328: a name an operator picks can collide with a group a cloud image already
  ships (the `admin` case above); a fixed default under the `dw_` prefix does not, on any stock
  image or package, so an operator who leaves `deploy_user` unset never meets the collision. Additive:
  a config that already names `deploy_user` is unaffected.
- **`database: bundled | external` in `deploy/config.yaml`** (dartway/dartway#325, D-096), the same
  vocabulary `storage` uses. `external` renders no `postgres` service, volume or `depends_on`;
  `DW_DATABASE_HOST`, `_PORT`, `_NAME`, `_USER` and `_PASSWORD` become required secrets — a managed
  provider (DigitalOcean Managed Postgres, RDS, Cloud SQL, …) names its own, none of them derivable
  the way the bundled container's are — and the secret store accepts these names precisely because
  the compose file no longer sets them (it still refuses them for `bundled`). `DW_DATABASE_SSL`
  (default `true`) and `_MAX_CONNECTIONS` (default 10, the pool ceiling — one server holds this many
  plus one more for its session `LISTEN`, and a managed plan's usable total is often in the tens)
  stay optional; the server already defaults both. `dartway deploy check` gained
  `database-reachable`: `DW_DATABASE_PORT`/`_SSL`/`_MAX_CONNECTIONS` are validated exactly as the
  server parses them, then on the deployment host over SSH — a managed provider's firewall usually
  trusts that address, not the maintainer's machine — a throwaway, pinned Postgres client attempts a
  real connection with the same `sslmode` the server itself will use (`require` unless
  `DW_DATABASE_SSL` is explicitly `false`) and reports why it failed (a bad stored value, DNS,
  refused, a timeout, authentication, or TLS not offered), never a bare TCP probe, which would miss
  the last two. Documents DigitalOcean Managed Postgres specifically: the direct port, not its
  PgBouncer transaction-mode pooler, which silently breaks the session `LISTEN` and the migration
  lock. Additive: an existing config with no `database` key keeps deploying exactly as before, so
  there is no migration note. `sslmode=verify-full` with a CA file is tracked separately
  (dartway/dartway#342).
- **`database-reachable` verifies the server's certificate when `DW_DATABASE_CA_FILE` names one**
  (dartway/dartway#342, D-102), instead of only encrypting the channel: the same `verify-full` the
  server itself connects with once `dartway_orm`'s `DwDatabaseConfig.caFile` is set. The value must be
  exactly where the file is mounted (`${DwStack.secretFilesDir}/<name>`, e.g.
  `/run/secrets/db-ca.pem`) — the server opens the literal path, so a value merely ending in a
  declared name but mounted, or not mounted, anywhere else is refused, not silently mounted from
  wherever it happens to sit — with `<name>` declared under `requires.files` and actually delivered
  with `dartway deploy secret put-file`. Also refused: naming an undeclared or undelivered file, and
  setting it together with `DW_DATABASE_SSL=false`, a contradiction the server itself also refuses.
  Additive: no `DW_DATABASE_CA_FILE` keeps today's `require`.
- **BREAKING: `secret push` no longer replaces a server value that differs from the local one — it
  refuses the whole push, naming every differing key, and sends nothing** (#330, D-097). Its default
  is now additive: it sends a key the server lacks or holds empty, leaves a key whose server value
  already matches alone, and — this is the behaviour change — stops rather than silently overwriting
  a key whose server value differs. `--overwrite KEY[,KEY…]` replaces exactly those named keys on
  purpose; there is no `--overwrite-all`. A generated key (`DwStack.generatedSecrets` — the database
  password for `database: bundled`, and with `storage: bundled` the storage keys) is bound to the
  data already on the server on every path that touches it, not only replacing it: dropping it with
  `--prune` or blanking it with `--allow-emptying` needs it named in `--overwrite` too, on top of
  whichever of those two flags is otherwise enough on its own for an ordinary key. The comparison
  runs on the server itself (`DwSecretStore.plan`, over the candidate's own encoded lines sent on
  stdin, read directly rather than staged in a file of their own) — only key names (including every
  name the store currently holds, so `--prune`'s orphaned keys are read in the very same pass rather
  than by a second, separately-timed call) and a `cksum` fingerprint of the store travel back, never
  a value. `writeAll` is asked to check that same fingerprint right before it writes, so a second
  push (or a hand edit) landing in between refuses the write rather than being silently undone by
  it — its own plaintext, like the rest of the store's writes, is staged inside the store's own
  directory, never the shared system temp one; a store that exists but cannot be read fails the
  comparison outright rather than reading as absent, which would have classed every key `add` and
  let the push through as a full replace; and a candidate key the comparison does not place in any of
  its three sets is refused rather than sent unexamined. Before sending anything, `push` prints a
  per-key plan (`add` / `keep (same)` / `overwrite` / `differs — refused` / `drop`) — the same shape
  `--dry-run` prints, only followed by the actual send. This is a CLI command's own default changing,
  not a change to generated project code, so there is no migration note.
- **`template/CLAUDE.md` no longer lists the tracker and how work is filed among a project's own
  conventions** (dartway/dartway#324). A project's queue moves faster than its code — one moved three
  times in three weeks — and the rule kept sending the next session to whichever address had already
  changed. Where a task comes from and how it is handed over is not a repository rule: the task's own
  brief carries what the work needs, the same stance this repository's own root `CLAUDE.md` already
  takes for itself.
- **Fix: `deploy run` and `deploy setup` resolve the project root from where the CLI actually runs**
  (dartway/dartway#343). `deploy check` already walked up from the working directory to find the
  project (`deployProjectRoot()`), so a project pinned to its Flutter package (`cd u90_flutter &&
  dart run dartway_cli:dartway deploy …`) passed `deploy check --local` — but `runDeploy` and
  `runSetup` each read `Directory.current` a second time instead of the root the check had already
  found, so `deploy run` refused with "missing Dockerfile" for files that were one level up, and
  `deploy setup` rendered `deploy/compose.override.yml` and `deploy/nginx.d` from the wrong directory.
  `DwStack` now carries the project root it was built from; both commands read it from there instead
  of recomputing it.

## 0.12.0

- **BREAKING: `dartway check` holds the server's `lib/src/` to a layout** (D-093, `invalidTopLevelLayout`): folders only — `core/`, `migrations/`, and one per feature declaring its `DwServerFeature` in `<feature>_feature.dart`. A file at the top of `src/`, a layer folder (`handlers/`, `rows/`, `entities/`, `domain/`, `objects/`, `publications/`, `services/`, `models/`) or a feature folder without its declaration is an error. `src/` used to be "the project's": three projects on the framework arranged it three ways, and the largest arranged it two ways at once, with one area in four folders. The skeleton `dartway create` hands out has the layout. Migration note: `docs/migrations/2026-09-25-server-features.md`.
- **`readFrameworkVersions` and `frameworkPackageDirectories` walk `packages/` one level deep, not two.** `packages/` has been flat since the 1.0 rewrite; the leftover second level silently read a package's own `example/` (`dartway_core_flutter_example`, `dartway_lints_example`) as a framework package in its own right, which `dartway update`'s framework-gap report and `--framework-path` both then acted on. Neither exists as a `dartway_*` release.
- **`dartway update`'s migration notes sort by the version they land in, then by name — the file's date decides between two different days, not the version.** Sorting by file name put same-day notes out of order (2026-09-24's `account-deletion-choice` printed before `contract-version`, though it lands later); sorting by raw version across every note put a satellite's small number (`dartway_lints` `0.4.0`) ahead of an earlier family note (`0.20.0-dev.2`) that has nothing to do with it. Now: the file's date first, then — only for two notes of the same day naming a package in common — the version that package lands at, then the file name.
- **Retired the 0.x-era `setup-ai`/`update` recognition that no rewrite project can still trigger**: the `dartway-audit.md` command-retirement entry, the report of root `dartway_notes.md`/`dev_notes.md` journals and of `tools/dw_claude_setup/` leftovers from the pre-CLI shell installer.

## 0.11.1

- **The toolkit's resident `CLAUDE.md` is half its size** (#281): 7 400 words paid in every session of every project become 3 450. The laws stay resident; what only one kind of task needs moves to skills loaded on demand — `dartway-documentation` (specs, ADRs, dev notes), `dartway-framework-notes` (filing a finding upstream), the old shapes into `dartway-update`, localization in full into `dartway-ui-kit` — each with a resident line saying when to load it.
- **`dartway create` pins the `dartway_lints` analyzer plugin** (#295): the skeleton enables it under `plugins:` in the Flutter package's `analysis_options.yaml` by a path into this repository, which `create` replaces with the version the template was taken from — or the checkout's path with `--framework-path`. The skeleton no longer depends on `custom_lint` or `dartway_lints`.
- **The toolkit teaches the CLI a project pins** (#289). 133 command blocks in `toolkit/` and the skeleton's README wrote `dartway generate|check|test|deploy|dev|stats`, the form those commands refuse from any `dartway` but the pinned one since 0.10.1; they now write `dart run dartway_cli:dartway <command>`, run in the Flutter package, and `toolkit/CLAUDE.md` says so once. The public documentation (`docs/`, 97 more) is rewritten the same way. `toolkit_pinned_commands_test.dart` fails on a bare one in code — in the toolkit, the skeleton's README and `docs/` — against the CLI's own list of project commands (`DwPinnedCli.projectCommands`).
- **`dart run dartway_cli:dartway test` runs from the Flutter package** (#289): it read only the working directory and answered that there was no `*_server` package — in the one place the pinned form runs.
- **`By check` counts every section** (#287). The tally belonged to the Flutter section and left out what the sections before it found: a layout error was shown and counted in `Errors: 4`, while the tally named three. It is now printed by the command over all of them, and a tally that disagrees with the error count stops the check as a bug in it. The generated-code section's fix names the pinned command too.
- **The web image installs the Flutter the project's `.fvmrc` names** (D-082). The skeleton's build stage cloned nothing and started `FROM ghcr.io/cirruslabs/flutter:3.44.0`, while the skeleton pins 3.47.2, which no image publishes: Flutter pins some of the packages an app resolves, so the image's `pub get --enforce-lockfile` refused every new project's lock. A new local check, `web-flutter-version` (error), compares an image built `FROM` a Flutter image with `.fvmrc`. Migration note: `docs/migrations/2026-09-23-web-image-flutter-from-fvmrc.md`.

- **The web image grants everyone read on the files it serves** (#292). The skeleton's `Dockerfile` runs `chmod -R a+rX build/web` after the build: `COPY` keeps modes, and under a deploy user's umask of `077` the assets a commit added were served as 403 while every page answered 200. A new local check, `web-file-modes` (warning), names a web image that leaves the modes to the build host. Migration note: `docs/migrations/2026-09-23-web-image-file-modes.md`.
- **Deploy ssh sessions notice a dead connection** (#286): every `ssh` and `scp` call opens with `ServerAliveInterval=30` and `ServerAliveCountMax=4`. A step is watched through one session that is silent while a web build runs; a NAT dropped it, and the CLI waited for an hour on a step that had long finished. A connection lost now ends within two minutes, and the watch reconnects and reads the step's result.
- **A project without `pubspec.lock` is told to resolve, not to edit its images** (#278). `locked-dependencies` said "add `--enforce-lockfile`" to a project whose Dockerfiles carry it — the first deploy of a project nobody has resolved yet, since `dartway create` does not copy the skeleton's lock. It now says to run `pub get` in both packages and commit the locks.
- **`dartway update` compares a framework package's pre-release correctly against the release it precedes.** `isAtLeastVersion` ignores a pre-release suffix entirely — right for an SDK check, wrong here: a project on `dartway_core_server` `0.20.0-dev.1` read as caught up with a channel already at `0.20.0`, and a migration note keyed to `0.20.0-dev.4` looked satisfied by every other `-dev.N` of that release. `isPackageAtLeastVersion` (`package:pub_semver`) is the comparison a package's own version needs: a pre-release sorts below the release it precedes, and its identifiers compare numerically (`dev.9` below `dev.10`), never as text (review of #308).

## 0.11.0 — DartWay 1.0

**Breaking:** `dartway deploy secret …` is now `dartway secret …` (D-078).

- **`doctor` asks for Flutter `>=3.44.0`** (#290), the minimum `dartway_core_flutter` compiles on.

- **`dartway quickstart` names `DW_ADMIN_IDENTIFIER`**, the framework's own name for the first administrator (D-079); the skeleton's `APP_BOOTSTRAP_ADMIN` is gone.

- **`local` is an environment of `deploy/config.yaml`, and `dartway secret` is a top-level command** (D-078). The two files that describe every environment now describe this machine too: `config.yaml > local` holds what the team shares, `secrets.yaml > local` what is the developer's own, and `dartway secret list --env local` answers "what is set, what is missing" in the same words it answers for a server. `dartway deploy secret …` is now `dartway secret …`, and `init`, `put-file`, `push` and `pull` say why they have nothing to do for `local`.

- **`requires` is read at the top level of `deploy/config.yaml`**, where it states what the project needs wherever it runs; an environment's own `requires` adds to it. The same list repeated per environment drifted in the one direction nobody notices — the environment that was forgotten is the one whose deploy stops.

- **Two advisory checks in `dartway check`**: `localSecretMissing` (a `requires` secret with no value for `local`) and `devComposeDrifted` (the development containers' credentials in `docker-compose.yaml` against the ones the server is told to reach them by — two files stating the same password, with nothing making them agree). `migrationsDrift` takes the same local environment, so it stops asking for a `DW_DATABASE_*` the project has already declared.

- **`deploy/config.yaml.example` is gone**: the skeleton ships `deploy/config.yaml` itself, with `local` filled in and a deployment commented out beside it. A new project runs before it has a server to deploy to, and one file is one file.

- **BEHAVIOUR (deploy): `deploy run` renders `docker-compose.yml` and `nginx.conf` on every run** (D-075), from `deploy/config.yaml` and the CLI's own version, saying of each whether it changed. They used to be written by `setup` alone, and a stack rendered by an older CLI met a build argument it did not carry: the deploy died inside `docker build` blaming the project's Dockerfile, while the file to fix was on the server and in no repository (reported by U90). A hand edit on a server is therefore overwritten — project additions belong in `deploy/compose.override.yml` and `deploy/nginx.d/`, which are not touched.

- **`deploy` and `deploy secret` find the project instead of demanding to be run from its root.** They read the working directory, so `dart run dartway_cli:dartway deploy …` — which runs from the package that pins the CLI — answered "no `*_server` package found" to somebody standing inside their own project (reported by Studio). They now walk up to the directory holding the `*_server` and `*_shared` packages, as `generate` and `check` already did.

- **`locked-dependencies` judges a package's own `pub get`, not a stage building something else.** A multi-stage Dockerfile that checks out another repository and builds it in its own `WORKDIR` had that `pub get` attributed to the project and checked against the project's lock file (reported by Studio). Instructions resolving elsewhere are now named in the verdict and not judged: another repository's lock is not this project's to check.

- **The web image is built with `STUDIO_APP_ORIGIN`** — the address it answers on, which the Studio binding checks a connecting Studio's token against. Projects kept it as a default in their Dockerfile, where a renamed stand makes it quietly wrong (reported by U90).

- **`deploy run --resume` no longer repeats a step that failed**: it stops with that step's recorded reason and output (`step_failed` with `resumed: true`), and `--retry-failed` is how to run it again. A self-deploy resumes after every interruption, so a failing step used to be repeated until the attempts ran out, stopping the server each time (reported by Studio).

- **The proxy and certbot images are pinned** (#269): `nginx:1.30.5-alpine`, `certbot/certbot:v5.8.0`, like Postgres and MinIO. A server set up earlier keeps the old names in its rendered `docker-compose.yml` until `deploy setup` renders it again.

- **BREAKING (deploy): the server is replaced one version at a time** (D-070). `deploy run` no longer starts the new server beside the serving one: the serving server stops gracefully, the new image migrates in a one-off run (`DW_MIGRATE_ONLY=true`), the new server starts; on a failure the previous image is started again. The gap is covered by the client's retries. Step `server-candidate` is gone; `server` does all of it.

- **`dartway check` holds the contract's names to the naming law** (`contractNameInvalid`, error — #167): a DTO in the shared package named one word, a read not named `Get…`/`List…`, or a command named like a read. The class name is the wire name, so the check fires before a build carries it. The example's `SearchChatMessages` is `ListChatMessagesMatching`.

- **`dartway create --language` sets the app's language** (#230). The project keeps only that translation (`en` or `ru`), makes it the template ARB and `AppLocaleController.productLocale`, and regenerates `lib/l10n/gen`. The skeleton no longer takes the device's language, and no longer falls back to whichever ARB sorts first.

- **A host added to a live stand gets into its certificate.** `deploy run` left a lineage certbot already managed untouched, so a `storage_domain` or `site` added later was served with a certificate that did not name it. The certificate step now reads the lineage's domains and extends it (`--expand`, same name) when a served host is missing.

- **MinIO comes from quay.io** (#264): MinIO removed `minio/minio` and `minio/mc` from Docker Hub, so every `storage: minio` deploy failed at the pull. Same releases, `quay.io/minio/…`; `dartway test` and the template's compose file follow. **`registry_mirror` now applies only to official Docker Hub images** (`postgres`, `nginx`): prefixed onto an image of another registry or a Hub organisation it named nothing. A server set up earlier keeps the old image names in its rendered `docker-compose.yml` until `dartway deploy setup` renders it again.

- **`dartway deploy run` survives the machine that started it** (D-068, #266). Every step runs on the server detached from the `ssh` session (`setsid`, streams and exit code in `~/.config/<project>/deploy-run/`); a broken connection is waited through for up to fifteen minutes. `--resume` finishes the deployment the server remembers — passing over done steps, waiting for a running one, running the rest — and a new run refuses while a step of the last one still runs. `--progress json` writes step events as JSON lines on stdout (prose on stderr). `now at` and the `revision` event are also reported with `--skip-git-update`.

- **`dartway check` names an override the framework caught up with** (`frameworkOverrideOutlived`, warning — D-032). A `dependency_overrides` version pin on a `dartway_*` package is reported when a resolved framework package depending on it already allows the locked version, with the file to edit; path and git overrides are left alone.

- **BREAKING: `dartway create` hands out the 1.0 skeleton.** Three packages — `*_shared` (the
  contract), `*_server` and `*_flutter`, no generated client package — with sign-in by a one-time
  code to a phone or an e-mail, the terms accepted on sign-up, a profile with a photo and its
  sign-in identifiers, roles, an admin panel with a members table and user cards, migrations, a
  dev seed and tests on both sides. Everything is named after the project: packages, types, the
  generated registry and schema (`dartwayStarter…` becomes `myApp…`) and the default storage
  buckets (`my-app-public`, `my-app-private`, as `dartway deploy` names them). The result is
  formatted, since the renames move line breaks. A project name must now also fit a bucket name:
  no leading, trailing or doubled underscore, at most 55 characters.

- **`dartway create --framework-path <monorepo>`** resolves the new project's framework packages
  from a local checkout by path — `dependency_overrides` onto `<monorepo>/packages` for exactly
  the packages each pubspec reaches — instead of pub.dev, and takes the template from the same
  checkout. For building the framework, and for versions not yet published.

- **`dartway deploy check` refuses a path dependency that leaves the project**
  (`dependencies-inside-context`, error). Images build from the project root, so a package taken
  by path from above it — a local framework checkout, the overrides `--framework-path` writes —
  resolves in every working copy and fails inside the image as `pub get` exit code 66. Read from
  `dependencies`, `dev_dependencies` and `dependency_overrides`, through sibling packages, and from
  `pubspec_overrides.yaml` unless `.dockerignore` keeps it out. `docker-context-packages` no longer
  also asks to `COPY` such a package. The template's and the example's `.dockerignore` keep
  `**/pubspec_overrides.yaml` out of images.

- **`dartway deploy setup` takes back a directory on the way to the secret store that the deploy
  user cannot write** — `~/.config` left as root's by an earlier tool — non-recursively and only
  inside the user's own home, and says so. It used to fail as "cannot change permissions … No such
  file or directory", naming neither the directory nor its owner; when the ownership cannot be
  changed, the failure now names both and the `chown` that fixes it.

- **`dartway create` records the language and the notes tracker it was given**, so the first
  `dartway update` keeps them instead of reinstalling the toolkit in the defaults.

- **BREAKING: a CLI with the framework beside it hands out its own revision.** `create`,
  `setup-ai` and `update` without a named checkout or a chosen channel (`--channel`,
  `DARTWAY_BRANCH`, or the channel a project recorded for `update`) take the template and the
  toolkit from the monorepo the CLI runs from — activated by path or by git ref, or run inside the
  monorepo — instead of cloning `stable`. The rewrite's CLI used to create 0.x projects that way.
  A CLI installed from pub.dev has nothing beside it and still takes `stable`. A project that
  recorded a channel is not moved onto the checkout by a plain `setup-ai`: it is refused, naming
  `--channel` and `--local-repo`.

- **BREAKING: the toolkit is installed whole or not at all.** `setup-ai`, `update` and `create`
  require a `*_shared` package beside `*_server` and `*_flutter`, and the installer no longer knows
  `__CLIENT_PKG__` (1.0 has no client package; it filled the token with an empty string, and an
  older toolkit's skills then named `..//lib/src/protocol`). Before writing anything the installer
  reads the toolkit and refuses one holding a token it does not fill, or would fill with nothing,
  naming each token and its file.

- **`dartway test` starts a MinIO beside the Postgres** (`DW_STORAGE_ENDPOINT`/`_ACCESS_KEY`/
  `_SECRET_KEY`, the image a deployment runs, in memory, on a port Docker picks) so upload
  suites run like the database ones. `--no-storage` skips it; `--storage-image` picks the image.

- **BREAKING: `dartway check` judges a 1.0 project.** Removed with the Serverpod core:
  `crudConfigMissing`, `crudConfigUnregistered`, `crudRuleUntested` (there are no CRUD configs)
  and `generatedCodeUnformatted` (the generator formats its own output). Added:
  `generatedCodeStale` (error) runs the project's `dartway_generator --check`, and
  `migrationsDrift` (error) runs `bin/migrate.dart check` when `DW_DATABASE_*` names a Postgres —
  without one it says it did not run. The server layout rule now expects `lib/<package>.dart`,
  `lib/generated/` and `lib/src/` with `src/migrations/migrations.dart`, instead of the 0.x
  `server.dart` and `crud`/`endpoints`/`models` areas. `toolkit_law_list_test` is skipped until the
  toolkit is rewritten for 1.0 (D-033): its law table still names the removed checks.

- **`dartway quickstart` and `dartway doctor` describe 1.0**: the server configured by its
  environment and migrating as it starts, Postgres and MinIO from `docker compose`, the dev seed,
  `APP_BOOTSTRAP_ADMIN`, `dartway dev web` for the browser, and the checks a change passes.

- **BREAKING: `dartway deploy` deploys the 1.0 stack, and nothing of Serverpod is left in it.**
  One server process configured by its environment alone, behind one front proxy serving three
  hosts (R2.7): `app` — the Flutter web image, with `/dw/` (the `/dw/live` WebSocket upgrade
  included) and `/health` proxied to the server on the same origin; `api` — the server for mobile
  apps and webhooks; and an optional static `site`. Postgres 17, an optional MinIO with its bucket
  and the CORS rule a browser needs for a presigned PUT, certbot. The Serverpod configuration
  reader, `passwords.yaml`, the insights and web-server ports, Redis and the migration-output
  parser are gone.

  `deploy/config.yaml` describes the whole environment — `api_domain`, `app_domain`, `site`,
  `storage: minio|external` with `storage_domain` — and refuses a key it does not know, so an
  older config fails naming `web_app_domain` rather than deploying without it. Every problem is
  reported at once.

- **The secret store is an environment file.** `~/.config/<project>/secrets.env` on the server,
  `KEY='value'` lines Compose takes literally. Every deploy renders the checkout's `.env` from it
  and refuses — by key name, never by value — a missing or empty required secret, a malformed
  line, a duplicate, or a name the compose file sets itself and would silently override.
  `secret init` generates `DW_DATABASE_PASSWORD` (and the MinIO keys); `set`, `list`, `put-file`,
  `push` and `pull` keep their shape, the last two against a git-ignored `deploy/secrets.yaml`.
  Secret files are mounted at `/run/secrets/<name>`.

- **The migration outcome is the server's exit.** The server applies its migrations as it starts
  and exits non-zero when one fails, so `run` starts the new image *beside* the serving one and
  waits for `/health`; an exit prints the server's own log and stops the deploy with the previous
  version still answering. Only then is the server replaced, and waited for.

- **`run` ends by asking from outside**, with the same probes `deploy check` uses: `/health` 200
  through both hosts, the Flutter `index.html` on the app host with a revalidating cache policy,
  the cache policy of the build's entry points, `/dw/live` upgrading through both hosts with the
  server answering on the socket, the site, and the storage preflight from the app's origin.
  Before the proxy restart it compares every upstream of the rendered configuration and the
  snippets with the applied stack, runs `nginx -t` inside the running proxy, and after the
  restart checks the proxy is still running.

- **New local checks**: the server image receives SIGTERM itself (exec-form `ENTRYPOINT`); the web
  image declares `ARG DW_BACKEND_URL`; a deployed site directory is committed; required secret
  names are not ones the compose file sets. `.dockerignore` may admit packages by role glob
  (`!*_server/`), and the template and example ignore files do — they no longer restate the package
  list. The example's ignore file had admitted a package that no longer exists and kept out the
  shared one both its images copy.

- **A local proof of the whole deployment**: `dart test -t docker --run-skipped
  test/deploy_local_stack_test.dart` renders the example's stack in plain-HTTP mode, runs the
  deploy steps through a local shell, and verifies it — a real sign-in and DTO call through both
  hosts, a presigned upload through the storage host, a failing candidate that leaves the
  running server serving, and a graceful stop.

- **`dartway test` passes `DW_DATABASE_*`** (the maintenance database, TLS off) to the suite;
  `doctor` no longer checks a Serverpod CLI; `create` no longer writes a `passwords.yaml`; a
  project needs no `*_client` package to be recognised.

- **`dartway dev` — the web app and the server on one origin, as deployed (D-039).** `dev proxy`
  serves `http://localhost:8000`: `/dw/*` (the `/dw/live` socket included) and `/health` to the
  server, everything else to a Flutter web dev server (`--web`) or a build (`--web-dir`, with the
  `index.html` fallback and the `Cache-Control` of the project's web image `nginx.conf`). `dev web`
  runs `flutter run -d web-server` compiled against that origin with the proxy in front, and stops
  both together. The browser's `Host` is passed on as the deployed Nginx passes it, so the live
  socket's origin check passes without `DW_ALLOWED_ORIGINS`; sockets — the live one and Flutter's
  hot-reload one — are tunnelled as bytes, close codes included, and responses stream unbuffered.
  Replaces the proxy each project wrote for itself.
