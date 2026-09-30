---
name: dartway-testing
description: >-
  How a DartWay project tests itself, by where the behaviour lives: contract tests in __SHARED_PKG__
  (round trip, validate(), onUpdate, channels); server acceptance tests on a real Postgres and storage
  (`dart run dartway_cli:dartway test`, the skeleton's AppHarness, DwTestServer, real clients, raw
  calls, DwTestClock, server.http); widget tests on the in-memory DwFakeServer through the skeleton's
  TestApp; where test files go; the timing traps; what not to test; proving a test by breaking the
  code. Use when writing or reviewing tests, or when a test fails with "Dw is not initialized",
  "Another dw core is alive", "found 0 widgets" or a pending Timer.
---

# DartWay — how a project tests itself

**What** deserves a test is the behaviour's complexity — rules, edge cases, rollback paths, and every
non-trivial bugfix, starting red — never the fact that a line changed; not cosmetics. Assert the
outcome, not that code ran. **Where** is decided by where the behaviour lives:

| The behaviour | Its test | Runs with |
|---|---|---|
| what a DTO carries, which field a command refuses, what an update does to a request, a request's channels | **contract test**, pure Dart | `dart test` in `__SHARED_PKG__` |
| who may call what, what a command writes and publishes, who may subscribe, a job's effect, where a file lands | **acceptance test**: the real server, a real database and storage | `dart run dartway_cli:dartway test` |
| what a screen shows, what the user's action sends, how a refusal or an update looks | **widget test** on the in-memory server | `flutter test` |
| a calculation, a parse, a state machine without I/O | **unit test** | the package's runner |

A widget test cannot prove a member is refused — the hidden button is not the rule; an acceptance test
cannot prove the button sends the right command.

**Where the file goes** (`testLayout`, `testHarnessBypassed`): at the mirror of what it tests —
`lib/src/core/files.dart` → `test/src/core/files_test.dart`; a server feature through its calls →
`test/src/invoices/invoices_acceptance_test.dart` (a scenario: `invoices_<scenario>_acceptance_test.dart`;
`check --fix` moves a root-level one); the contract → `test/<shared package>_test.dart`. Helpers and the
harness live in `test/support/`, imported relatively; a test builds no server, fake server or
`ProviderScope` of its own — a configuration it needs is a method on the harness.

## 1. The contract

The skeleton's `__SHARED_PKG__/test/dartway_starter_shared_test.dart` is the file to extend: one list
round-trips a value of every DTO through the project's protocol
(`appProtocol.decodeNamed(o.dwTypeName, o.toJson())` equals `o`), with and without optional fields;
`validate()` asserted as `code@field`; `onUpdate` of each request with `matches`, `sort` or a custom
`onUpdate` (`DwUpdateAction.upsert` / `remove`); a caller channel resolved
(`channels.single.resolvedFor(42).wireName`).

## 2. The server — acceptance tests

`dart run dartway_cli:dartway test` (from `__FLUTTER_PKG__`; `-- --name x` passes arguments, `--keep`
keeps the database up, `--no-storage`) starts a Postgres and a storage on ports Docker picks, runs
`dart test` in `__SERVER_PKG__`, and removes both. Never a test database in compose or a fixed port.

**One harness, extended, never replaced**: `AppHarness` in `__SERVER_PKG__/test/support/app_harness.dart`
— `start`, `stop`, `client`, `signUp`, `admin`, `refusedWith` — builds the server with the **same
factory `bin/server.dart` uses**, on a `DwTestDatabase` per file, with captured codes. A new file is
`setUpAll` → `AppHarness.start()`, `tearDownAll` → `stop()`; domain helpers (a staff member) are added to
it or an extension on it.

- **Time is the harness's `DwTestClock`**: every `ctx.now` answers it and a job runs when the clock
  passes its `runAt` — move it (`clock.advance`, `moveTo`), never wait or rewrite `dw_job`. The caller's
  UTC offset is pinned to zero (`DwTestServer.utcOffset`, `connectClient(utcOffset:)`).
- Tests in one file share a database: each creates its own members and asserts on what it created.
- **Real clients for behaviour** — `connectClient()`, `watch(…)`, `command(…)`, a second member for "the
  other device" and "someone else is refused"; wait with `dwWaitUntil`, never a fixed delay.
  **Raw calls for the wire** — `server.caller(token:)` (status, headers), `server.openLive()` (subscribe,
  `expectSilence`). **`server.db`** for what is stored, not for what a client could observe.
- `server.wakeJobs()` runs due jobs now; `server.runInContext((ctx) async …)` calls a service with a real
  context; `DwTestStorage.create(prefix:)` provisions buckets (`dartway-uploads`).
- **Other services**: `server.http` answers `ctx.http` from rules —
  `server.http.when((r) => r.url.host == 'sms.example.com', (r) => DwOutboundResponse(200, json: {…}))`;
  the last rule wins, a request no rule answers fails the call, `server.http.requests` records what left.
  Without a server, `DwFakeOutboundHttp()..when(…)` and `http.client()`.
- Write one when the rule is the point — a boundary, a refusal with its code, a filter that must not
  leak, a publication and its audience, an idempotent retry, a job's effect. Not for a read that maps a
  table with no rule.

## 3. Screens — widget tests on the in-memory server

A feature reads and writes through the ambient `dw`; nothing is added to make it spyable. The seam is
the server, replaced by `DwFakeServer(protocol: appProtocol)` (`package:dartway_client/testing.dart`):
`onRequest<ListMyInvoices>((request, call) => DwCallOk(<CustomerInvoice>[…]))`, `onCommand<…>`,
`call.publish(…)`; assert with `callsOf<PayInvoice>()`, `requestsOf<…>()`; push from outside with
`server.publish(channel, [object])`; page with `dwFakeTablePage`, `dwFakeOffsetPage`, `dwFakeWindow`;
files with `DwFakeStorage`. **Every test ends asserting `server.errors` is empty.**

**Start from the skeleton's `FakeApp` and `TestApp`** (`__FLUTTER_PKG__/test/support/app_test_app.dart`):
they build the core through the app's own factory in `lib/core/dw_core.dart` with the fake's transports
and a `DwMemoryTokenStore` (the signed-in user is that session, not a provider override), dispose it,
answer the reads every screen makes, pump at phone size, tap, settle, and check the fake met no
surprise. A widget test lives at `test/<zone>/<feature>/<entry>_test.dart`. Sample:
`__FLUTTER_PKG__/test/admin/users/admin_users_page_test.dart`.

- `Dw is not initialized` / `found 0 widgets` — no core: a feature reaches `dw` while building.
  `Another dw core is alive` — a previous test did not dispose its core (`addTearDown(core.dispose)`).
- A `MaterialApp` a test builds mounts the delegates, the supported locales **and an explicit `locale:`**;
  the app's root takes it from `tester.platformDispatcher.localeTestValue`.
- **Never `await` a core call directly** (`core.signOut()`): fake time moves only with pumped frames —
  `await app.run(tester, …)`.
- **No `pumpAndSettle` over a spinner**; settle as the harness does. A success notification holds a
  timer — `waitOutNotifications` before unmounting. A failed read is retried: assert what was asked,
  never how many times. Settle after `enterText` before asserting a button enabled.

Assert what the screen shows from the server's answer, that the action **sent the right DTO**, that a
refusal renders as its text and nothing else changed, that a publication changed the screen without a
re-read.

## 4. Not tested here

The framework (calls, updates, reconnects, upload retries — tested in the DartWay repository);
cosmetics; generated code (the round trip and `generate --check` cover it); a UI rule mirroring a server
rule as proof of access. No coverage thresholds, and none reported.

## 5. A test is proved by breaking the code

Before committing a test, **break the one thing it is about** — a comparison, a flag, one line — and
watch it go red; name the change in the review ("removed `isDeleted` from the mapper — red"). Three
shapes pass while testing nothing: the subject is inert where it stands (never mounted, never reached);
**the test compares a copy with the copy** (an expectation built by the code under test, a hand list
beside the one the code builds) — the mutation does not find this one, reading each side's source does;
and a mutation that changed two things, going red for the wrong reason.
