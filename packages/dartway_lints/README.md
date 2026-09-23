# dartway_lints

Lint rules enforcing [DartWay](https://dartway.dev) conventions, as an
analyzer plugin.

## Setup

Enable the plugin in the Flutter package's `analysis_options.yaml` — a
top-level section, not under `analyzer:`:

```yaml
plugins:
  dartway_lints: ^0.4.0
```

That is all: the analysis server fetches and runs the plugin itself, so the
package is not a dependency of the project. Restart the analysis server after
changing the section. The rules show in the IDE and in `dart analyze`;
`flutter analyze` does not run analyzer plugins, so a CI step runs
`dart analyze --fatal-infos`, which fails where `flutter analyze` does and on
these rules too. Suppress one with `// ignore: dartway_lints/<rule>`.

Projects created by `dartway create` have it enabled already. Requires Dart 3.12
(Flutter 3.44) or newer.

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

