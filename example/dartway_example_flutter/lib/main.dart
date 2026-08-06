import 'package:flutter/foundation.dart';

import 'dartway_example_app.dart';

void main() {
  // Concrete development parameters live here; the app itself stays environment
  // agnostic.
  //
  // A deployed build is compiled against a fixed API address, and the address
  // is supplied by `dartway deploy`, which reads it from the Serverpod
  // configuration — the one place a domain is written down. Nothing to add
  // here when a project gets deployed, and no second copy to keep in step.
  const deployedBackendUrl = String.fromEnvironment('DW_BACKEND_URL');

  // Empty on a local run, where the machine decides instead: Android
  // devices/emulators reach the dev host via its LAN IP, every other platform
  // (web, desktop, iOS sim) talks to localhost.
  //
  // `defaultTargetPlatform` works on every platform — unlike `dart:io`'s
  // `Platform`, which does not compile for Flutter web.
  final backendUrl = deployedBackendUrl.isNotEmpty
      ? deployedBackendUrl
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://192.168.0.100:8080/'
      : 'http://localhost:8080/';

  DartwayExampleApp(backendUrl: backendUrl, appVersion: 'local').run();
}
