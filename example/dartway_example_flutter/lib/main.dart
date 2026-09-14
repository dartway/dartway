import 'package:flutter/foundation.dart';

import 'app_version.dart';
import 'dartway_example_app.dart';

void main() {
  // Concrete development parameters live here; the app itself stays
  // environment agnostic.
  //
  // A deployed build is compiled against a fixed server address, the origin
  // the app's calls go to: `--dart-define=DW_BACKEND_URL=https://app.example.com`
  // (the web app's own host, where `/dw/` is proxied to the server).
  const deployedBackendUrl = String.fromEnvironment('DW_BACKEND_URL');

  // Empty on a local run, where the machine decides instead: the Android
  // emulator reaches the development host at 10.0.2.2, every other platform
  // (web, desktop, iOS simulator) at localhost.
  //
  // `defaultTargetPlatform` works on every platform — unlike `dart:io`'s
  // `Platform`, which does not compile for Flutter web.
  final backendUrl = deployedBackendUrl.isNotEmpty
      ? deployedBackendUrl
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8080'
      : 'http://localhost:8080';

  DartwayExampleApp(
    baseUrl: Uri.parse(backendUrl),
    appVersion: exampleAppVersion,
  ).run();
}
