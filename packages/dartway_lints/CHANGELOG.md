# Changelog

## 0.2.0

`forbidden_provider_scope`: writing a `ProviderScope` in application code is a warning. The only one
belongs to `DwAppRunner`, which wraps the whole app; tests build their own and are left alone.

The rule exists because the mistake it catches does not look like one. A nested scope with
`overrides:` genuinely works for widgets — a `WidgetRef` resolves from the nearest scope above its
widget. A provider reading the same provider through its own `Ref` resolves from the container
hosting *it*, which for anything declaring no `dependencies` is the root, so it quietly gets the base
value. Nothing throws and nothing warns; the screen shows a different value than the one that was
overridden.

`riverpod_lint` has a rule for this case and it cannot help here: it skips every provider it cannot
statically prove scoped, which it can only do for generated ones. DartWay writes providers by hand.

The replacement is not a workaround — a value that must differ per subtree is a family key or a
constructor argument, which puts the difference in the call instead of in the widget tree above it.

## 0.1.1

`deep_relative_import`: a relative import that walks more than two levels up is a warning. One or two
`../` read as "the feature next door" — the shape the rule keeps legal, and the reason this is not
`always_use_package_imports`, which forbids the neighbour too. Past two steps the path stops naming
anything: `'../../../../ui_kit/ui_kit.dart'` says neither what is imported nor from where, while
`package:my_app/ui_kit/ui_kit.dart` says both.

The limit is also a structure signal. If a *sibling* feature is suddenly four levels away it is not a
sibling: either the group fell apart, or what is being imported belongs in `shared/` or `domain/`.

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
