# Changelog

## 0.3.1

`model_rebuild_by_constructor` no longer reports a skeleton default. A construction whose `id:` is
`dw.repo.mockModelId` — the sentinel `setupRepository(defaultModel:)` instances carry — is out of the
rule's scope: a stored row is a model with a real id, and a skeleton default is not a row. There is
nothing there to rebuild with `copyWith`, because there is no row to copy from; the instance is
invented from nothing to give a loading skeleton its shape.

The bug was not noise in one project's file. `setupRepository(defaultModel:)` is the framework's own
API and every project registers one default per model, so the rule produced exactly as many warnings
as an app has models — 17 in one of them — in the one file where it had nothing to say. The framework
shipped its own template with an `// ignore_for_file:` on top of that file, which is the shape of the
problem rather than a fix: a rule guaranteed to be loud where it must be silent teaches people to
scroll past its output. Both `example/` and `template/` have dropped the ignore.

The exemption is keyed on the sentinel's value, not on the `defaultModel:` argument position. The
value travels — through a helper that builds the instance, through defaults registered in a loop —
while the argument position only covers the call written inline; and a *real* id handed to
`setupRepository` pins a stored row as a skeleton, which is worth a warning rather than an exemption.
The sentinel is matched by name, for the reason `forbidden_provider_scope` matches `ProviderScope` by
name: an unresolved reference must not make the rule fire, since firing is the failure being fixed.

The rule's message now names the reason it fired, so the exemption is visible from the warning: *a
stored row is a model with a real id.*

## 0.3.0

`model_rebuild_by_constructor`: a Serverpod model constructor called with a non-null `id:` is a
warning. A row being created never passes an id — it comes back from the database — so the call is
rebuilding a row that already exists, and rebuilding is what `copyWith` is for.

The rule exists because the bug it catches is invisible by construction. Serverpod makes a field with
`default=`, and any nullable field, an *optional* argument. A method that rebuilds a model by naming
its fields therefore keeps compiling when a field is added to the model, and silently substitutes the
default for it. One project reset a `priority` field to `medium` on every single edit of the record
it belonged to — the agent's draft, the manual correction, the approval — and the discrepancy
surfaced in an audit rather than in a test. The method carried an honest doc comment asking for the
opposite; the field was added by another task that never opened that file, which is what a rule
living in a comment at the far end of the system is worth.

The ban takes nothing away. The one reason to rebuild by hand — "`copyWith` reads null as *not
passed*, and I need to clear a nullable field" — is not true of the generated one: it takes
`Object? field = _Undefined` and tests `field is T? ? field : this.field`, so passing `null` clears
the field and omitting it keeps the value.

Matched through `SerializableModel` rather than through `TableRow`: on the server a generated model
implements both, but the client half implements only the former — and the client half is what an
application is written against, in the one package where these lints are configured to run. Serverpod's
own output (`lib/src/protocol/`, `lib/src/generated/`) is skipped, as is `// ignore`d code: the
framework's skeleton mocks in `core/default_models.dart` are invented from nothing with a synthetic
id, which is the one hand-built instance a DartWay app legitimately has.

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
