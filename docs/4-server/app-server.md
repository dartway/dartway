# The application server: what does `start()` do, and how is it configured?

A DartWay server is one `DwAppServer` object in the project's server package and one process
running it. It is built from declarations — the protocol, the handlers, the rules — and refuses to
start when they disagree, so an inconsistency is found at deploy time instead of by the first user
who presses the button.

## The constructor

```dart
abstract final class DartwayExampleServer {
  static DwAppServer build({
    required DwDatabaseConfig database,
    DwFileStorageConfig? storage,
    int port = 8080,
    DwAuthConfig? auth,
    DwServerSettings settings = const DwServerSettings(),
    required String? adminIdentifier,
    DwPushModule? push,
    DwServerClock clock = DwServerClock.system, // a DwTestClock in tests
  }) => DwAppServer(
    protocol: appProtocol,
    schema: dartwayExampleSchema,
    migrations: appMigrations,
    migrationsDirectory: 'lib/src/migrations',
    database: database,
    auth: auth ?? AccountAuth.config,
    features: [
      profileFeature,
      scheduleFeature,
      bookingsFeature,
      contentFeature,
      chatFeature,
      adminFeature,
      accountFeature(adminIdentifier: adminIdentifier),
    ],
    files: storage == null
        ? null
        : DwFileStorage(storage, rules: uploadRules, canRead: canReadFile),
    modules: [
      push ?? AppPush.module(eligibility: ProfileAccess.pushEligibility),
    ],
    port: port,
    settings: settings,
    clock: clock,
  );
}
```

That is `example/dartway_example_server/lib/dartway_example_server.dart`. The skeleton has the same
shape in `DartwayStarterServer.build`; `bin/server.dart` builds it from the environment, and tests
build it on a free port against their own database.

| Parameter | Required | What it is |
|---|---|---|
| `protocol` | yes | the `DwWireProtocol` both sides speak |
| `schema` | no | the `DwDatabaseSchema` the row classes declare; checked after migrating |
| `migrations` | yes | the project's migrations (namespace `app`) — [migrations](migrations.md) |
| `database` | yes | a `DwDatabaseConfig` — [database](database.md) |
| `auth` | yes | a `DwAuthConfig` — [auth and identity](auth-identity.md) |
| `features` | yes | the project's areas, each a `DwServerFeature(name, handlers:, channels:, jobs:, routes:)` declared in its own folder: one `DwCallHandler` per request and command ([handlers](handlers-and-context.md)), a `DwChannelRule` per channel kind it owns ([channels](../2-core/channels-and-realtime.md)), its jobs ([jobs](jobs.md)) and its doors for callers that are not the app ([routes](routes.md)). `server.handlers` and `.jobs` read them together with every module's ([`modules:`](push-delivery.md#wiring), a `DwServerModule` answers calls and runs jobs too); `server.channels` and `.routes` read features' only — a module has neither. A feature's name is its folder under `lib/src/`: lower-case, and once |
| `files` | no | a `DwFileStorage`; without it file calls fail — [uploads](uploads.md) |
| `modules` | no | framework satellites — push, analytics — each a `DwServerModule` contributing its own migrations, calls and jobs; their calls and jobs are part of `server.handlers` and `.jobs`, alongside features' (a module has neither channels nor routes) — [push delivery](push-delivery.md), [analytics](analytics.md) |
| `port` | no | `8080`; `0` binds a free port (`server.boundPort` tells which) |
| `address` | no | `InternetAddress.anyIPv4` |
| `alerts` | no | a `DwAlertSink`; the log by default — [alerts](alerts.md) |
| `logger` | no | a `DwServerLogger`; `DwConsoleLogger` by default |
| `settings` | no | `DwServerSettings`, below |
| `clock` | no | a `DwServerClock`, `DwServerClock.system` by default: what every context reads as `ctx.now` and what the job queue decides due times by; a test passes a `DwTestClock` — [time](handlers-and-context.md#time-ctxnow-and-the-callers-offset) |

## What `start()` does, in order

1. **Validates the declaration** and throws `DwStartupException` listing *every* problem at once:
   - a handler for a class the protocol does not register, two handlers for one class, or a
     handler for a framework call (`DwRequestCode`, `DwStartUpload`, …);
   - a request or command class the protocol registers and no handler answers;
   - an access check written for another call class than its handler's;
   - a channel kind without a name, with `:` in it, or with two rules;
   - a job named `dw.…` (the framework's), declared twice, recurring with a non-positive interval,
     or with fewer than one attempt;
   - an `allowedOrigins` entry that is not a full origin;
   - a file storage problem (a public rule without a public bucket, a bad bucket name, …);
   - a route under `/dw`, on `/health`, not starting with `/`, or declared twice.
2. **Probes the file buckets**, when `files` is set and its `verifyBuckets` is on — before
   anything opens, because a private file behind a public bucket is already leaked
   ([uploads](uploads.md#the-two-buckets)).
3. **Opens the database pool** and proves it with one real connection, so a wrong password fails
   here and not on the first request.
4. **Applies migrations**: the framework's own (namespace `dw`, `DwAppServer.frameworkMigrations`)
   and the project's (`app`), through the same runner and the same refusals as
   `bin/migrate.dart apply` ([migrations](migrations.md#what-the-server-does-on-start)).
5. **Checks the schema**, when `schema` is given: every table and column it declares must exist.
   Only absences fail — a migration missing from the list would otherwise surface as handlers
   failing on their first query. Extra tables, columns, types and indexes are left to
   `migrate check` in CI: a server must not refuse to start over an index an operator added by
   hand.
6. **Starts the job executor**: syncs the recurring schedule, listens for job notifications and
   starts `jobWorkers` workers ([jobs](jobs.md)).
7. **Binds one port** on `dart:io` (D-028) and answers:

   ```
   POST /dw/<WireName>   requests and commands
   GET  /dw/live         the live update socket
   GET  /health          liveness and database reachability
   *                     the project's routes, by exact path
   ```

8. **Watches SIGINT and SIGTERM** and stops gracefully on either.

Any failure closes what was already opened and rethrows. `bin/server.dart` does not catch it, so
the process exits non-zero and the deploy sees a failed start rather than a server that half runs.

`start()` returns once the port is bound; the process stays alive because the port is open.

## `/health`

`GET` or `HEAD /health` runs `SELECT 1`: `200 ok`, or `503 database unavailable` (logged as a
warning). While the server is stopping it answers `503 stopping`. Any other method is `405`. It
takes no token and reveals nothing else, so a load balancer or the deploy's probe can call it.

## Stopping

`stop()` — or SIGINT/SIGTERM — stops in this order, each wait bounded by
`DwServerSettings.stopTimeout`:

1. stops accepting connections; calls in flight finish and are answered, their updates delivered;
2. closes every live socket with `1001` (`DwCloseCode.serverStopping`), so clients reconnect to
   the next process instead of reporting an error;
3. waits for running jobs;
4. closes the port, the database pool and the storage client.

A deploy that kills the process without a signal skips all of it: calls are cut mid-answer and a
non-transactional job runs again after its lease.

## `DwServerSettings`

Every limit exists because something unbounded would otherwise grow. The defaults suit a mobile
app on one server process.

| Field | Default | Why it exists |
|---|---|---|
| `maxBodyBytes` | 1 MiB | The largest call body; a call over it is malformed (`400`). A handler can override it for its own call; a route passes its own to `DwHttpRequest.bytes` (`413` over it). |
| `bodyReadTimeout` | 30 s | A body dripped one byte at a time holds a connection and a buffer. A late call body is malformed (`400`); a route's is `408`. |
| `pingInterval` | 20 s | Live sockets are pinged; a peer silent until the next ping is dropped, instead of lingering until TCP gives up on a dead mobile link. |
| `outboundLimitBytes` | 8 MiB | Characters queued to one socket; past it the socket closes as a slow consumer rather than growing the server's memory. |
| `maxLiveMessageBytes` | 64 KiB | The largest inbound live message (a token or a channel name). |
| `closeGrace` | 5 s | How long a socket close handshake may take before the socket is destroyed. |
| `stopTimeout` | 15 s | How long `stop()` waits for calls and jobs. |
| `allowedOrigins` | `{}` | Browser origins, besides the one the socket is served on, allowed to open the live socket. Below. |
| `tokenCacheSize` | 10 000 | Resolved session tokens kept in memory, so a call authenticates without a query. `0` disables the cache. |
| `tokenCacheTtl` | 1 min | How long a resolved token is trusted. Revocations in this process apply at once; this bounds how late one made elsewhere is noticed. |
| `jobWorkers` | 2 | Concurrent job executions in this process; `0` runs none. |
| `jobPollInterval` | 30 s | The slowest a due job waits when its notification was lost. |
| `commandOutcomeRetention` | 7 days | How long command outcomes are kept for idempotency (D-013); see [commands](../2-core/commands-and-idempotency.md). |
| `failedJobRetention` | 30 days | How long a job out of attempts stays in `dw_job` for the operator, from when it failed; `dw.cleanup` removes it after. |
| `alertsPerSignature` | 5 | Alerts of one failure signature per `alertWindow` ([alerts](alerts.md)). |
| `alertWindow` | 1 h | The window of that ceiling. |
| `outboundTimeout` | 30 s | How long one outbound request (`ctx.http`) may take, connecting to last byte, unless the call names its own ([handlers](handlers-and-context.md#outbound-http)). |
| `outboundMaxResponseBytes` | 10 MiB | The largest response body one outbound request reads, unless the call names its own; past it the exchange fails with `DwOutboundException`. |

## Configuration comes from the environment

There is no configuration file. The server is configured by its environment, read **once, at start,
in one file**: `lib/src/core/environment.dart` declares the project's typed `AppEnvironment`, and
`bin/server.dart` reads it through `DwLocalEnvironment.overlay` (which adds `deploy/config.yaml >
local` and `deploy/secrets.yaml > local` on a developer's machine):

```dart
// lib/src/core/environment.dart
final class AppEnvironment {
  const AppEnvironment({required this.server, required this.sms});

  static AppEnvironment read(Map<String, String> variables) =>
      DwEnvironmentReader.read(variables, (read) => AppEnvironment(
        server: DwServerEnvironment.read(
          read,
          defaultPublicBucket: AppFiles.defaultPublicBucket,
          defaultPrivateBucket: AppFiles.defaultPrivateBucket,
        ),
        sms: AppSmsEnvironment(
          login: read.required('SMS_LOGIN'),
          password: read.required('SMS_PASSWORD'),
          retries: read.integer('SMS_RETRIES', fallback: 3),
        ),
      ));

  final DwServerEnvironment server;
  final AppSmsEnvironment sms;
}

// bin/server.dart
final env = AppEnvironment.read(DwLocalEnvironment.overlay(Platform.environment));
```

`DwEnvironmentReader` has `required`, `optional`, `integer` (with a `fallback`), `flag` (`true` /
`false`), `list` (comma-separated) and `report` for a problem no single variable shows (two that go
together). Each answers at once and records what is wrong; `read` throws `DwEnvironmentException`
with **every** missing and malformed variable once the object is built, so a deploy that forgot three
hears about all three in one start. A problem never repeats a text value; a number or flag read with
`secret: true` is not repeated either. `Platform.environment` anywhere else in `lib/` is an error of
`dart run dartway_cli:dartway check` (`forbiddenEnvironmentRead`).

`DwServerEnvironment.read` is the framework's own variables, typed:

| Variable | Becomes |
|---|---|
| `DW_DATABASE_*` | `database`, as `DwDatabaseConfig.fromEnvironment` reads it (below) |
| `DW_STORAGE_*` | `storage`, as `DwFileStorageConfig.fromEnvironment` reads it, the buckets defaulting to the names given and the public base URL to the public bucket on the endpoint (path style); `null` without `DW_STORAGE_ENDPOINT` — the server runs without uploads |
| `DW_STORAGE_PROVISION=true` | `provisionStorage`: `DwFileStorageSetup.provision` before starting — for a storage the project owns; a problem without an endpoint |
| `PORT` | `port`, 8080 by default |
| `DW_ALLOWED_ORIGINS` | `allowedOrigins`, comma-separated, for `DwServerSettings.allowedOrigins` |
| `DW_ADMIN_IDENTIFIER` | `adminIdentifier`, for `DwFirstAdministrator(identifier:)` (below) |
| `DW_MIGRATE_ONLY=true` | `migrateOnly`, for `DwAppServer.start(migrateOnly:)`: apply the migrations and exit |

Every one of them comes through the local overlay and into the one error list — nothing of the
framework's reads `Platform.environment` behind the project's back. The two groups above that have
parsers of their own are:

- `DwDatabaseConfig.fromEnvironment(env)` reads `DW_DATABASE_HOST`, `_PORT` (5432), `_NAME`,
  `_USER`, `_PASSWORD`, `_SSL` (`true` unless `false`), `_CA_FILE` (unset) and `_MAX_CONNECTIONS`
  (10). Every missing or malformed key is reported in one `ArgumentError`, so a misconfigured deploy
  fails with the whole list instead of one line per restart. `_CA_FILE`, when set, verifies the
  server's certificate against that CA (`verify-full` instead of `require`) and is refused together
  with `_SSL=false` — a CA has nothing to verify without TLS. A local Postgres without TLS needs
  `DW_DATABASE_SSL=false`. A server without SSL is refused at once when SSL is required — the pool asks it once before the first
  connection — with an error naming the setting.
- `DwFileStorageConfig.fromEnvironment(env)` reads `DW_STORAGE_*` ([uploads](uploads.md#configuration)).

A value the project wants configurable is one more field of a sub-config in `AppEnvironment`,
handed to what uses it by `bin/server.dart` through the project's server factory.

## One process, one isolate

A server runs in a single isolate (D-014). The live hub (who is subscribed to what), the session
token cache and the alert ceiling live in that isolate's memory.

What this means in practice: **run one server process per database.** Jobs would coordinate across
processes — workers claim rows with `SKIP LOCKED` — and a revocation made by one process reaches
another within `tokenCacheTtl`, but live updates do not cross processes: a command handled by one
process publishes only to sockets connected to that process. Scaling out is processes plus
`LISTEN`/`NOTIFY` for updates, which is not built yet.

## Same origin, and `allowedOrigins`

The app reaches the server on the same origin it is served from: the deploy proxies `/dw/` and
`/health` to the server, and `dart run dartway_cli:dartway dev` does the same locally
([deploy](../5-tooling/deploy.md), [CLI](../5-tooling/cli.md)). So the server answers no CORS
preflight, ever. A browser cannot send a cross-origin `application/json` call without one, which
closes that door for calls without a list to maintain.

The live socket is a WebSocket upgrade, which browsers do not preflight. The server therefore
checks `Origin` itself: an upgrade whose origin is the host it was sent to is allowed; an upgrade
without `Origin` (a native app) is allowed; any other origin must be listed in `allowedOrigins`,
as a full origin — scheme, host and port (`https://app.example.com`, `http://localhost:5000`). A
bare host is refused at startup: it would silently allow every port and scheme of it.

## Work after start: `server.accounts` and `server.db`

A running server exposes `server.db` (the pool's `DwDatabaseHandle`), `server.accounts` (a
`DwAccountService` whose revocations end sessions on this server at once), `server.boundPort` and
`server.logger`. All but the logger throw `StateError` before `start()`.

The skeleton used to use them for its first administrator; that is now a **startup step**, below.

A script with no server running builds `DwAccountService(db, auth)` over a bare database instead —
see [auth and identity](auth-identity.md#dwaccountservice). A script that has a server (the seed
starts one on port `0`) uses `ctx.accounts` and needs no such thing.

## Startup steps and seeds

**`DwAppServer(startup: [...])` and `DwServerFeature(startup: [...])` are work done at every start,
after the migrations and before the port opens** — the server's steps first, then each feature's, in
the order the features are listed. The lifecycle is the concept: a step is idempotent by
construction — it states what must be true and makes it so — and nothing has been served when it
runs, so a step that throws stops the start with the previous version still serving.

Each runs in a background context, in one transaction, so `ctx.db`, `ctx.accounts`, `ctx.publish`
and `ctx.jobs` are the ones a handler has. `DwStartupStep.problems(auth)` is judged with the
server's own, before the database is even opened: a value read from the environment is checked
there.

**Nothing but logging comes after `server.start()` in `bin/server.dart`.** By then the port is open:
work there races the first calls, and when it fails the server is up with half of it. `dartway
check` fails an `await`, or a reach into `server.db`, `server.accounts` or `runInContext`, after
`start()` (`workAfterServerStart`).

What goes where, and this is the whole of it:

| What | Where |
|---|---|
| the schema, once per database | a **migration** ([migrations](migrations.md)) |
| existing rows carried across a schema change | `m.backfill` in that migration |
| rows the code declares — a catalogue, a questionnaire, the reasons a project refuses something | a **seed**: `DwSeedRows` |
| one value per app, with a default for every field | a **settings object**: `ctx.settings` ([database](database.md#settings)) |
| anything else that must be true before the first call | a **startup step** |
| development data, whenever a developer feels like it, never in production | a **script** (`bin/seed_dev.dart`) |

Rows the operators own once they exist are none of these: a seed would write the declaration back
over their edit at the next start. Their starting values are defaults in the code, and the rows are
made in the admin panel.

### `DwSeedRows`

Rows the code declares, written into their table by a key at every start. The example's staff chat
declares its channels (`example/dartway_example_server/lib/src/chat/`):

```dart
// chat_rows.dart
const staffChannels = [
  NewChatChannelRow(slug: 'front-desk', title: 'Front desk'),
  NewChatChannelRow(slug: 'coaches', title: 'Coaches'),
  NewChatChannelRow(slug: 'maintenance', title: 'Maintenance'),
];

// chat_feature.dart
final chatFeature = DwServerFeature(
  'chat',
  handlers: chatHandlers,
  startup: [
    DwSeedRows(
      'staff channels',
      table: ChatChannelRow.tableDef,
      key: (t) => [t.slug],
      rows: staffChannels,
    ),
  ],
);
```

At every start, in one statement (`DwTableRepository.upsertAll`):

- a declared row that is missing is inserted;
- a stored row with the same key and other values is written over, keeping its id — an edit of the
  declaration reaches every environment on its next start;
- a stored row that already holds the declared values is not touched, so a start with nothing new
  writes nothing and logs nothing;
- a stored row the declaration does not name is left alone. Retiring one is a column of its own
  (`isPublished: false`), declared like any other value, since other rows may point at it.

**A seed owns its rows: only rows nobody edits outside the code are a seed** — the next start
writes the declaration back over an edit made in an admin panel.

The key names unique, `NOT NULL` columns — a natural key, never the `id`, which differs between
databases; one `@DwUniqueColumn` or exactly a unique index. A nullable key column (a conflict never
matches a null, so every start would insert the row again), a key that is not unique and two declared
rows with one key are refused before the database is opened. The rows are constants: a value
computed at start (`DateTime.now()`) rewrites the row at every start. During a rolling deploy the
old and the new server each converge the table at their own start — the last one to start wins, and
a row the new version dropped stays as the old one wrote it. A seed whose rows point at another
seed's is listed after it.

### `DwFirstAdministrator`

The case every project has. The admin role is granted by an admin, which leaves the first one
nowhere to come from; `DW_ADMIN_IDENTIFIER` names it per environment, and there is no default
because whoever receives the codes sent to that identifier *is* the administrator. It is read into
`DwServerEnvironment.adminIdentifier`, and `bin/server.dart` hands it to the server factory, which
hands it to the skeleton's `account` feature — the step is the account's; what it grants is the
profile's, so `grant` is a change function of the profile feature:

```dart
DwServerFeature accountFeature({required String? adminIdentifier}) =>
    DwServerFeature(
      'account',
      startup: [
        DwFirstAdministrator(
          grant: ProfileChanges.grantAdmin,
          identifier: adminIdentifier,
        ),
      ],
    );

// ProfileChanges — the project's half: the framework goes as far as the account.
static Future<void> grantAdmin(DwCallContext ctx, int accountId) async {
  final profile = (await ctx.db.userProfiles.findFirst(
    where: (t) => t.accountId.equals(accountId),
  ))!;
  if (profile.role == UserRole.admin) return;
  await ctx.db.userProfiles.update(
    profile.copyWith(
      role: UserRole.admin,
      firstName: profile.firstName.isEmpty ? 'Admin' : null,
    ),
  );
}
```

The framework ensures the account the way a sign-in does (`onAccountCreated` runs with a tool
origin, so the project's profile appears with it) and hands it to `grant`. Unset, the variable is a
warning at every start and nothing else. Set to something the project's `normalize` refuses, it is
a server that does not start. It runs at **every** start, so an identifier demoted in the panel is
an administrator again next time — which is the only way back into a project that locked itself
out; the way to stop it is to take the identifier out of the environment.

### `server.runInContext`

Code outside any call sometimes needs what a handler has — `ctx.publish`, `ctx.jobs`, `ctx.files`,
`ctx.accounts`: a script that publishes, a test that calls a domain service directly rather than
through a command.

```dart
final plan = await server.runInContext((ctx) => PlanService.rebuild(ctx, accountId));
```

It runs the way a job does: a background context with no caller, in one transaction; publications
and revocations are delivered once it commits, and nothing of it is if `work` throws. The value
`work` returns is the answer. A test server exposes the same as `DwTestServer.runInContext`.

### `server.callAs`

A door of the server's own that acts for a signed-in person — an MCP endpoint, an importer holding
a person's key — calls the contract, not the database, so that the rules a call has are the rules
it keeps:

```dart
final result = await server.callAs(
  const ListMyInvoices(),
  token: bearerToken,
);
final created = await server.callAs(
  PayInvoice(invoiceId: id),
  token: bearerToken,
  idempotencyKey: toolCallId, // a retried tool call answers its first outcome
);
```

Everything an HTTP call goes through after decoding runs: the session of `token`, sign-in, validation,
the access rule, the handler, a command's idempotency and transaction, and the updates it publishes,
which reach live connections as after any call. The answer is the typed `DwCallResult<R>` a client
gets. `page` positions a page or window request. There is no request over the network, so no
protocol or contract header to keep in step: a door that posted to its own port over loopback carried
them by hand, and broke the day the protocol version moved.

## Related

- [Handlers and the call context](handlers-and-context.md) — what runs for each call.
- [Wire and versions](../2-core/wire-and-versions.md) — the headers and statuses of `/dw/`.
- [Testing](../5-tooling/testing.md) — `DwTestServer` starts this server on a free port.
