---
name: dartway-testing
description: >-
  How a DartWay project tests itself, by where the behaviour lives: the contract in
  __SHARED_PKG__ (`dart test` — codecs round-trip through the protocol, `validate()` codes and
  fields, a request's `onUpdate` and channels); the server as acceptance tests on a real Postgres
  and MinIO (`dartway test`; `DwTestDatabase` per test file, `DwTestServer.start`, the real client
  from `connectClient()`, raw wire through `caller()` / `openLive()`, `DwTestStorage`, `wakeJobs`);
  screens as widget tests on the in-memory server from `package:dartway_client/testing.dart`
  (`DwFakeServer`, `DwFakeStorage`, `dwFakeTablePage` …) with the app's own `DwFlutterCore` built
  per test and disposed after it, the localization delegates mounted and the locale pinned. Covers
  what deserves a test and what does not, the skeleton's harnesses, the timing traps, and why there
  are no coverage thresholds. Use when writing or reviewing tests, when a widget test fails with
  "Dw is not initialized" / "Another dw core is alive" / "found 0 widgets" / a pending Timer, or
  when an acceptance test cannot reach its database.
---

# DartWay — how a project tests itself

`dartway-clean-code` Part 3 decides **what** deserves a test: the threshold is the complexity of
the behaviour, never the fact that a line changed. This skill decides **where** the test goes and
how to write it.

**The level follows where the behaviour lives.** A DartWay project has three places where a rule
can live, and each has its own kind of test:

| The behaviour | Lives in | Its test | Runs with |
|---|---|---|---|
| What a DTO carries, which field a command refuses, what an arriving object does to a request, which channel a request listens on | The contract, `__SHARED_PKG__` | **Contract test**, pure Dart | `dart test` in `__SHARED_PKG__` |
| Who may call what, what a command writes and publishes, who may subscribe, what a job does, where a file lands | Handlers, access and channel rules, jobs, upload rules — `__SERVER_PKG__` | **Acceptance test** against a real server on a real database and storage | `dartway test` |
| What a screen shows, what the user's action sends, how a refusal or a live update looks | A feature — `__FLUTTER_PKG__` | **Widget test** on the in-memory server | `flutter test` in `__FLUTTER_PKG__` |
| A calculation, a parse, a state machine with no I/O | A plain class or an extension | **Unit test**, in whichever package holds it | `dart test` / `flutter test` |

Choosing the wrong place is the common failure. A widget test cannot prove that a member is refused:
the button being hidden is not the rule, the server's access rule is. An acceptance test cannot prove
that the button sends the right command. And a contract rule tested only through the server is
tested on one of the two sides that apply it.

---

## 1. The contract — `dart test` in `__SHARED_PKG__`

The shared package is pure Dart, so its tests need nothing running. The skeleton ships them in
`__SHARED_PKG__/test/`; extend that file's lists rather than starting a new style.

**Every DTO travels and comes back equal.** One test lists a value of every data object, request and
command — with the optional fields set, and once more without them — and decodes each through the
project's protocol:

```dart
for (final object in <DwWireObject>[
  const ListMyInvoices(),
  const PayInvoice(invoiceId: 7, note: DwFieldPatch.clear()),
  invoice(paidAt: null),
]) {
  expect(
    appProtocol.decodeNamed(object.dwTypeName, object.toJson()),
    object,
    reason: object.dwTypeName,
  );
}
```

It catches a type missing from the registry, a field that does not survive the trip, and equality
that ignores a field (which would make the client treat two different requests as one). A new DTO
is a new line here.

**Validation, as codes and fields.** A `DwSelfValidating` command's `validate()` runs on both sides,
so its test is here, asserted as `code@field` rather than as text:

```dart
List<String> codes(DwSelfValidating dto) => [
  for (final refusal in dto.validate()) '${refusal.code}@${refusal.field}',
];
expect(codes(const PayInvoice(invoiceId: 0)), ['dw.invalid@invoiceId']);
```

**Update actions and channels are pure functions — test them as such.** What a list request does
with an arriving object is `onUpdate`, and a mistake in `matches` shows up in the app as a row that
does not leave its filter, with nothing failing anywhere:

```dart
const unpaid = ListMyInvoices(status: InvoiceStatus.unpaid);
expect(unpaid.onUpdate(invoice(status: InvoiceStatus.unpaid)), DwUpdateAction.upsert);
expect(unpaid.onUpdate(invoice(status: InvoiceStatus.paid)), DwUpdateAction.remove);
expect(
  const ListMyInvoices().channels.single.resolvedFor(42).wireName,
  'invoices:42',
);
```

Write one whenever a request has `matches`, a custom `onUpdate`, a `sort`, or a caller channel.

## 2. The server — acceptance tests with `dartway test`

A handler's access rule, what it writes, what it publishes and to whom run inside a real call against
a real database. A mock of the context would only restate the code, so the test starts the project's
real server and talks to it the way an app does.

### Running them

```bash
dartway test                          # from the project root
dartway test -- --name 'refund'       # arguments after -- go to dart test
dartway test --keep                   # leave the database container up to inspect a failure
dartway test --no-storage             # a server without uploads
```

`dartway test` starts a Postgres and a MinIO for the run on ports Docker picks, passes their
coordinates as `DW_DATABASE_*` (the maintenance database `postgres`) and `DW_STORAGE_ENDPOINT` /
`_ACCESS_KEY` / `_SECRET_KEY`, runs `dart test` in `__SERVER_PKG__`, and removes both containers at
the end — Ctrl-C included.

Do not add a test database to `docker compose` and do not point the suite at a fixed port. A fixed
port is shared between projects on one machine, and a second container that does not get it starts
anyway with the port unpublished: the suite then reads the neighbour's database and can pass having
verified nothing. A database that outlives its run turns up as arithmetic — `Expected: <2>, Actual:
<3>` — several hypotheses away from the cause.

Running `dart test` by hand works when `DW_DATABASE_*` names a Postgres where the user may create
databases (the development one does) and, for storage tests, `DW_STORAGE_*` names a MinIO. Without
them the suite fails at its first `create`, naming the missing variables.

### One database and one server per test file

```dart
late DwTestDatabase database;
late DwTestServer server;

setUpAll(() async {
  database = await DwTestDatabase.create(prefix: 'app_test');
  server = await DwTestServer.start(
    buildInvoiceServer(database: database.config), // the project's own server factory
  );
});
tearDownAll(() async {
  await server.stop(); // stops every client from connectClient first
  await database.drop();
});
```

- **`DwTestDatabase.create`** makes an empty database named `<prefix>_<random>` on the server
  `DW_DATABASE_*` names; `drop` removes it, disconnecting whatever still holds it. Starting the
  server migrates it — framework and project migrations — exactly as a deployment does, so an
  acceptance run also proves the migrations apply to an empty database.
- **`DwTestServer.start`** starts the server on a free loopback port without signal handling. Build
  it with the **same factory `bin/server.dart` uses**, overriding only what a test must: the database,
  the storage, and the auth config's code delivery (capture the codes instead of printing them) and
  resend delay. A server assembled separately for tests drifts from the one that ships.
- **Tests in one file share the database**, so each test creates its own members with distinct
  identifiers and asserts on what it created — never on table-wide counts it did not set up.

**The skeleton's harness does all of this once**, in `__SERVER_PKG__/test/support/`: start and stop,
a signed-up member by identifier and delivered code, an administrator promoted in the database, a
watch that waits until it is live, a matcher for a refusal code, a counting HTTP transport, a
recording live connector. Use it and extend it; a new test file is `setUpAll` → harness start,
`tearDownAll` → harness stop.

### Three ways to talk to the server

**The real client — for behaviour.** `server.connectClient()` answers a started `DwAppClient` over
real HTTP and the real live socket, with short test timings (`dwTestClientOptions`):

```dart
final client = await server.connectClient();
final session = (await client.command(
  DwVerifyCode(ticketId: ticket.id, code: code),
)).valueOrThrow;
await client.signIn(session);

final invoices = client.watch(const ListMyInvoices()); // live, like a screen
final paid = (await client.command(const PayInvoice(invoiceId: 7))).valueOrThrow;
```

A second member's client is how "the other device sees it live" and "someone else is refused" are
tested. Wait for live state with a small polling helper (the skeleton's harness has one) rather than a
fixed delay.

**Raw calls — for the wire.** `server.caller(token: …)` sends a call exactly as a client would and
answers the HTTP status, headers and body; `.response`, `.value(call)`, `.refusal`, `.updates` read
it:

```dart
final anonymous = server.caller();
addTearDown(anonymous.close);
final answer = await anonymous.call(const ListMyInvoices());
expect(answer.status, 401);
```

Use it when the status, a header or the idempotency key is the point. `server.openLive()` opens a raw
socket (`authenticate`, `subscribe`, `expect<…>()`, `expectSilence()`) for channel rules:
subscribing to another account's channel must answer `DwSubscriptionRefusedMessage`.

**The database — for what is stored.** `server.db` is the running server's `DwDatabaseHandle`:
assert the row a command wrote, arrange a state no command can reach yet. Do not assert through the
database what the client could observe — that ties the test to the schema instead of the behaviour.

### Jobs and storage

- **`server.wakeJobs()`** runs the job executor now instead of at its next poll. Call it after the
  command that enqueued, then wait for the effect.
- **`server.runInContext((ctx) async { ... })`** calls a domain service directly with a real
  context — no command, no scaffolding job: a background context in one transaction, publications
  delivered after commit, nothing delivered if it throws. Use it for a service that has rules of its
  own; what a command publishes to whom is still tested through the command.
- **`DwTestStorage.create(prefix:)`** provisions a public and a private bucket for the file on the
  MinIO `dartway test` started; pass `storage.config` to the server factory, `storage.drop()` after
  the server stops. `storage.keys(bucket)` lists what landed where. What to test — `dartway-uploads`.

### What deserves an acceptance test

**Write one when the rule is the point:** a role or ownership boundary, a refusal with its code and
field, a filter that must not leak another account's rows, what a command publishes and who receives
it, a channel rule, an idempotent retry, a job's effect, a file landing in the right bucket. A
bugfix in a handler starts with the failing test.

**Not** for a handler that reads a table and maps it with no rule in between — the framework's
calls, transport and updates are tested in the DartWay repository.

## 3. Screens — widget tests on the in-memory server

A DartWay feature reads and writes through the ambient `dw` and hands no callback out, so there is
nothing above it to spy on — and **nothing should be added to make it spyable**: a callback kept "for
tests" buys a weaker screen for a weaker test. The seam is the server itself, replaced by one in
memory.

### The in-memory server

`package:dartway_client/testing.dart` (`dartway_client` is a dev dependency of `__FLUTTER_PKG__`):

- **`DwFakeServer(protocol: appProtocol)`** speaks the real HTTP contract and live socket in memory —
  statuses, idempotent commands, `426` below `minAppBuild`, hello and authentication on the socket,
  subscriptions — with handlers registered per DTO type:

  ```dart
  final server = DwFakeServer(protocol: appProtocol)
    ..registerToken('token-42', 42)
    ..onRequest<ListMyInvoices>((request, call) => DwCallOk(<Invoice>[...invoices]))
    ..onCommand<PayInvoice>((command, call) {
      final paid = invoices.first.copyWith(status: InvoiceStatus.paid);
      call.publish(DwLiveChannel.forAccount(AppChannel.invoices, 42), [paid]);
      return DwCallOk(paid);
    });
  ```

  A handler answers a `DwCallResult` whose value has the call's result type exactly
  (`DwCallOk(<Invoice>[])`, not `DwCallOk([])`). `call.accountId` is the caller; `call.publish`
  publishes as a real command does (in the response when the caller's live connection subscribes
  to the channel, and to other subscribers).
- **Assert what left**: `server.callsOf<PayInvoice>()` (each with `.call`, headers, status),
  `server.requestsOf<ListMyInvoices>()`, `server.executions(key)`.
- **Push from outside**: `server.publish(channel, [object])` is an update someone else caused;
  `server.closeChannel`, `server.revokeToken`, `server.reachable = false` for the rest.
- **`server.errors`** collects handler exceptions, calls nobody registered a handler for, and frames
  that do not decode. **Every test ends asserting it is empty** — a fake that swallowed them would let
  a broken test pass.
- Paged reads: answer with `dwFakeTablePage(rows, request)`, `dwFakeOffsetPage(rows, request, call.page)`
  or `dwFakeWindow(newestFirst, request, call.page)` — they page as the real server does.
- Uploads: `DwFakeStorage(server)` and its `transport` (`dartway-uploads`).

### The core: built per test, disposed after it

The app builds its `DwFlutterCore` in one factory in `lib/core/`, which takes the transports as
optional parameters. A widget test calls **that factory** with the fake's `httpTransport` and
`liveConnector`, a `DwMemoryTokenStore` holding the session to start signed in (or none),
`clientOptions: dwFakeClientOptions`, and a `DwFakeStorage`'s `transport` when uploads are involved:

```dart
final core = createInvoiceCore( // the app's own factory, which assigns dw
  baseUrl: server.baseUrl,
  appVersion: appVersion,
  httpTransport: server.httpTransport,
  liveConnector: server.liveConnector,
  tokenStore: DwMemoryTokenStore(session),
  clientOptions: dwFakeClientOptions,
);
addTearDown(core.dispose);
await core.init();
await tester.pumpWidget(const ProviderScope(child: InvoiceAppRoot()));
```

- **Through the app's factory, not a second core written in the test.** A core assembled in a test
  drifts from the one the app ships — its refusal text, its update-required screen, its error
  reporting — and the drift is invisible until it matters.
- **With a token store of its own, the core needs no storage plugin** — no platform channel for a
  widget test to answer.
- **One core at a time, and it must be disposed.** Building a core while another is alive throws
  `Another dw core is alive`; the next test in the file fails on it, blaming a test that did nothing
  wrong. `addTearDown(core.dispose)` right after building covers a test that failed halfway;
  disposing twice is harmless.
- **The core is needed to render, not only to tap.** A feature reaches `dw` while building —
  `dw.action(...)` is constructed in `build` — so a test that never taps still needs one. Without it
  the subtree throws `Dw is not initialized` and the test dies later at a finder ("found 0 widgets"),
  with the real cause in an exception block further up the output.

**The skeleton's harness does this once**, in `__FLUTTER_PKG__/test/support/`: a fake app that answers
the reads every screen makes on its way (the signed-in profile, the settings) the way the real
handlers do, and a running app that builds the core, pumps the app at phone size, settles, taps,
waits out notifications, and on stop unmounts, disposes the core and asserts the fake server met no
surprise. It can also mount the app under `DwAppBootstrapper`, as `DwAppRunner` does, for what covers
the whole app (the update-required screen). A new widget test starts from it.

The signed-in user is the session in the token store and the profile the fake answers — not a
provider override. There is no session to fake beyond that.

### Localization is mounted with a locale, not just with delegates

Every user-visible string comes from the app's localizations, so the tree must be able to answer the
lookup. The app's root widget already carries the delegates and the supported locales; a test that
builds its own `MaterialApp` around a widget mounts **three** things:

```dart
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'), // explicit: the default is whatever the platform reports
  home: subject,
)
```

- **Without the delegates** the first lookup fails a null check, and the failure lands where the
  subject fails to build rather than where localization is missing. When localization reaches a
  living app this turns every such test red at once — fix it in the shared harness, not per file.
- **Without an explicit locale** the tree resolves against the locale the test platform reports, so
  `find.text('Pay')` asserts on whichever language that was. Pin it to the language the assertions
  are written in — `locale:` on a `MaterialApp` the test builds; for the app's root, which takes its
  locale from the app's locale provider, set `tester.platformDispatcher.localeTestValue` before
  pumping (with `addTearDown(tester.platformDispatcher.clearLocaleTestValue)`), or override that
  provider in the test's `ProviderScope`.

A test that needs another language passes that locale — the point of it being a value in one place.

### Traps about time

- **Never `await` a call on the core directly in a widget test** — `core.signOut()`, a `dw.command`
  outside a tap. The test runs on fake time and the fake server's traffic moves only with pumped
  frames, so the future never completes. `await app.run(tester, core.signOut())` pumps until it does
  and fails, naming the wait, after ten seconds of pumped time.
- **Do not `pumpAndSettle` a screen that shows a spinner.** A progress indicator animates for as long
  as it is on screen, so settling by frames waits out its timeout. Pump a few short frames, then a few
  hundred milliseconds for Riverpod, the in-memory traffic and a page transition, then a few frames
  more — the skeleton's harness settles exactly that way.
- **A notification holds a timer.** A successful `dw.action` shows a notification that removes itself
  after `DwUiNotification.defaultDuration`; a test that ends with it on screen fails on "A Timer is
  still pending even after the widget tree was disposed" — an error about a toast in a test about a
  payment. Pump that duration before unmounting, and before tapping a button the notification covers.
- **A failed read is retried.** With `dwFakeClientOptions` retries are milliseconds apart, so a read
  you made fail is attempted several times while the test settles. Assert the shape of what was asked
  (the request arrived, the error text is on screen), never the number of attempts.
- **A text field may report a change a frame late** — settle after `enterText` before asserting that a
  button became enabled.

### What a widget test asserts

That the screen shows what the server answered; that the user's action **sent the right DTO**
(`callsOf<PayInvoice>().single.call` equals the expected command); that a refusal is rendered as its
text and nothing else changed; that a published update changes the screen without a re-read
(`requestsOf` did not grow); that the signed-out and failure states look like themselves.

## 4. What we deliberately do not test

- **The framework.** That a command reaches the server, that a list applies an update, that a watch
  resubscribes after a reconnect, that an upload retries — all tested in the DartWay repository.
  Re-testing it in a project buys nothing and breaks on every upgrade.
- **Cosmetics.** A recoloured button, a padding, a rename. A test written for a checkbox contradicts
  KISS and YAGNI, and it will be deleted by the first person who touches the widget.
- **Generated code.** Codecs, the protocol registry, table definitions, the schema. The contract's
  round-trip test covers what matters about them; `dartway generate --check` covers the rest.
- **A UI rule that mirrors a server rule.** Asserting that the pay button is hidden from a viewer is
  fine as UI, but it says nothing about access — write the acceptance test for the rule and let the
  widget test be about the button.

## 5. No coverage thresholds

We do not set a percentage and we do not gate anything on one. A threshold is met by writing tests for
what is easy to cover — getters, mappers, generated wrappers — while the calculation everyone is afraid
of stays at the one test it had. The number goes up and the suite gets worse.

`dartway check` does not ask whether a feature has a test either: that is not a gap with a name, it is
a percentage. The question at review is "**is the thing that would break covered, at the place where
it lives**" — which is what `dartway-finish` asks.

## 6. A test is proved by breaking the code, not by passing

A new test that passes has proved nothing yet: a test that cannot fail passes too, and it passes
for the rest of the project's life. So before a test is committed, **break the thing it is about and
watch it go red** — change the comparison, drop the flag, return the wrong row, delete the line the
test exists for. It stays green: it does not test what its name says, and the fix is the test, not
the code.

State the mutation in the review, by name: "removed `isDeleted` from the mapper — red; removed the
blanking in the hook — red". A reviewer asked to *check* a test reads it and agrees with it. A
reviewer asked to **break it and say whether it went red** finds the hollow ones: Studio did this
for one day across its own suite and found seven tests that had been passing without exercising
anything, plus a cascade deletion nobody had noticed and a schema check its own new code walked
around.

All of them are one thing: **a claim with nothing that could make it false.** That is the question
to ask of a test, and of a check, and of a startup guard — *name the state in which this must fail,
and say whether it is reachable.* A claim with no such state is a ritual, however green.

Three shapes turn up again and again, and all look like ordinary green:

- **The subject is inert where the test stands.** A test of the Studio binding that never mounts the
  binding, a test of a rule whose enforcement runs only on a real connection, a test of a job that
  nothing runs. Whatever is passed in, the assertions hold — because nothing reads them.
- **The test compares a copy with the copy.** A manifest checked against a hand-written list of
  zones instead of against the router; an expected JSON built by the same function that encodes it;
  the length of a list asserted against the length of what that list was built from. It cannot
  disagree with itself, so it goes red only when somebody edits both — and in the tautological case,
  never at all.

  **This is the shape the mutation does not find**, and the only one: break something nearby and the
  test goes red, which reads as proof. It is found by eye, by asking of each side where its value
  came from — two sides from one source are one side written twice.
- **The mutation proved something else.** The trap of this practice itself: an edit that changes two
  things at once — the behaviour *and* who is watching it — goes red for the wrong reason and is
  written down as proof. Removing a whole handler makes every test of that path fail, including the
  ones that never asserted anything about it. Change one thing: a comparison, a flag, one line, the
  value of one field. If the red cannot be explained in a sentence naming that one thing, it proved
  nothing.

This is the same rule the framework applies to its own work — `dartway-finish` asks for the
mutation, and a change that cannot be broken in front of a reviewer is not covered.

## Common mistakes

- Testing an access rule through the UI instead of an acceptance test.
- A server built for tests by hand instead of through the project's server factory.
- Asserting table-wide counts in a file whose tests share one database.
- A fixed delay instead of waiting for the condition (a watch going live, a job's effect).
- A core built in a test and not disposed — the *next* test fails with "Another dw core is alive".
- A second `DwFlutterCore` written inside the test instead of the app's factory.
- A widget test that does not assert `server.errors` is empty.
- `pumpAndSettle` on a screen with a spinner; ending a test with a notification on screen.
- A `MaterialApp` in a test with the delegates but no locale.
- Keeping a callback parameter on a widget "so it can be tested".
- A test whose subject is inert where it stands — the widget never mounted, the rule never reached —
  so it passes whatever it is given.
- A test that compares a copy with the copy it is checking: a hand-written list beside the one the
  code builds, an expectation encoded by the function under test.
