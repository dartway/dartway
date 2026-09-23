---
title: dartway_lints is an analyzer plugin, enabled in analysis_options.yaml
affects:
  dartway_lints: "0.4.0"
---

## Who is affected

Every project: its Flutter package runs `dartway_lints` through `custom_lint`, and on Flutter 3.47
(Dart 3.13) `custom_lint` crashes inside the analysis server — the rules stop showing in the IDE
while `dart run custom_lint` still passes. From 0.4.0 the rules are an analyzer plugin.

## What to change

`<project>_flutter/pubspec.yaml` — the plugin is not a dependency any more:

    dev_dependencies:
    -  custom_lint: ^0.8.0
    -  dartway_lints: ^0.3.1

`<project>_flutter/analysis_options.yaml` — drop the legacy entry, add the plugin as a top-level
section:

    analyzer:
    -  plugins:
    -    - custom_lint

    + plugins:
    +   dartway_lints: ^0.4.0

Then `flutter pub get`, and restart the analysis server (in the IDE: "Restart Analysis Server").

Wherever a script or CI runs `dart run custom_lint`, run `dart analyze --fatal-infos` in the Flutter
package instead. `flutter analyze` does not run analyzer plugins, so it reports a clean build over a
plugin warning. A `// ignore: forbidden_ui_style_usage` becomes
`// ignore: dartway_lints/forbidden_ui_style_usage`.

## How to check

A raw `Color(0xFF000000)` in a file outside `lib/ui_kit/` is underlined in the IDE, and
`dart analyze` in the Flutter package reports it as `forbidden_ui_style_usage`.
