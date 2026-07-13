# Changelog

## 0.1.0

- First public release: `forbidden_ui_style_usage` — outside `ui_kit/`, flags
  raw `Color`, `TextStyle` and `BorderRadius` constructions, `Colors.*`,
  `Theme.of(context)`, and the kit's theme shortcuts (`context.theme`,
  `context.textTheme`, `context.colorScheme`). Generated files are left alone.
- The theme-access half of the rule never fired before this release: it listened
  for a `PropertyAccess`, while `context.textTheme` — a property read off a
  simple identifier — is a `PrefixedIdentifier`. The branch was dead code, so
  the one convention the package exists to enforce was, in practice,
  unenforced. Targets are now matched by *type* rather than by spelling, which
  also catches a `BuildContext` named anything else.
- `colorTheme` is gone from the checked names: no such getter exists, it was a
  typo checking for nothing.
- `example/` is now the test suite: `dart run custom_lint` there fails on a
  missed lint (`// expect_lint:` above every line that must be reported) and on
  an unexpected one (the `ui_kit/` file writes the same styles freely and must
  stay silent). It runs the real analyzer — the bug above would have survived
  any unit test of the rule's logic, because the logic was never reached.
