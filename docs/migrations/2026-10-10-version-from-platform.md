---
title: Read the app version from the platform build
affects:
  dartway_cli: "0.25.0"
---

## Who is affected

Projects whose Flutter entrypoint passes a committed `appBuildVersion` constant.
Apply this change on the next template sync. An empty platform build number maps
to build `0`. In the template, an empty version or a failed platform read is
reported with its stack trace via `debugPrint` before using `0.0.0+0` so startup
continues. The read precedes the app's uncaught-error pipeline; these fallbacks
are template behaviour.

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
   builds that do not use the deployment Dockerfile. Pass `--build-number=N` in
   release builds and use `--build-name` only when overriding the marketing
   version. Kamal uses the GitHub Actions run number; `dartway deploy run` uses
   the deployment's UTC epoch second. Do not commit release build-number bumps.

On web, `PackageInfo` reads the `version.json` that `flutter build web` writes.
The web Dockerfile defaults its build argument to `0` only for a direct local
Docker build. Both supported deployment paths override it, so deployed web
images have distinguishable version labels. `Dw-App-Version` labels sessions
and decides nothing about compatibility.

## How to check

Test `appVersionOf` with a supplied build number and an empty one (`+0`), and
with an empty version (`0.0.0+0`). Test that `readAppVersion` returns `0.0.0+0`
when reading the platform version throws, and that both fallbacks report the
problem and its stack trace before continuing.
Run `flutter test`, then build and run web and a mobile simulator build with
`--build-number=521`. `AppVersionLabel` should show the marketing version followed
by `+521`, while `pubspec.yaml` remains unchanged.
