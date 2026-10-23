---
title: Read Studio resources through the design link
affects:
  dartway_cli: "0.27.0"
---

## Who is affected

Projects that copy Studio-published resources into their Flutter `assets/`.
Projects without `.dartway/design.json` keep the design checks disabled.

## What to change

Create `.dartway/design.json` at the project root: `{"path":"dw_studio"}`
(`{}` selects the same default). The path is relative to the project root.
Run `dartway check --fix` to create `<project>_flutter/dw_studio -> ../dw_studio`
and add the resources to the template web Dockerfile and `.dockerignore`.
Commit the config, symlink and Docker edits. Custom Dockerfiles need the same
resources copied beside the Flutter package, preserving `<design path>/ui_kit/resources/`.

In `lib/ui_kit/assets/app_icon.dart`, replace copied paths with
`dw_studio/ui_kit/resources/<key>.<ext>` and remove the matching copies from
`assets/`. List `dw_studio/ui_kit/resources/` under `flutter.assets` in the
Flutter pubspec. App-owned assets stay under `assets/` in the same dictionary.
For a nested design path, the link name is its final directory component.

## How to check

Run `dartway check`. `designResourcesInvalid` checks the config, relative link,
pubspec and Docker context; `designResourceCopied` names each identical copy
and its Studio resource key. Both are errors.
