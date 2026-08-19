---
name: dartway-testing
description: >-
  How a DartWay project tests itself, by layer: an access or save rule from DwCrudConfig
  is an integration test on the server against a live database (withServerpod +
  serverpod_test_tools.dart); plain logic is a unit test; a feature is a widget test with the
  core booted from setUpAll through the app's own idempotent initializer and the server standing
  in as DwRecordingServerTransport from package:dartway_serverpod_core_flutter/testing.dart —
  reads prepared with answerGetAll/answerGetOne/answerGetCount, writes read back off
  transport.saves/transport.deletes, the signed-in user overridden in the test's own ProviderScope.
  Covers why the core must be up for a feature to even render, why the offline store is not a test
  seam, the two timing traps (a toast holds a timer past pumpAndSettle, a failed read is retried),
  what is deliberately not tested, and why there are no coverage thresholds.
  Use when writing or reviewing tests, when a test cannot see what a feature saved, or when a
  widget test fails with LateInitializationError, "found 0 widgets" or a pending Timer.
---

# DartWay — how a project tests itself

`dartway-clean-code` Part 3 decides **what** deserves a test (the threshold is behaviour
complexity, never the fact that a line changed). This skill decides **where** that test goes and
how to write it, because in a DartWay project the answer is not obvious: a feature reads and writes
through the ambient `dw`, hands no callbacks out, and has no repository to inject.

**The level follows where the behaviour lives.** Three layers, three different questions:

| The behaviour | Lives in | Its test |
|---|---|---|
| Who may read or save what, and what a save does to the database | `DwCrudConfig` on the server | **Integration test**, against a live database |
| A calculation, a parse, a state machine, a rule with no I/O | A plain class in the app | **Unit test** |
| The screen reads, the user acts, something leaves for the server | A feature widget | **Widget test**, with the core up |

Choosing the wrong layer is the common failure. A widget test cannot prove that a non-admin is
refused: the UI hiding a button is not the rule, the server is. And an integration test cannot
prove that the button sends the right model.

---

## 1. Rules — an integration test on the server

Access and save rules live in `DwCrudConfig`, run inside a real request, and touch the database.
Nothing below the server can check them, and a mock of the session would only re-state the code.

The machinery is already in the project: `withServerpod` from the generated
`test/integration/test_tools/serverpod_test_tools.dart`, which stands up a real Serverpod against a
test database.

```dart
withServerpod('appSetting write access', (sessionBuilder, endpoints) {
  setUpAll(() {
    DwCore.init<UserProfile>(
      userProfileTable: UserProfile.t,
      crudConfigurations: const [appSettingCrudConfig],
      dtoConfigurations: const [],
      channelConfigurations: const [],
      userProfileConstructor: (session, {required registrationRequest}) async =>
          throw UnsupportedError('outside this suite'),
      dwAlerts: DwAlerts.init(),
    );
  });

  test('a member cannot write a setting an admin can', () async {
    final session = sessionBuilder.build();
    // …sign the session in as each role and assert the DwApiResponse
  });
});
```

**Write one when the rule is the point:** a role boundary, an ownership check, a validation that
rejects, `beforeSaveTransaction` / `afterSaveTransaction` ordering, a filter that must not leak
another user's rows. **Not** for CRUD that is configured and does nothing else — that is testing
the framework, and the framework tests itself.

---

## 2. Plain logic — a unit test

Anything with no `dw`, no widget and no server: a parser, a price, a state machine, an extension
over a list of models. The cheapest layer, and where most of a project's logic should already be —
`dartway-clean-code` §2.11 takes it out of the widget for reasons that have nothing to do with
testing.

The skeleton ships one to copy: `test/core/app_settings/app_setting_key_test.dart` pins that
`AppSettingKey.parse` has **no failure path** — an absent row, a hand-edited value and nonsense all
resolve to something a screen can render.

---

## 3. A feature — a widget test with the core up

This is the layer that needs a technique, so it gets the rest of this skill.

### The seam is the transport, and nothing above it

A DartWay feature saves for itself: no callback is passed in, so there is nothing above it to spy
on. **Do not keep a callback alive as a test seam** — it buys a weaker screen for a weaker test.

The seam is one level down: the transport the core sends every server operation through. A test
hands `DwCore` its own instead of a Serverpod client, and then a save is a value in a list.

**The offline store is not this seam, and is documented not to be.** A write always leaves by the
transport first; `dw.repo.localWrites` is reached only after the connection refuses it. Reaching for
it to watch a save would force every save to declare itself durably queued, which is a lie about the
feature's intent.

### The harness, written once per project

The skeleton ships it as `test/support/app_test_core.dart`. Read that file; this is what it holds
and why.

```dart
// The project's own generated Protocol — the same object the real client carries.
// It is the only thing that names the models right: a generated model is an
// abstract class with a private implementation, so its `runtimeType` reads
// `_AppSettingImpl`. Import it prefixed — the DartWay core declares a `Protocol` too.
final testTransport = DwRecordingServerTransport(
  serializationManager: app.Protocol(),
);

void bootTestCore() {
  initExampleDwCore(transport: testTransport);  // the app's own core initializer
  DefaultModels.initRepository();           // list skeletons need the default models
}
```

**Boot through the app's own initializer, not a second core built in the test.** A core assembled
in a test drifts from the one the app ships, and the drift is invisible until it matters. Give the
initializer an optional `transport` and build **no Serverpod client** when it is set: a client
brings a connectivity monitor and an auth key manager, both of which reach for platform channels a
widget test has no business answering.

**Keep the initializer idempotent** (`if (_coreInitialized) return;`). There is one core per
process and it cannot be replaced, so the second test file in a run would otherwise meet
`Dw is already initialized` or a `LateInitializationError`.

### The core is needed to *render*, not only to tap

`dw.action(...)` is constructed inside `build`. A feature therefore touches `dw` while building,
before anything is interacted with — **so a test that never taps anything still needs a booted
core**. Miss this and the failure does not say so: the subtree fails to build, and the test dies
later at a finder ("found 0 widgets"), with the real cause in a separate exception block further up
the output.

### Reads are prepared, writes are read back

```dart
testTransport.answerGetAll = (_) async => listResponse([storedAppName('Acme')]);

await tester.pumpFeature(const AdminSettingsForm(), signedInAs: adminProfile());
await tester.pumpAndSettle();

await tester.tapAndSettle(find.byType(AppCheckbox));

expect(testTransport.saves, hasLength(1));
final saved = testTransport.saves.single.model as AppSetting;
expect(saved.settingKey, AppSettingKey.signUpEnabled.key);
```

- **A read must be prepared.** `answerGetOne` / `answerGetAll` / `answerGetCount`; an unprepared one
  throws `DwUnpreparedServerCall` naming the call and the field that would answer it. That is
  deliberate: a test that does not know what its subject fetches is the thing being caught, and an
  empty list would hide it behind an empty state that looks intentional.
- **A write needs no setup.** `saveModel` echoes the model back and `delete` succeeds, because the
  assertion is about what *left*. Set `answerSave` / `answerDelete` only when the response matters —
  the id assigned on insert, a refusal.
- **What left is read back** off `transport.saves` and `transport.deletes`: the model, the
  `apiGroup`, the class name on the wire. `transport.reads` holds the requests, so "this list is
  unfiltered" stops being a claim in a doc comment.
- **Reset between tests** (`setUp(resetTestCore)`), because the transport outlives them all.

### The signed-in user is an override, not a session

There is no session in a test — no key manager, nothing to sign into. Stand the user up in the
test's own `ProviderScope`:

```dart
ProviderScope(
  overrides: [
    dw.userProfileProvider.overrideWithValue(profile),
    dw.requireUserProfileProvider.overrideWithValue(profile),
  ],
  child: /* … */,
)
```

This is the sanctioned use of `overrides:` — the app never writes a `ProviderScope` of its own
(`forbidden_provider_scope`), a test may. Inventing a session instead would test the framework's
session rather than this feature.

### Two traps about time, not about the transport

- **`pumpAndSettle` does not drain a notification.** A successful
  `dw.action(onSuccessNotification: ...)` inserts a toast that removes itself on a `Future.delayed`;
  settling waits for frames, not for timers. The test then fails on "A Timer is still pending even
  after the widget tree was disposed" — an error about a toast, in a test about a save. Pump
  `DwUiNotification.defaultDuration` after the tap, once, in a shared `tapAndSettle` helper.
- **A failed read is retried.** Riverpod retries a failed provider on its own with a growing
  backoff, so a read you made fail is attempted many times while the test settles. Assert the shape
  of what was asked — `transport.reads.map((r) => r.operation)` — never the number of attempts; a
  count pins somebody else's default.

And one that is not about time: **`AppTextFormField` delivers `onChanged` from a post-frame
callback**, so after `enterText` the form's own state (and whether the Save button is enabled) is a
frame behind. Use `pumpAndSettle`, not `pump`.

---

## 4. What we deliberately do not test

- **The framework.** That `dw.repo.saveModel` reaches the server, that a list provider refetches on
  an update, that the session survives a restart — all of it is tested in the DartWay repository,
  against the framework's own code. Re-testing it in a project buys nothing and breaks on every
  upgrade.
- **Cosmetics.** A recoloured button, a padding, a rename. A test written for a checkbox contradicts
  KISS and YAGNI, and it will be deleted by the first person who touches the widget.
- **Generated code.** Models, the protocol, migrations. There is nothing there a human wrote.
- **A UI rule that mirrors a server rule.** Asserting that the publish button is hidden from a
  member is fine as *UI*, but it says nothing about access — write the integration test for the
  rule and let the widget test be about the button.

## 5. No coverage thresholds

We do not set a percentage and we do not gate anything on one. A threshold is met by writing tests
for what is easy to cover, which is exactly the code that did not need covering — getters, mappers,
generated wrappers — while the calculation everyone is afraid of stays at the same one test it had.
The number goes up and the suite gets worse.

The question at review is not "how much is covered" but "**is the thing that would break covered,
and at the layer where it lives**". That is what `dartway-finish` asks.

## Common mistakes

- Testing an access rule through the UI instead of an integration test over `DwCrudConfig`.
- Building a second `DwCore` inside the test instead of calling the app's initializer.
- A core initializer without the idempotency guard — green alone, red as soon as a second test file
  boots it.
- Reaching for `dw.repo.localWrites` to observe a save.
- Asserting the number of server calls on a path where a read failed.
- `pump` instead of `pumpAndSettle` after typing into `AppTextFormField`.
- Keeping a callback parameter on a widget "so it can be tested".
