# dartway_lints

Custom lint rules enforcing [DartWay](https://dartway.dev) conventions.

## Rules

- **forbidden_ui_style_usage** (warning) — the UI kit is the single source of
  styles: raw `Color(...)`, `TextStyle(...)`, `BorderRadius(...)`,
  `Colors.*` and `context.textTheme` / `context.colorScheme` access are
  flagged everywhere outside `ui_kit/`. Feature code composes UI-kit widgets
  and presets instead.

## Setup

```yaml
# pubspec.yaml
dev_dependencies:
  custom_lint: ^0.8.0
  dartway_lints: ^0.1.0
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
