# How is a DartWay project tested, and how is the framework?

Tests follow risk. A test is mandatory only for access (1), money and counted things (2), data
integrity (3), a bug that happened (4), a contract others rely on (5), or complex pure logic (6).
Tests outside those classes are rare and must pass the gate in
[`dartway-testing` §4](https://github.com/dartway/dartway/blob/master/toolkit/skills/dartway-testing/SKILL.md).
Layout and copy, instruction texts, wiring already proven at a boundary, reads that only map a table,
declarations read back, and version literals or other change-detectors get no test by default.

The shape is a honeycomb: each risk is tested at the boundary that owns it, with no copy at another
tier. The project's test surfaces are:

| Tier | Runs with | Proves | Needs |
|---|---|---|---|
| Contract | `dart test` in `<project>_shared` | every data object, request and command survives the wire and comes back equal | nothing |
| Server acceptance | `dart run dartway_cli:dartway test` in the Flutter package | server rules and stored outcomes — on a real Postgres and a real S3 storage, through real clients; one file per feature, new cases as rows in its table | Docker or explicit test servers |
| Widgets | `flutter test` in `<project>_flutter` | a screen's own logic, only where it has some | nothing: an in-memory server |
| Unit | the package's runner | complex pure logic (class 6), with table-driven cases | nothing |

Goldens are only for a real surface. Mutation testing is never a gate.

The skeleton ships worked contract, acceptance and widget tests; the reference application in
`example/` has more:
`template/dartway_starter_shared/test/dartway_starter_shared_test.dart`,
`template/dartway_starter_server/test/` with its harness `test/support/app_harness.dart`, and
`template/dartway_starter_flutter/test/` with `test/support/app_test_app.dart`. The example keeps both
harnesses at the same paths, under the same names, extended with what the club needs — one harness
per side, extended and never replaced.

**A test sits at the path of what it tests, in every package**: `lib/admin/users/admin_users_page.dart`
is tested in `test/admin/users/admin_users_page_test.dart`, `lib/src/core/files.dart` in
`test/src/core/files_test.dart`. A test of a whole folder — a server feature through its calls — is
named after the folder at its mirror: `lib/src/chat/` → `test/src/chat/chat_acceptance_test.dart`;
extend that feature's table for a new case.
Helpers live in `test/support/` and are imported relatively, and a test builds no server and no
`ProviderScope` of its own. `dart run dartway_cli:dartway check` holds all three (`testLayout`,
`testHarnessBypassed`).

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
cd <project>_flutter
dart run dartway_cli:dartway test                        # finds the project from here
dart run dartway_cli:dartway test -- --name 'sign-in'    # arguments after -- go to `dart test`
dart run dartway_cli:dartway test --keep                 # leave the containers up after the run
dart run dartway_cli:dartway test --no-storage           # a server without uploads
```

By default the command starts `postgres:17-alpine` and `rustfs/rustfs:1.0.0` —
the images a deployment runs — pulled first when absent, with up to three attempts, so a project's CI
needs no pre-pull step — each published on `127.0.0.1` at a port Docker picks and with its data in `tmpfs`,
waits until Postgres answers `pg_isready` and the storage its health endpoint (60 seconds at most), runs
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

### Servers supplied by a cloud environment

No Docker is needed when the environment already runs a Postgres and, for uploads, an
S3-compatible server. Supply them explicitly:

```bash
dart run dartway_cli:dartway test \
  --database-url postgres://test_user:test_password@127.0.0.1:5432/postgres \
  --storage-url http://test_key:test_secret@127.0.0.1:9000
```

`--database-url` names the maintenance database on the test server; the role needs `CREATEDB`.
The password is required and the port is optional (it defaults to 5432). `--storage-url` accepts HTTP or HTTPS with access and secret keys,
and uses path-style S3 in `us-east-1`. URL-encode reserved characters in credentials.
Both flags select servers independently: a supplied URL prevents that service's container from
starting. With `--database-url` alone, storage is disabled and the startup line says so;
add `--storage-url` for projects whose tests upload files. `--no-storage` still disables storage.
`--keep` is limited to container runs.

Both hosts must resolve only to loopback addresses. A dedicated remote test server requires
`--allow-remote-test-server`; never supply a stage or production server. Inherited `DW_DATABASE_*`
and `DW_STORAGE_*` variables do not select servers or affect the suite: without flags, containers
remain the default. This prevents a shell or stage `.env` from silently redirecting tests.

The loopback guard checks the current DNS answers; it does not pin later suite connections to those
answers. Prefer literal loopback addresses to avoid a hostname changing between validation and use.
Postgres URL mode disables TLS, including with `--allow-remote-test-server`; remote credentials
travel unencrypted. Use a local tunnel or an isolated, trusted test network. `https` storage URLs
use normal TLS certificate verification.

Every CLI run, including a container run, supplies a fresh `DW_TEST_RUN_ID` (16 lower-case letters
or digits). The test helpers use
`dw_test_<run>_<random>` databases and `dw-test-<run>-<role>-<random>` buckets, overriding their
per-file prefixes while the run id is set. Each file remains isolated. On success, failure and
SIGINT, the CLI stops the suite and sweeps only resources named for that run on the explicit
servers, including bucket objects. Concurrent runs remain untouched. Plain `dart test` without
`DW_TEST_RUN_ID` keeps the existing names and per-file teardown. SIGKILL or loss of the executor
cannot run cleanup; the environment must discard its servers or remove that exact run's resources.
A second Ctrl-C while the cleanup worker's VM is starting or compiling can also prevent cleanup.
Once its `main` begins, the worker ignores SIGINT until the sweep finishes.

A minimal cloud image starts Postgres, creates a dedicated role and provides a maintenance database:

```sql
CREATE ROLE test_user LOGIN PASSWORD 'test_password' CREATEDB;
```

Listen on loopback and permit that role to connect to the maintenance database and its new databases.
For projects with uploads, also start an S3-compatible server on loopback, with dedicated keys
allowed to list, create, configure and delete buckets and their objects. Pass its URL with
`--storage-url`. Provisioning and starting these servers belongs to the environment.

### What a suite has to start a server

`package:dartway_core_server/testing.dart` is the whole kit, and it re-exports the client so an
end-to-end test imports nothing else of the framework:

| Name | What it is for |
|---|---|
| `DwTestDatabase.create(prefix:)` | A database of its own for one test file, on the server `DW_DATABASE_*` names; `config` goes to `DwAppServer(database:)`, `drop()` removes it |
| `DwTestStorage.create(prefix:)` | A public and a private bucket of its own on the storage `DW_STORAGE_*` names, provisioned as a project's are; `config` goes to `DwFileStorage`, `drop()` removes both with their objects |
| `DwTestServer.start(server)` | Starts a `DwAppServer` on a free loopback port without signal handling — migrations applied, handlers validated, exactly as `bin/server.dart` starts it. `db` is its database, `wakeJobs()` runs the job executor now, `stop()` stops every client it handed out and then the server |
| `DwTestClock(at)` | The server's clock for `DwAppServer(clock:)`: it stands at `at` until the test calls `advance(by)` or `moveTo(at)`, and each move wakes the job executor — what `ctx.now` answers and when a job is due ([jobs](../4-server/jobs.md#time-is-the-servers-clock)). A retry, a push retry or a recurring job waits until it is moved past; database-stamped times keep real time |
| `utcOffset` | The UTC offset every `caller()` and `connectClient()` of this server reports as the device's, `Duration.zero` unless set — so `ctx.callerUtcOffset` never depends on the machine's zone. `connectClient(utcOffset:)` names another for one client; `null` makes a raw caller send none |
| `caller(token:)` → `DwTestCaller` | Raw calls as a client sends them: the path, the headers and the body, a fresh `Dw-Idempotency-Key` per command. `call(dto)` answers a `DwTestAnswer` — `status`, `headers`, `response`, `value(call)`, `updates`, `refusal`; `raw(...)` sends anything. For tests of the wire itself |
| `openLive()` → `DwTestLiveSocket` | A raw live socket that has read its `hello`: `authenticate`, `subscribe`, `waitFor`, `expect<T>`, `expectSilence` |
| `connectClient()` | A started, real `DwAppClient` of this server — real HTTP, the real live socket — with `dwTestClientOptions` (millisecond retries, no release delay). Transports passed in wrap the real ones, to lose an answer or watch the frames |
| `DwCountingTransport` | Real HTTP for `connectClient(httpTransport:)`, counting posts per wire name (`posts('ListMyInvoices')`) and keeping the last answer to each: how a test proves an update arrived live and not by a re-read |
| `DwRecordingConnector` | The real live socket for `connectClient(liveConnector:)`, keeping every frame the server sent: `updatesOn`, `refusalsOf`, `closuresOf` a channel |
| `dwWaitUntil(condition)` | Polls until a condition holds, and throws a `TimeoutException` naming `reason` when it does not: for what arrives on the socket or after a job, never a fixed delay |

The skeleton wraps them once per test file (`template/dartway_starter_server/test/support/app_harness.dart`):

```dart
static Future<AppHarness> start({
  DwFileStorageConfig? storage,
  DateTime? now,
}) async {
  final database = await DwTestDatabase.create(prefix: 'app_test');
  final clock = DwTestClock(now ?? DateTime.now());
  late final AppHarness harness;
  final server = await DwTestServer.start(
    DartwayStarterServer.build(
      database: database.config,
      storage: storage,
      port: 0,
      clock: clock,
      auth: AccountAuth.config(
        // Tests ask one identifier for several codes within a minute.
        resendDelay: Duration.zero,
        deliverCode: (ctx, kind, identifier, code) async =>
            harness.delivered[identifier] = code,
      ),
    ),
  );
  return harness = AppHarness._(database, server, clock);
}
```

The server under test is built by the same function `bin/server.dart` uses, with the sign-in code
captured instead of delivered and a clock the test holds (`harness.clock`): a test that stamps or
schedules by time reads `harness.clock.now()` and moves it, rather than waiting. Members sign up through real clients, so an acceptance test reads like
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

  app.server.publish(AppChannels.settings, [const AppSettings(appName: 'Acme')]);
  await app.settle(tester);
  expect(find.text('You are in Acme'), findsOneWidget);
  expect(app.server.requestsOf<GetAppSettings>(), hasLength(1));

  await app.stop(tester);
});
```

(`template/dartway_starter_flutter/test/app/home/home_page_test.dart`.) `stop` waits out notifications,
unmounts the app, disposes the core and asserts both `server.errors` and unaccounted application
error reports are empty. The app factory routes the existing `DwFlutterConfig.onErrorReport` hook
to the harness while preserving its normal reporting behavior. The harness also captures Flutter
errors through `FlutterError.onError` and `PlatformDispatcher.onError` until cleanup finishes, then
restores both hooks even if teardown assertions fail. `DwRefusalException` and
`DwNotAuthenticatedException` reports are normal outcomes and are excluded from incident checks.

An error-path test can assert a captured `DwErrorReport` and account for that exact report with
`app.consumeErrorReport(report)`. The report must have been received by this harness; unrelated
reports still fail `stop`. Most screens keep the cheap fake timing defaults, including an immediate
cache release. A cache or navigation lifecycle test passes `clientOptions: const DwClientOptions()`
to `TestApp.start` to use the production client's one-second release delay.

**Settle by short pumps, not `pumpAndSettle`.** A loading indicator animates for as long as it is on
screen, so settling by frames waits out the timeout instead of the traffic.

## Before calling a change done

`dartway-plan` selects **Risks to guard** from its risk survey and the spec: each item names a class
(1–6) and the expected outcome from the spec. **`No must-test risk: <why>`** is a valid plan; a
bugfix starts with its failing test. The feature scaffold extends the contract list for new DTOs
(class 5) and starts a new acceptance file with an access refusal (class 1). A restricted channel also
needs an outsider receiving nothing. Other tests follow the feature's risk classes; a second client
hearing a publication must earn its place through the gate. It creates no test file for behaviour
outside the six classes.

`dartway-testing` §4 also owns the agent rules for expected values, assertion-change declarations and
reds caused by intended changes. `dartway-finish` checks those rules and the plan's guarded risks.

`dartway-finish` owns the gate list and runs fast gates locally: generation, the migration check
when row classes or migrations changed, all three analyzers, and the conventions checker. It reads
pull-request workflows per suite. Where CI runs a full suite, finish runs changed tests and tests
in the directory mirroring each changed `lib/` file locally. A file with no mirror, including
support, wiring or migrations, requires that package's full suite locally. An uncovered suite runs
locally in full; with no workflow, all three do, reported as "no CI workflow: full suites run locally".
The report names each gate's result, local test files and the workflow carrying each full suite (or
"full suites: run locally, no CI"). After applying edits, the same rule selects the gates and targeted
tests to re-run. `dartway-checkup` is a project audit and always runs every suite in full locally.

The setup brief (`dartway quickstart`) lists the full-suite commands, from the project root:

```bash
(cd <project>_flutter && dart run dartway_cli:dartway generate --check --contract-base <trusted-SHA>)
(cd <project>_flutter && dart run dartway_cli:dartway test)
(cd my_app_shared && dart test)
(cd my_app_flutter && flutter test)
(cd <project>_flutter && dart run dartway_cli:dartway check)
```

`dart run dartway_cli:dartway check` also reports `migrationsDrift` when `DW_DATABASE_*` names a Postgres it may create
throwaway databases on; see [The conventions checker](conventions-checker.md).

CI runs these as `ci`: each is a step of the project's `.github/workflows/ci.yml`, on every pull
request, and every one runs even after an earlier one failed.

## The framework's own tiers

The monorepo tests itself in four tiers, split by what a run needs. The same six risk classes and
test gate apply here: public API and wire contracts are class 5; migration integrity is class 3.

**`tool/checks.sh [analyze|test|services]`** — `analyze` and `test` by default, which need no
Docker. CI (`.github/workflows/checks.yml`, on every pull request and push to `master`, one job per
mode, all three) runs tier 1 in full. Before a PR, run `dart analyze` over touched resolution roots,
`dart run dartway_cli:dartway check` when `template/` or `example/` changed, and the touched packages'
suites (`dart test`
or `flutter test` in each package, or `tool/checks.sh services` for a services package). A completed
run means those suites are green locally and `checks.yml` is green on the PR. The full script
resolves the workspace and every package outside it, then:

- **analyze**: `dart analyze --no-fatal-warnings` over `packages` and `tool`, and in every package
  that is not a workspace member. Errors fail; warnings do not, because the one standing warning is
  in generated code the generator rewrites;
- **test**: every package with a `test/` directory, with `flutter test` where the pubspec names
  `flutter_test` and `dart test` otherwise. `packages/dartway_lints/example` is a fixture: its files
  violate the rules on purpose, and `dartway_lints`' own `test/example_test.dart` runs `dart analyze`
  over it and compares the diagnostics with the ones it marks. A package is left out only by being named in the script, with its reason:
  `example/dartway_example_server` and `template/dartway_starter_server` (project servers, run by
  `dart run dartway_cli:dartway test`), the lints example, and the packages of `services`. Anything new with a `test/`
  directory runs — the direction that fails loudly;
- **services**: the suites of `packages/dartway_analytics_server`,
  `packages/dartway_auth_providers_server`, `packages/dartway_orm`, `packages/dartway_core_server`
  and `packages/dartway_push_server`, plus the CLI external-server acceptance tests, against the
  Postgres of `DW_DATABASE_*` and the S3-compatible storage of `DW_STORAGE_*`. It is not in the default because it needs two containers, and it is
  not optional: CI runs it on every pull request with a Postgres service and a storage, on the ports
  the script's header gives with its `docker run` and `export` lines. Asked for without every
  variable set, or with nothing answering on the database's or the storage's port, it stops before
  running anything and names what is missing — it never skips.

**The database suites of `example/` and `template/`** run through `dart run dartway_cli:dartway test`, exactly as a
project runs them: `.github/workflows/database.yml` installs the CLI from the commit, resolves
`example/` and runs `dart run dartway_cli:dartway test` from its root. The template is proved as
`dartway create` hands it out: a project created from the commit, its packages vendored in and
committed, runs its own `.github/workflows/ci.yml` through `tool/run_project_ci.dart`, which runs
the steps in order and refuses a construct it does not know rather than skip a gate. It runs on a daily schedule, by
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

The generated project contract gate is separate from the core wire golden. CI passes its trusted
base SHA to `generate --check`/`check --contract-base`; regeneration cannot silently approve a breaking
DTO edit. Fixture tests exercise old/new generated codecs and real CLI/Git baselines, including
read-only project byte identity and pin-move adoption, changed-source rejection and blocking unsupported contracts. Tooling metadata alone
does not trigger a core wire bump or runtime interoperability tier.
