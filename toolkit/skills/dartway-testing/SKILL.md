---
name: dartway-testing
description: >-
  How a DartWay project tests itself, by where the behaviour lives: contract tests in __SHARED_PKG__
  (round trip, validate(), onUpdate, channels); server acceptance tests on a real Postgres and storage
  (`dart run dartway_cli:dartway test`, the skeleton's AppHarness, DwTestServer, real clients, raw
  calls, DwTestClock, server.http); widget tests on the in-memory DwFakeServer through the skeleton's
  TestApp; where test files go; the timing traps; the gate a test passes before it is written (what it
  protects, the regression that fails it, why existing coverage misses it, no seam only the test needs)
  and the junk shapes that fail it; a bugfix's test red before the fix; proving a test by breaking the
  code. Use when writing, adding or reviewing tests, or when a test fails with "Dw is not initialized",
  "Another dw core is alive", "found 0 widgets" or a pending Timer.
---

# DartWay — how a project tests itself

A test is written for a behaviour — a rule, an edge case, a rollback path, a bug that happened — never
for the fact that a line changed, and only past the gate (§4). **Where** it goes is decided by where the
behaviour lives:

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
`check --fix` moves a root-level one); the contract → `test/<shared package>_test.dart`. A test walking
through two features is split by feature, what they share moved into the harness. Helpers and the
harness live in `test/support/`, imported relatively; a test builds no server, fake server or
`ProviderScope` of its own — a configuration it needs is a method on the harness.

## 1. The contract

The skeleton's `__SHARED_PKG__/test/<shared package>_test.dart` is the file to extend: one list
round-trips a value of every DTO through the project's protocol
(`<project>Protocol.decodeNamed(o.dwTypeName, o.toJson())` equals `o`), with and without optional fields;
`validate()` asserted as `code@field`; `onUpdate` of each request with `matches`, `sort` or a custom
`onUpdate` (`DwUpdateAction.upsert` / `remove`); a caller channel resolved
(`channels.single.resolvedFor(42).wireName`).

## 2. The server — acceptance tests

`dart run dartway_cli:dartway test` (from `__FLUTTER_PKG__`; `-- --name x` passes arguments, `--keep`
keeps the database up, `--no-storage`) starts a Postgres and a storage on ports Docker picks, runs
`dart test` in `__SERVER_PKG__`, and removes both. Never a test database in compose or a fixed port.

**One harness, extended, never replaced**: `AppHarness` in `__SERVER_PKG__/test/support/app_harness.dart`
— `start`, `stop`, `client`, `signUp`, `admin`, with the matcher `refusedWith` beside it — builds the
server with the **same factory `bin/server.dart` uses**, on a `DwTestDatabase` per file, with captured codes. A new file is
`setUpAll` → `AppHarness.start()`, `tearDownAll` → `stop()`; domain helpers (a staff member) are added to
it or an extension on it.

- **Time is the harness's `DwTestClock`**: every `ctx.now` answers it and a job runs when the clock
  passes its `runAt` — move it (`clock.advance`, `moveTo`), never wait or rewrite `dw_job`. Times a test
  sets up are `harness.clock.now().add(…)`, never `DateTime.now()`. A standing clock also holds back job
  and push retries and recurring jobs until moved; what the database stamps (`created_at`, session and
  code expiry) keeps real time.
- **The caller's UTC offset is pinned to zero**: `server.utcOffset = …` for someone else's day (callers
  made after it use it; `null` — a raw caller sends none, as an old app), `connectClient(utcOffset:)`;
  `DwAppServer.callAs` carries none.
- Tests in one file share a database: each creates its own members and asserts on what it created.
- **Real clients for behaviour** — `connectClient()`, `watch(…)`, `command(…)`, a second member for "the
  other device" and "someone else is refused"; wait with `dwWaitUntil`, never a fixed delay
  (`dwWaitUntil`, `DwCountingTransport`, `DwRecordingConnector` are the framework's, in `testing.dart`).
  **Raw calls for the wire** — `server.caller(token:)` (status, headers; `addTearDown(caller.close)`),
  `server.openLive()` (subscribe, `expectSilence`). **`server.db`** for what is stored, not for what a client could observe.
- `server.wakeJobs()` runs due jobs now; `server.runInContext((ctx) async …)` calls a service that has
  rules of its own with a real context — what a command publishes is still tested through the command; `DwTestStorage.create(prefix:)` provisions buckets (`dartway-uploads`).
- **Other services**: `server.http` answers `ctx.http` from rules —
  `server.http.when((r) => r.url.host == 'sms.example.com', (r) => DwOutboundResponse(200, json: {…}))`;
  the last rule wins, a request no rule answers fails the call, `server.http.requests` records what left,
  `server.http.reset()` between tests sharing a server. A rule throwing
  `DwOutboundException(request, cause: 'refused')` is an unreachable provider; one never completing runs
  into the timeout. Without a server, `DwFakeOutboundHttp()..when(…)` and `http.client()`.
- Write one when the rule is the point — a boundary, a refusal with its code, a filter that must not
  leak, a publication and its audience, an idempotent retry, a job's effect. Not for a read that maps a
  table with no rule.

## 3. Screens — widget tests on the in-memory server

A feature reads and writes through the ambient `dw`, so the seam is the server, replaced by `DwFakeServer(protocol: appProtocol)` (`package:dartway_client/testing.dart`):
`onRequest<ListMyInvoices>((request, call) => DwCallOk(<CustomerInvoice>[…]))` — the exact result
type, not `DwCallOk([])` — `onCommand<…>`,
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
  the app's root takes the product's stated language from `appLocaleProvider` — a test of another
  language overrides that provider.
- **Never `await` a core call directly** (`core.signOut()`): fake time moves only with pumped frames —
  `await app.run(tester, …)`.
- **No `pumpAndSettle` over a spinner**; settle as the harness does. A success notification holds a
  timer — `app.waitOutNotifications(tester)` before unmounting, and before tapping what it covers. A failed read is retried: assert what was asked,
  never how many times. Settle after `enterText` before asserting a button enabled.

Assert what the screen shows from the server's answer, that the action **sent the right DTO**, that a
refusal renders as its text and nothing else changed, that a publication changed the screen without a
re-read.

## 4. The gate — before a test is added

Four answers, a sentence each; a missing one means the test is not written yet.

1. **What it protects** — an observable behaviour or contract: a refusal and its code, what a command
   writes and publishes, what a screen shows from an answer, a calculation's result. Cosmetics protect
   nothing.
2. **Which credible regression turns it red** — a change someone could plausibly make, named; §5
   proves it does.
3. **Why existing coverage misses it.** Each contract has one owner test, at the tier the table above
   gives it: a refusal is the acceptance test's, what a screen makes of the answer is the widget
   test's, a DTO's shape the contract test's. Another tier only for a risk of its own there — the
   refusal's text on screen, not the refusal again; a handler's predicate or a controller's helper is
   not tested alone while the call proves each of its cases. Owned elsewhere: the framework (calls,
   updates, reconnects, upload retries — tested in the DartWay repository) and generated code (the
   round trip and `generate --check`). A new case is a row of the existing list or table, its setup a
   method on the harness — not a near-duplicate beside it.
4. **Whether it needs a seam no production caller uses** — a constructor parameter, a
   `@visibleForTesting` export, a flag, a provider overridden to record calls. Then it is tested at the
   real boundary instead — the server through its calls, the screen through the fake server; the
   seams are the framework's (`DwTestClock`, `server.http`, `DwFakeServer`). Production code whose only
   caller is a test is dead, not covered.

**A test that breaks under a refactor that keeps the behaviour asserts the implementation** — it is
rewritten at the boundary that owns the behaviour. No coverage thresholds, and none reported.

**Junk** — each of these fails the gate:

- **Runs, asserts nothing it produced**: a screen pumped or a handler called, ending on no exception,
  `isNotNull`, or a widget that is there whatever the answer. Assert the outcome, not that code ran.
- **A copy compared with the copy**: an expectation built by the code under test (the mapper making the
  expected DTO), a hand list beside the one the code builds (refusal codes, routes, registered DTOs) —
  red only when someone edits one side. The mutation of §5 does not find it; reading each side's source
  does.
- **The fake implements the assertion**: a `DwFakeServer` handler that filters, sorts or refuses by
  logic of its own, and a widget test that then "proves" the filter, the order or the rule. It proves
  the fake; the rule is the server's (§2).
- **The setup does the subject's work**: a row inserted through `server.db` that the command should
  write, a `server.publish` standing in for the command's publication, an outcome read from a table
  the path never writes.
- **A declaration read back**: a handler's access rule, a channel kind's rule, a `DwFeatureSpec` field
  or a settings default asserted as declared. What a rule promises is proven by a call it refuses.
- **A refusal for the wrong reason**: "another member is refused" with a caller who is not signed in,
  stopped before the rule is reached. Assert the code (`refusedWith`) from a caller only the rule
  stops.
- **Structure by test**: a test reading `lib/` for an import, a call or a file. Structure is the
  checker's (`dart run dartway_cli:dartway check`); a rule it lacks is a framework finding
  (`dartway-framework-notes`).
- **A name the test does not keep**: "hides archived invoices" over a list with no archived one,
  "retries" with a single attempt.

## 5. A test is proved by breaking the code

Before committing a test, **break the one thing it is about** — a comparison, a flag, one line — and
watch it go red; name the change in the review ("removed `isDeleted` from the mapper — red"). Two
shapes survive this proof while testing nothing: the subject is inert where it stands (never mounted,
never reached), and a mutation that changed two things, going red for the wrong reason.

**A bugfix starts with its test, red on the unfixed code for the reason the bug names** — the failure
is the bug, not a compile error or a missing helper — and green after the fix; the review says so
("red before the fix: expected `slotTaken`, got ok"). A regression test that never failed proves the
fake, not the fix. One test, at the boundary that owns the bug — not the same scenario replayed at
every tier it crossed.
