---
title: Read the app version from the platform build
affects:
  dartway_cli: "0.24.0"
  dartway_core_shared: "0.21.0-dev.17"
---

## Who is affected

Projects whose Flutter entrypoint passes a committed `appBuildVersion` constant.
Apply this change on the next template sync. Code that reads `DwAppVersion.build`
must also allow `null`, meaning the platform supplied no build number; do not
invent a build number for the session label.

## What to change

1. Add `package_info_plus: ^9.0.1` to the Flutter package's dependencies and run
   `flutter pub get`.
2. Delete `lib/core/app_version.dart` and `test/core/app_version_test.dart`, and
   remove their imports. The widget harness in `test/support/app_test_app.dart`
   passes a literal such as `'0.0.0+0'` to `AppDwCore.create`.
3. Make `main` asynchronous and read the platform version before running the app:

   ```dart
   import 'package:flutter/widgets.dart';
   import 'package:package_info_plus/package_info_plus.dart';

   Future<void> main() async {
     WidgetsFlutterBinding.ensureInitialized();
     final info = await PackageInfo.fromPlatform();
     final appVersion = info.buildNumber.isEmpty
         ? info.version
         : '${info.version}+${info.buildNumber}';
     // Pass appVersion to the application's existing app constructor and run it.
   }
   ```

4. Keep the marketing version in `pubspec.yaml`; its `+N` is only a fallback for
   local builds. Pass `--build-number=N` in release builds and use `--build-name`
   only when overriding the marketing version. Studio's per-project counter will
   supply N (STD-E21). Do not commit release build-number bumps.

On web, `PackageInfo` reads the `version.json` that `flutter build web` writes.
The web Dockerfile and deploy flow are unchanged; until STD-E21 is wired, that
web build uses pubspec's fallback build number. `Dw-App-Version` labels sessions
and decides nothing about compatibility.

## How to check

Run `flutter test`, then build and run web and a mobile simulator build with
`--build-number=521`. `AppVersionLabel` should show the marketing version followed
by `+521`, while `pubspec.yaml` remains unchanged.
