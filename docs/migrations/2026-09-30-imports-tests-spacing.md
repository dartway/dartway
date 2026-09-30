---
title: "package: imports, tests that mirror lib/, spacing tokens and the lint plugin: dartway check fails the rest"
affects:
  dartway_core_flutter: "0.21.0-dev.9"
  dartway_cli: "0.13.0"
---

## Who is affected

Every project `dart run dartway_cli:dartway check` now fails on any of:

- a relative `import`/`export` in `lib/` of the Flutter, server or shared package (`relativeImport`);
- a test file that mirrors no `lib/` path, a helper outside `test/support/`, or a test inside it
  (`testLayout`);
- a widget test building its own `ProviderScope` or `DwFakeServer`, a server test its own
  `DwTestServer.start`/`DwAppServer`, outside `test/support/` (`testHarnessBypassed`);
- a number as a gap or an inset outside `ui_kit/`: a spacer `SizedBox(height:|width:)`, `Gap(n)`,
  `EdgeInsets.*(n)` (`rawSpacing`);
- a Flutter package whose `analysis_options.yaml` does not enable the `dartway_lints` plugin
  (`lintsPluginMissing`) — every project created before `dartway create` wired it.

And it warns on a doc comment in `lib/` written in another script than the project's language
(`docCommentLanguage`). `dartway_lints` 0.5.0 drops `deep_relative_import`: a
`// ignore: dartway_lints/deep_relative_import` can go.

## What to change

**Imports — mechanical.** In the project root:

    dart run dartway_cli:dartway check --fix

rewrites every relative import and export in `lib/` of the three packages to its `package:` form,
then checks. Generated files are left to their generator. Run `dart format` over the packages after
it, and `dart analyze`: a file that imported the same library both ways now imports it twice
(`duplicate_import`) — delete one line. Under `test/`, nothing changes: the harness in
`test/support/` is imported relatively, at any depth.

**The lint plugin — mechanical.** `dartway update` adds

    plugins:
      dartway_lints: ^0.5.0

to the Flutter package's `analysis_options.yaml` (or raises an older caret), pinned to the channel.
Restart the analysis server, then run `dart analyze` — `flutter analyze` runs no plugins. Fix what
the rules report (`forbidden_ui_style_usage`, `forbidden_provider_scope`); in a project that never had
them this is where the raw styles and nested `ProviderScope`s surface.

**Spacing — add the tokens, then replace the numbers.** Copy
`template/dartway_starter_flutter/lib/ui_kit/theme/app_space.dart` into `lib/ui_kit/theme/`, add
`part 'theme/app_space.dart';` to `ui_kit.dart`, and adjust the steps to your design if it has its
own scale. Then replace each number the check lists with its step:

    - const Gap(12),
    + const Gap(AppSpace.m),
    - padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    + padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.s),

A value between two steps rounds to the nearer one (the skeleton took 6 → `xs`, 20 → `xl`,
28/36 → `xxl`); if the design needs it exactly, it is a step of the scale — added once, in
`app_space.dart`. A number that belongs to one component (a strip's height, a badge's inner padding)
moves into that component in the kit, where numbers are allowed. `SizedBox` with a `child:` sizes the
child and is not checked; `0`, `EdgeInsets.zero` and `double.infinity` pass.

**Tests — move them to the mirror of what they test.** `git mv`, then fix the relative import of
`test/support/`:

    - test/invoices_acceptance_test.dart            import 'support/app_harness.dart';
    + test/src/invoices/invoices_acceptance_test.dart  import '../../support/app_harness.dart';

The forms: `lib/<path>.dart` → `test/<path>_test.dart`; a test of a whole folder (a server feature
through its calls) → `test/<path>/<folder>_acceptance_test.dart` for `lib/<path>/<folder>/`; a rule of
`core/` at its file (`lib/src/core/auth.dart` → `test/src/core/auth_test.dart`); the contract test at
the mirror of the shared package's library (`test/contract_test.dart` →
`test/<project>_shared_test.dart`). A test that walks two features is split by feature. Helper files
beside tests (`test/helpers.dart`, `test/src/chat/chat_fixtures.dart`) move to `test/support/`.

**The harness — one per side.** A widget test that pumps its own `ProviderScope` (with overrides) or
builds a `DwFakeServer` moves onto `TestApp`/`FakeApp` from `test/support/app_test_app.dart` (copy
the skeleton's if the project has none): the signed-in session is the token in the store and the
profile the fake answers, not an override; what a screen reads is a handler added to `FakeApp`. A
server test that starts a server of its own moves onto `AppHarness` from
`test/support/app_harness.dart`; a configuration only one test needs becomes a method on the harness
(the example's `AppHarness.startStorageOnly`).

**Doc comments** in another script than the project's language are a warning, not a failure:
translate them as you touch the files. Log and error strings stay English.

## How to check

`dart run dartway_cli:dartway check`: no `relativeImport`, `testLayout`, `testHarnessBypassed`,
`rawSpacing` or `lintsPluginMissing`; then `dart analyze` in the Flutter package, and the suites of all
three packages (`flutter test`, `dart test`, `dart run dartway_cli:dartway test`) — a moved test that
lost its import fails to compile rather than silently not running.
