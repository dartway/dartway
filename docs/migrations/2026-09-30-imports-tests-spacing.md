---
title: "package: imports, tests that mirror lib/, spacing tokens and the lint plugin: dartway check fails the rest"
affects:
  dartway_core_flutter: "0.21.0-dev.16"
  dartway_cli: "0.22.0"
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

rewrites every relative import and export in `lib/` of the three packages to its `package:` form and
sorts the import block it touched, then checks. Generated files are left to their generator. Run
`dart format` over the packages after it, and `dart analyze`: a file that imported the same library
both ways now imports it twice (`duplicate_import`) — delete one line. Under `test/`, nothing changes: the harness in
`test/support/` is imported relatively, at any depth.

**The lint plugin — mechanical.** `dartway update` adds

    plugins:
      dartway_lints: ^0.5.0

to the Flutter package's `analysis_options.yaml` (or raises an older caret), pinned to the channel —
or, with `--framework-path`, to that checkout by `path:`. A `plugins:` section it cannot edit safely
is left as it is, and the command prints the lines to add by hand.
Restart the analysis server, then run `dart analyze` — `flutter analyze` runs no plugins. Fix what
the rules report (`forbidden_ui_style_usage`, `forbidden_provider_scope`); in a project that never had
them this is where the raw styles and nested `ProviderScope`s surface.

**Spacing — add the scale, then name the numbers. Never change a visible value.** Copy
`template/dartway_starter_flutter/lib/ui_kit/theme/app_space.dart` into `lib/ui_kit/theme/` and add
`part 'theme/app_space.dart';` to `ui_kit.dart`. The steps are named by their value (`s2` … `s48`),
so the scale grows without renaming: count the values the check lists, and add the project's own
dominant ones as steps (`static const double s14 = 14;`) — do not round them to a neighbour, since
that moves what the user sees in a change that is meant to move nothing. Then replace each number
with its step:

    - const Gap(12),
    + const Gap(AppSpace.s12),
    - padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    + padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16, vertical: AppSpace.s8),
    - Wrap(spacing: 6, runSpacing: 4, …)
    + Wrap(spacing: AppSpace.s6, runSpacing: AppSpace.s4, …)

A value used once or twice that the design does not mean as a step is a sign it belongs to one
component: move it into that component in the kit, where numbers are allowed. Whether the scale is
then tightened is a design decision, taken apart from this migration. A `SizedBox` with a `child:`
or with both a width and a height, and `SizedBox.square`, size something and are not checked; `0`,
`EdgeInsets.zero` and `double.infinity` pass.

**Tests — move them to the mirror of what they test.** Root-level acceptance tests of a server
feature move mechanically: `dart run dartway_cli:dartway check --fix --type testLayout` moves each
`test/<feature>[_<scenario>]_acceptance_test.dart` to `test/src/<feature>/` when `lib/src/<feature>/`
exists, rewriting its relative import of `test/support/`. The rest by hand, with `git mv`, fixing that
import:

    - test/invoices_refund_acceptance_test.dart   import 'support/app_harness.dart';
    + test/src/invoices/invoices_refund_acceptance_test.dart   import '../../support/app_harness.dart';

The forms: `lib/<path>.dart` → `test/<path>_test.dart`; a test of a whole folder (a server feature
through its calls) → `test/<path>/<folder>/<folder>_acceptance_test.dart`, and a scenario of it
`<folder>_<scenario>_acceptance_test.dart` beside it; a scenario across features goes with the
feature that owns it; a rule of `core/` at its file (`lib/src/core/auth.dart` →
`test/src/core/auth_test.dart`); the contract test at the mirror of the shared package's library
(`test/contract_test.dart` → `test/<project>_shared_test.dart`). Helper files beside tests
(`test/helpers.dart`, `test/src/chat/chat_fixtures.dart`) move to `test/support/`.

**The harness — one per side.** A widget test that pumps its own `ProviderScope` (with overrides) or
builds a `DwFakeServer` moves onto `TestApp`/`FakeApp` from `test/support/app_test_app.dart` (copy
the skeleton's if the project has none): the signed-in session is the token in the store and the
profile the fake answers, not an override; what a screen reads is a handler added to `FakeApp`. A
server test that starts a server of its own moves onto `AppHarness` from
`test/support/app_harness.dart`; a configuration only one test needs becomes a method on the harness
(the example's `AppHarness.startStorageOnly`).

**Doc comments** in another script than the project's language are a warning, not a failure:
translate them as you touch the files. Comments the skeleton wrote and the project kept unchanged are
not reported (the check compares with the template the project was created from, when a framework
checkout is at hand), nor are generated files. Log and error strings stay English.

## How to check

`dart run dartway_cli:dartway check`: no `relativeImport`, `testLayout`, `testHarnessBypassed`,
`rawSpacing` or `lintsPluginMissing`; then `dart analyze` in the Flutter package, and the suites of all
three packages (`flutter test`, `dart test`, `dart run dartway_cli:dartway test`) — a moved test that
lost its import fails to compile rather than silently not running.
