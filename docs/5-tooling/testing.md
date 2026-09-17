# How is a DartWay project tested, and how is the framework?

Three tiers in a project, each where the thing it proves actually lives, and none of them a copy of
another:

| Tier | Runs with | Proves | Needs |
|---|---|---|---|
| Contract | `dart test` in `<project>_shared` | every data object, request and command survives the wire and comes back equal | nothing |
| Server acceptance | `dartway test` from the project root | handlers, access rules, publishing, migrations — on a real Postgres and a real S3 storage, through real clients | Docker |
| Widgets | `flutter test` in `<project>_flutter` | a screen reads, commands, refuses and follows live updates as the user sees it | nothing: an in-memory server |

The skeleton ships a worked example of each, and the reference application in `example/` another:
`template/dartway_starter_shared/test/contract_test.dart`, `template/dartway_starter_server/test/`
with its harness `test/support/app_harness.dart`, and `template/dartway_starter_flutter/test/` with
`test/support/app_test_app.dart` (`example/dartway_example_flutter/test/support/example_test_app.dart`
in the example).

**Why the split is not negotiable.** A rule the server enforces — who may read a row, what a command
refuses, which channel hears a change — runs inside a call, against the database. No widget test can
reach it: a widget test proving that the admin-only button is hidden proves that the button is
hidden. And a screen's behaviour is not reachable from the server side: the server does not know
whether a refusal became a readable message or an endless spinner. Each tier tests the half only it
can see.

## The contract: `dart test` in the shared package

The shared package is pure Dart, so its suite runs anywhere in milliseconds. What it has to hold is
the wire: a data object with a field its generated codec does not carry compiles, starts and travels
without that field. The skeleton's contract test builds an instance of every data object, request
and command, encodes it, decodes it by its wire name through the project's protocol and expects it
back equal. It also holds what the shared package decides for both sides, because both sides run
it: what a command's `validate()` refuses, which channel a "my" request resolves to for a signed-in
account, and how a request answers an update — `upsert` for a row inside its filter, `remove` for
one that left it.

## Server acceptance: `dartway test`

```bash
dartway test                        # from the project root
dartway test -- --name 'sign-in'    # arguments after -- go to `dart test`
dartway test --keep                 # leave the containers up after the run
dartway test --no-storage           # a server without uploads
```

The command starts `postgres:17-alpine` and `quay.io/minio/minio:RELEASE.2025-09-07T16-13-09Z` —
the images a deployment runs — each published on `127.0.0.1` at a port Docker picks and with its data in `tmpfs`,
waits until Postgres answers `pg_isready` and MinIO its readiness endpoint (60 seconds at most), runs
`dart test` in the server package, and removes both containers afterwards, on Ctrl+C too. `--image`
and `--storage-image` name other images. The suite receives the coordinates in its environment:

- `DW_DATABASE_HOST`, `_PORT`, `_NAME` (the maintenance database `postgres`), `_USER` (its
  superuser, since a suite creates databases), `_PASSWORD` (generated per run), `_SSL=false`;
- `DW_STORAGE_ENDPOINT`, `_ACCESS_KEY`, `_SECRET_KEY` — no bucket names: a suite makes its own.

**Why a database per run, and not a compose service.** A test database declared as a service is
shared, named, long-lived and on a fixed port, and every one of those is wrong for it. On a fixed
port the second project on a machine does not get the port and does not fail either: Docker starts
the container unpublished, and the suite connects to the neighbour's database — green, having
verified nothing where the schemas are close enough. And a long-lived database keeps rows from the
last run, which arrive as arithmetic (`Expected: <2>, Actual: <3>`) several hypotheses away from
their cause. A container that exists for one run has no port to lose and nothing to keep.

**Why the environment, and not a configuration per file.** The environment is a property of the
process: a test file cannot forget it. A per-file override can be forgotten, and in a real project
one was honoured by 25 files out of 29.

### What a suite has to start a server

`package:dartway_core_server/testing.dart` is the whole kit, and it re-exports the client so an
end-to-end test imports nothing else of the framework:

| Name | What it is for |
|---|---|
| `DwTestDatabase.create(prefix:)` | A database of its own for one test file, on the server `DW_DATABASE_*` names; `config` goes to `DwAppServer(database:)`, `drop()` removes it |
| `DwTestStorage.create(prefix:)` | A public and a private bucket of its own on the storage `DW_STORAGE_*` names, provisioned as a project's are; `config` goes to `DwFileStorage`, `drop()` removes both with their objects |
| `DwTestServer.start(server)` | Starts a `DwAppServer` on a free loopback port without signal handling — migrations applied, handlers validated, exactly as `bin/server.dart` starts it. `db` is its database, `wakeJobs()` runs the job executor now, `stop()` stops every client it handed out and then the server |
| `caller(token:)` → `DwTestCaller` | Raw calls as a client sends them: the path, the headers and the body, a fresh `Dw-Idempotency-Key` per command. `call(dto)` answers a `DwTestAnswer` — `status`, `headers`, `response`, `value(call)`, `updates`, `refusal`; `raw(...)` sends anything. For tests of the wire itself |
| `openLive()` → `DwTestLiveSocket` | A raw live socket that has read its `hello`: `authenticate`, `subscribe`, `waitFor`, `expect<T>`, `expectSilence` |
| `connectClient()` | A started, real `DwAppClient` of this server — real HTTP, the real live socket — with `dwTestClientOptions` (millisecond retries, no release delay). Transports passed in wrap the real ones, to lose an answer or watch the frames |

The skeleton wraps them once per test file (`template/dartway_starter_server/test/support/app_harness.dart`):

```dart
static Future<AppHarness> start({DwFileStorageConfig? storage}) async {
  final database = await DwTestDatabase.create(prefix: 'app_test');
  late final AppHarness harness;
  final server = await DwTestServer.start(
    DartwayStarterServer.build(
      database: database.config,
      storage: storage,
      port: 0,
      auth: AppAuth.config(
        // Tests ask one identifier for several codes within a minute.
        resendDelay: Duration.zero,
        deliverCode: (ctx, kind, identifier, code) async =>
            harness.delivered[identifier] = code,
      ),
    ),
  );
  return harness = AppHarness._(database, server);
}
```

The server under test is built by the same function `bin/server.dart` uses, with the sign-in code
captured instead of delivered. Members sign up through real clients, so an acceptance test reads like
the product: one member changes a role, and another member's watched request hears it without a
re-read.

## Widgets: an in-memory server

A widget test boots the app's own core and its own widget, and puts an in-memory server where the
network would be. `package:dartway_client/testing.dart` (a dev dependency of the Flutter package)
provides it:

| Name | What it is for |
|---|---|
| `DwFakeServer(protocol:)` | Speaks the protocol as the real server does — headers and their checks, honest statuses, `426` for an old build, idempotent commands, the response transport filtered by `Dw-Live-Connection` (none without it), sign-in on the socket, subscriptions requiring an account. Its `httpTransport` and `liveConnector` go to the core |
| `onRequest<Q>(handler)`, `onCommand<C>(handler)` | Answer a call type with a `DwCallResult`; a handler reads `call.accountId` and publishes with `call.publish(channel, objects)`, which lands in the response of a signed-in caller that `subscriptionRule` allows (or whose named connection subscribes to the channel) and on other sockets, as on a real server |
| `registerToken`, `revokeToken`, `publish`, `closeChannel`, `dropConnections`, `reachable` | Sessions, someone else's update, revoked access, a lost network |
| `calls`, `callsOf<C>()`, `requestsOf<Q>()`, `executions(key)`, `subscribeCount(channel)` | What the app actually sent |
| `errors` | Handler exceptions, calls nobody answers, messages that do not decode. **A test ends by asserting it is empty**: a fake that swallowed a call nobody expected would let a broken test pass |
| `DwFakeStorage(server)` | The framework's upload calls answered, and a storage in memory behind `transport` that holds a client to the signed length and type |
| `DwStreamRecording(stream)` | Records what a stream emits, for assertions over a sequence of states |
| `dwFakeOffsetPage`, `dwFakeTablePage`, `dwFakeWindow` | A page, a table page or a window of a list, cut the way the server cuts them |

It is not the real server: handlers are closures, there is no database and no access rule beyond what
a test declares. That is the division above — the rules are proven in the acceptance tier, and here
the question is what the screen does with the answers.

The skeleton's harness (`template/dartway_starter_flutter/test/support/app_test_app.dart`) builds the
fake once — `FakeApp` answers the reads every screen makes on its way in — and `TestApp.start` builds
the app's core against it with an in-memory token store, pumps the app at phone size and lets the
traffic settle. A test then reads like a user:

```dart
testWidgets('the app name comes from the server settings, and a name saved '
    'elsewhere arrives live', (tester) async {
  final fake = FakeApp();
  final app = await TestApp.start(tester, fake);
  expect(find.text('You are in DartwayStarter'), findsOneWidget);

  app.server.publish(AppChannels.settings, [
    const AppSetting(id: AppSettingKeys.appName, value: 'Acme'),
  ]);
  await app.settle(tester);
  expect(find.text('You are in Acme'), findsOneWidget);
  expect(app.server.requestsOf<ListAppSettings>(), hasLength(1));

  await app.stop(tester);
});
```

(`template/dartway_starter_flutter/test/app/home_page_test.dart`.) `stop` waits out notifications,
unmounts the app, disposes the core and asserts `server.errors` is empty.

**Settle by short pumps, not `pumpAndSettle`.** A loading indicator animates for as long as it is on
screen, so settling by frames waits out the timeout instead of the traffic.

## Before calling a change done

The order the setup brief (`dartway quickstart`) gives an agent, from the project root:

```bash
dartway generate --check
dartway test
(cd my_app_shared && dart test)
(cd my_app_flutter && flutter test)
dartway check
```

`dartway check` also reports `migrationsDrift` when `DW_DATABASE_*` names a Postgres it may create
throwaway databases on; see [The conventions checker](conventions-checker.md).

## The framework's own tiers

The monorepo tests itself in four tiers, split by what a run needs.

**`tool/checks.sh [analyze|test|services]`** — `analyze` and `test` by default, which need no
Docker; the same command locally and in CI (`.github/workflows/checks.yml`, on every pull request
and push to `master`, one job per mode, all three). It resolves the workspace and every package
outside it, then:

- **analyze**: `dart analyze --no-fatal-warnings` over `packages` and `tool`, and in every package
  that is not a workspace member. Errors fail; warnings do not, because the one standing warning is
  in generated code the generator rewrites;
- **test**: every package with a `test/` directory, with `flutter test` where the pubspec names
  `flutter_test` and `dart test` otherwise — plus `dart run custom_lint` in
  `packages/dartway_lints/example`, whose `test/` files violate the rules on purpose and are that
  package's real suite. A package is left out only by being named in the script, with its reason:
  `example/dartway_example_server` and `template/dartway_starter_server` (project servers, run by
  `dartway test`), the lints example, and the packages of `services`. Anything new with a `test/`
  directory runs — the direction that fails loudly;
- **services**: the suites of `packages/dartway_orm`, `packages/dartway_core_server` and
  `packages/dartway_push_server`, against the Postgres of `DW_DATABASE_*` and the S3-compatible
  storage of `DW_STORAGE_*`. It is not in the default because it needs two containers, and it is
  not optional: CI runs it on every pull request with a Postgres service and a MinIO, on the ports
  the script's header gives with its `docker run` and `export` lines. Asked for without every
  variable set, or with nothing answering on the database's or the storage's port, it stops before
  running anything and names what is missing — it never skips.

**The database suites of `example/` and `template/`** run through `dartway test`, exactly as a
project runs them: `.github/workflows/database.yml` installs the CLI from the commit, resolves the
project and runs `dartway test` from its root, one job per project. It runs on a daily schedule, by
hand, and on a change to the workflow file itself — not on every pull request yet, because these are
the suites that test races, and a race is what goes intermittently red on a busier runner.

**Docker proofs** in `packages/dartway_cli`: the tests tagged `docker` build images and run a rendered
deployment stack in local Docker — `test/deploy_local_stack_test.dart` builds the example's images
and deploys the rendered stack on this machine, `test/deploy_rendered_files_docker_test.dart` has
Docker itself validate the rendered files. `dart_test.yaml` skips the tag by default (minutes, and a
daemon) and gives it a 40-minute timeout:

```bash
cd packages/dartway_cli
dart test -t docker --run-skipped
```

`test/dev_proxy_origin_test.dart` in the same package proves the development proxy against a real
server's origin check; it skips itself unless `DW_DATABASE_*` is set.

**On Node.** The pure-Dart packages that a web app compiles are also run under dart2js:

```bash
cd packages/dartway_core_shared && dart test -p node   # every suite
cd packages/dartway_client && dart test -p node        # every suite but real_transport_test.dart (@TestOn('vm'))
```

`dartway_orm`, `dartway_generator` and `dartway_core_server` use `dart:io` and run on the VM only.
Neither `tool/checks.sh` nor a workflow runs the Node tier; it is run by hand.

**The wire golden test** — `packages/dartway_core_shared/test/wire_golden_test.dart`, part of the
shared package's suite. It records the canonical encodings of calls, responses, update transports,
live messages and generated DTOs together with the `dwProtocolVersion` they were taken at. Changing
an encoding without bumping the protocol version fails it (D-052): an app built against the old
format is then answered `426` and shows "update the app" instead of failing to decode. After a deliberate
bump, refresh the recordings with `DW_UPDATE_GOLDENS=1 dart test test/wire_golden_test.dart`. See
[The wire and versions](../2-core/wire-and-versions.md).
