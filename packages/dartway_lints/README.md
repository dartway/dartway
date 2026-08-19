# dartway_lints

Custom lint rules enforcing [DartWay](https://dartway.dev) conventions.

## Rules

- **forbidden_ui_style_usage** (warning) — the UI kit is the single source of
  styles. Flagged everywhere outside `ui_kit/`: raw `Color(...)`,
  `TextStyle(...)`, `BorderRadius(...)`, `Colors.*`, `Theme.of(context)`, and
  the kit's own theme shortcuts (`context.theme`, `context.textTheme`,
  `context.colorScheme` — recognised by the *type* of the target, so `ctx` is
  caught as readily as `context`). Generated files are left alone.

  Feature code composes kit widgets and tokens instead. When Flutter insists on
  a style rather than a widget — `InputDecoration.labelStyle`, a `TextSpan`, an
  `Icon`'s colour — that widget belongs in the kit, and the feature composes it.

- **deep_relative_import** (warning) — a relative import may walk at most two
  levels up. One or two `../` read as "the feature next door"; beyond that the
  path names nothing (`'../../../../ui_kit/ui_kit.dart'`) and the destination
  belongs in the line: `package:my_app/ui_kit/ui_kit.dart`.

  Deliberately not `always_use_package_imports`, which also forbids the
  legitimate neighbour. The limit doubles as a structure signal: a "sibling"
  four levels away is not a sibling — either the group fell apart, or the thing
  being imported belongs in `shared/` or `common/`.

- **forbidden_provider_scope** (warning) — the application does not write a
  `ProviderScope`. The only one belongs to `DwAppRunner`, which wraps the whole
  app; files under `test/` (and `*_test.dart`) build their own freely.

  A nested scope with `overrides:` is the mistake that does not look like one:
  widgets under it *do* read the override, while a provider reaching the same
  provider through its own `Ref` resolves from the root container and silently
  gets the base value. `riverpod_lint`'s rule for this skips providers it cannot
  prove scoped — which it can only do for generated ones, and DartWay writes
  them by hand. A value that must differ per subtree is a family key or a
  constructor argument.

- **model_rebuild_by_constructor** (warning) — a Serverpod model constructor
  called with a real `id:`. A row being created never passes one (the id comes
  back from the database), so the call is rebuilding a row that already exists —
  and rebuilding is `copyWith`'s job.

  Serverpod makes a field with `default=`, and any nullable field, an *optional*
  argument. A method that rebuilds a model by naming its fields therefore keeps
  compiling when the model grows a field, and quietly writes the default into
  it. One real project reset a `priority` field on every edit of the record for
  months; the compiler, the tests and the review all saw nothing. The method
  even carried a doc comment asking for the opposite — the field was added by a
  task that never opened that file.

  Nothing is lost by the ban. The one reason to rebuild by hand — "`copyWith`
  cannot clear a nullable field" — is not true of the generated one: it takes
  `Object? field = _Undefined` and tests `field is T? ? field : this.field`, so
  passing `null` clears and omitting keeps. Matched through `SerializableModel`
  rather than `TableRow`, because the client half of a generated model — the
  half an application is written against — implements only the former.
  Serverpod's own output (`lib/src/protocol/`, `lib/src/generated/`) is left
  alone, and so are the two ids that are not real: `null`, and
  `dw.repo.mockModelId`. The second is the sentinel a skeleton default carries —
  `setupRepository(defaultModel: …)` builds an instance from nothing to give a
  loading skeleton its shape, and there is no row there to rebuild. That
  exemption is what `core/default_models.dart` rests on; the file needs no
  `// ignore_for_file:` and neither `example/` nor `template/` carries one.

## Testing

`example/` is the rules' test suite: files under `lib/app/` carry
`// expect_lint: <rule>` above every line that must be reported, and the files
that must stay silent — `lib/ui_kit/` writing styles freely, a feature importing
its neighbour one `../` away, `test/` building its own `ProviderScope`,
`lib/src/protocol/` rebuilding a model field by field the way the generator
does, `lib/core/default_models.dart` registering skeleton defaults on the
`mockModelId` sentinel — are there to catch an over-eager rule.

```bash
cd example && dart run custom_lint   # fails on a missed or an unexpected lint
```

It runs the real analyzer, which is the point: this rule's one historical bug
was a visitor registered for the wrong AST node (`context.textTheme` is a
`PrefixedIdentifier`, not a `PropertyAccess`), so it matched nothing while every
unit test of its logic would still have passed.

## Setup

```yaml
# pubspec.yaml
dev_dependencies:
  custom_lint: ^0.8.0
  dartway_lints: ^0.3.0
```

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
```

Then run `dart run custom_lint` (or rely on the IDE integration).

Complements the `dartway check` command of
[`dartway_cli`](https://pub.dev/packages/dartway_cli), which validates the
broader project structure. Part of the
[DartWay monorepo](https://github.com/dartway/dartway).
