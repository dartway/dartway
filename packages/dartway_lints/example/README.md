# Example — the UI kit is the single source of styles

Enable the plugin in your app's `analysis_options.yaml`:

```yaml
plugins:
  dartway_lints: ^0.4.0
```

Then look at your IDE, or run `dart analyze`.

## What it catches

Outside `lib/ui_kit/`, a raw style is a warning — because the moment one screen picks its own colour,
the kit stops being the source of truth and the design system starts to rot:

```dart
// lib/app/profile/profile_page.dart

Container(
  color: Color(0xFF00695C),          // ⚠️ raw Color outside ui_kit
  child: Text(
    'Profile',
    style: TextStyle(fontSize: 18),  // ⚠️ raw TextStyle outside ui_kit
  ),
)

final radius = BorderRadius.circular(12);      // ⚠️ raw BorderRadius
final primary = Theme.of(context).primaryColor; // ⚠️ direct theme access
```

Write this instead — the kit is yours, it lives in your app as source:

```dart
AppCard(
  child: AppText.title('Profile'),
)
```

## What it does not catch

Inside `lib/ui_kit/` everything above is allowed: that is where styles are *supposed* to be
declared. Generated files are exempt too.

The rule is not about aesthetics. A design system only survives if there is exactly one place that
decides what a title looks like — and a machine, not a reviewer, is what keeps it that way.

## This folder

The files here are the fixture the plugin is proved on: every diagnostic they must produce is marked
`// expect_lint: <rule>` on the line above, and `test/example_test.dart` in the plugin package runs
`dart analyze` here and requires exactly those.
