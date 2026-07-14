# Changelog

## 0.1.0

First public release — the DartWay conventions, enforced by machine.

`forbidden_ui_style_usage`: outside `ui_kit/`, a raw style is a warning — raw `Color`, `TextStyle`
and `BorderRadius` constructions, `Colors.*`, `Theme.of(context)` and the kit's theme shortcuts
(`context.theme`, `context.textTheme`, `context.colorScheme`). Inside `ui_kit/` all of it is
allowed: that is where styles are supposed to be declared. Generated files are left alone.

The rule is not about aesthetics. A design system survives only if exactly one place decides what a
title looks like — and a machine, not a reviewer, is what keeps it that way. It matters more with an
AI agent in the loop: an agent that can paint its own colours produces code that reviews clean and
looks wrong.

Targets are matched by *type*, not by spelling, so a `BuildContext` named anything at all is still
caught.

`example/` is the test suite: `dart run custom_lint` there fails both on a missed lint
(`// expect_lint:` sits above every line that must be reported) and on an unexpected one — the
`ui_kit/` file writes the same styles freely and must stay silent. It runs the real analyzer, which
is the only way to test a lint that a unit test of its logic would happily let through.
