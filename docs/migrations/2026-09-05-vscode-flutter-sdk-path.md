---
title: "The VS Code Flutter SDK path in your project points at a Windows path with a version in it"
affects:
  dartway_cli: "0.10.0"
---

## Who is affected

Every project created by `dartway create` before 2026-09-05. The file is in your repository, so
fixing the skeleton does not reach you — this is the only thing that does.

Open `<project>_flutter/.vscode/settings.json` and look:

```json
{ "dart.flutterSdkPath": ".fvm\\versions\\3.44.0" }
```

Two things are wrong with that one line.

**It is a Windows path.** On macOS and Linux there is no directory named `.fvm\versions\3.44.0` —
the separator is part of the file name. The Dart extension does not complain about a path it
cannot resolve; it quietly falls back to whatever Flutter is on your `PATH`, which is precisely the
SDK fvm exists to stop you from using. Your editor then analyses against one SDK while your builds
use another, and nothing anywhere says so.

**The version is baked in.** `.fvmrc` is the file that names the SDK. This is a second copy of that
number in a file nothing regenerates, so it goes stale the moment `.fvmrc` moves — and stale in the
way that produces a "works on my machine".

## What to change

```json
{ "dart.flutterSdkPath": ".fvm/flutter_sdk" }
```

`.fvm/flutter_sdk` is the symlink fvm maintains for exactly this: no separator problem, no version
to keep in step. fvm itself warns about the other form — *"SDK Path points to project directory,
but does not use the flutter_sdk symlink. Using `fvm use` will break the project."*

If the project has several Flutter packages, each has its own `.vscode/settings.json`.

## How to check

Reload the window and open any Dart file. The status bar names the SDK the analyzer is using: it
should be the version in `.fvmrc`, not the one from `PATH`. `.fvm/flutter_sdk` appears after
`fvm use` has run in that package at least once — the directory is git-ignored, which is why the
setting can be committed while the link is local.
