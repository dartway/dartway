# The application server: what does `start()` do, and how is it configured?

A DartWay server is one `DwAppServer` object in the project's server package and one process
running it. It is built from declarations — the protocol, the handlers, the rules — and refuses to
start when they disagree, so an inconsistency is found at deploy time instead of by the first user
who presses the button.

## The constructor

```dart
DwAppServer buildExampleServer({
  required DwDatabaseConfig database,
  DwFileStorageConfig? storage,
  int port = 8080,
  DwAuthConfig? auth,
  DwServerSettings settings = const DwServerSettings(),
}) => DwAppServer(
  protocol: dartwayExampleProtocol,
  schema: dartwayExampleSchema,
  migrations: appMigrations,
  database: database,
  auth: auth ?? exampleAuth,
  handlers: [
    ...profileHandlers,
    ...scheduleHandlers,
    ...bookingHandlers,
    ...contentHandlers,
    ...chatHandlers,
    ...adminHandlers,
  ],
  channels: exampleChannels,
  files: storage == null ? null : exampleFileStorage(storage),
  port: port,
  settings: settings,
);
```

That is `example/dartway_example_server/lib/dartway_example_server.dart`. The skeleton has the same
shape in `buildDartwayStarterServer`; `bin/server.dart` builds it from the environment, and tests
build it on a free port against their own database.

| Parameter | Required | What it is |
|---|---|---|
| `protocol` | yes | the `DwWireProtocol` both sides speak |
| `schema` | no | the `DwDatabaseSchema` the row classes declare; checked after migrating |
| `migrations` | yes | the project's migrations (namespace `app`) — [migrations](migrations.md) |
| `database` | yes | a `DwDatabaseConfig` — [database](database.md) |
| `auth` | yes | a `DwAuthConfig` — [auth and identity](auth-identity.md) |
| `handlers` | yes | one `DwCallHandler` per request and command class — [handlers](handlers-and-context.md) |
| `channels` | no | one `DwChannelRule` per channel kind — [channels](../2-core/channels-and-realtime.md) |
| `jobs` | no | `DwJobDefinition` and `DwRecurringJob` — [jobs](jobs.md) |
| `routes` | no | `DwHttpRoute` doors for callers that are not the app — [routes](routes.md) |
| `files` | no | a `DwFileStorage`; without it file calls fail — [uploads](uploads.md) |
| `port` | no | `8080`; `0` binds a free port (`server.boundPort` tells which) |
| `address` | no | `InternetAddress.anyIPv4` |
| `alerts` | no | a `DwAlertSink`; the log by default — [alerts](alerts.md) |
| `logger` | no | a `DwServerLogger`; `DwConsoleLogger` by default |
| `settings` | no | `DwServerSettings`, below |

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
| `minAppBuild` | `0` | The oldest app build served. A call whose `Dw-App-Version` build is lower (or absent while this is above 0) is answered `426` `dw.updateRequired`; the live socket closes `incompatible`. Read at start: raising it is a restart, not a release. See [update required](../3-flutter/update-required.md). |
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

## Configuration comes from the environment

There is no configuration file. The framework reads exactly two groups of variables itself, and
only when the project asks it to:

- `DwDatabaseConfig.fromEnvironment(env)` reads `DW_DATABASE_HOST`, `_PORT` (5432), `_NAME`,
  `_USER`, `_PASSWORD`, `_SSL` (`true` unless `false`) and `_MAX_CONNECTIONS` (10). Every missing or
  malformed key is reported in one `ArgumentError`, so a misconfigured deploy fails with the whole
  list instead of one line per restart. A local Postgres without TLS needs
  `DW_DATABASE_SSL=false`.
- `DwFileStorageConfig.fromEnvironment(env)` reads `DW_STORAGE_*` ([uploads](uploads.md#configuration)).

Everything else is the project's `bin/server.dart` reading `Platform.environment` and passing
values in. The skeleton's (`template/dartway_starter_server/bin/server.dart`) reads:

| Variable | Becomes |
|---|---|
| `DW_DATABASE_*` | `DwDatabaseConfig.fromEnvironment` |
| `PORT` | `port`, 8080 by default |
| `DW_STORAGE_*` | the storage configuration; without `DW_STORAGE_ENDPOINT` the server runs without uploads |
| `DW_STORAGE_PROVISION=true` | `DwFileStorageSetup.provision` before starting — for a storage the project owns |
| `DW_MIN_APP_BUILD` | `DwServerSettings.minAppBuild` |
| `DW_ALLOWED_ORIGINS` | `DwServerSettings.allowedOrigins`, comma-separated |
| `APP_BOOTSTRAP_ADMIN` | the first administrator, below |

The example's `bin/server.dart` is the same without the administrator. A value the project wants
configurable is one more line there; the framework does not grow a settings loader for it.

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
`/health` to the server, and `dartway dev` does the same locally
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

The skeleton uses them for its first administrator. The admin role is granted by an admin, which
leaves the first one nowhere to come from; `APP_BOOTSTRAP_ADMIN` names it per environment.
`bin/server.dart` parses the identifier before anything starts (a mistyped admin is a startup
error), starts the server, then calls:

```dart
Future<bool> ensureAdministrator(
  DwAppServer server,
  String rawIdentifier,
) async {
  final (:kind, :identifier) = parseAdminIdentifier(rawIdentifier);
  // Created through the framework like any sign-in, so the account, its
  // identifier and its profile appear together (`onAccountCreated` runs with a
  // tool origin).
  final (:accountId, :created) = await server.accounts.ensure(kind, identifier);
  final profile = (await server.db.userProfiles.findFirst(
    where: (t) => t.accountId.equals(accountId),
  ))!;
  if (profile.role == UserRole.admin) return created;
  await server.db.userProfiles.update(
    profile.copyWith(
      role: UserRole.admin,
      firstName: profile.firstName.isEmpty ? 'Admin' : null,
    ),
  );
  return true;
}
```

That is `template/dartway_starter_server/lib/src/bootstrap.dart`. It runs on every start and acts
only when the identifier is not an admin yet, so an admin demoted in the panel is back on the next
start. There is no default identifier: whoever receives the codes sent to it becomes the admin.

A script with no server running (the seed) builds `DwAccountService(db, auth)` over a bare
database instead — see [auth and identity](auth-identity.md#dwaccountservice).

## Related

- [Handlers and the call context](handlers-and-context.md) — what runs for each call.
- [Wire and versions](../2-core/wire-and-versions.md) — the headers and statuses of `/dw/`.
- [Testing](../5-tooling/testing.md) — `DwTestServer` starts this server on a free port.
