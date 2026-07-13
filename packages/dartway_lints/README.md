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

## Testing

`example/` is the rule's test suite: files under `lib/app/` carry
`// expect_lint: forbidden_ui_style_usage` above every line that must be
reported, and `lib/ui_kit/` writes the same styles freely and must stay silent.

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
