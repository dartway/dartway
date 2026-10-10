---
title: Read the app version from the platform build
affects:
  dartway_cli: "0.24.0"
---

## Who is affected

Projects whose Flutter entrypoint passes a committed `appBuildVersion` constant.
Apply this change on the next template sync. An empty platform build number maps
to build `0`. In the template, an empty version or a failed platform read is
reported with its stack trace via `debugPrint` before using `0.0.0+0` so startup
continues. The read precedes the app's uncaught-error pipeline; these fallbacks
are template behaviour. `DwAppVersion.parse` remains strict (`<semver>+<build>`).

## What to change

1. Add `package_info_plus: ^9.0.1` to the Flutter package's dependencies and run
   `flutter pub get`.
2. Delete `lib/core/app_version.dart` and `test/core/app_version_test.dart`, and
   remove their imports. The widget harness in `test/support/app_test_app.dart`
   passes a literal such as `'0.0.0+0'` to `AppDwCore.create`.
3. Make `main` asynchronous and read the platform version before running the app:

   ```dart
   import 'package:flutter/foundation.dart';
   import 'package:flutter/widgets.dart';
   import 'package:package_info_plus/package_info_plus.dart';

   Future<void> main() async {
     WidgetsFlutterBinding.ensureInitialized();
     final appVersion = await readAppVersion();
     // Pass appVersion to the application's existing app constructor and run it.
   }

   Future<String> readAppVersion() async {
     final PackageInfo info;
     try {
       info = await PackageInfo.fromPlatform();
     } catch (error, stackTrace) {
       // The app's uncaught-error pipeline is installed after this read.
       debugPrint('Could not read app version: $error\n$stackTrace');
       return '0.0.0+0';
     }
     return appVersionOf(info);
   }

   String appVersionOf(PackageInfo info) {
     if (info.version.isEmpty) {
       debugPrint('Platform app version is empty.\n${StackTrace.current}');
       return '0.0.0+0';
     }
     return info.buildNumber.isEmpty
         ? '${info.version}+0'
         : '${info.version}+${info.buildNumber}';
   }
   ```

4. Keep the marketing version in `pubspec.yaml`; its `+N` is only a fallback for
   local builds. Pass `--build-number=N` in release builds and use `--build-name`
   only when overriding the marketing version. N will come from Studio's
   per-project counter. Do not commit release build-number bumps.

On web, `PackageInfo` reads the `version.json` that `flutter build web` writes.
The web Dockerfile and deploy flow are unchanged; until the release counter is
wired, that web build uses pubspec's fallback build number. `Dw-App-Version` labels sessions
and decides nothing about compatibility.

## How to check

Test `appVersionOf` with a supplied build number and an empty one (`+0`), and
with an empty version (`0.0.0+0`). Test that `readAppVersion` returns `0.0.0+0`
when reading the platform version throws, and that both fallbacks report the
problem and its stack trace before continuing.
Run `flutter test`, then build and run web and a mobile simulator build with
`--build-number=521`. `AppVersionLabel` should show the marketing version followed
by `+521`, while `pubspec.yaml` remains unchanged.
