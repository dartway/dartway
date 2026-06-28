import 'package:flutter/foundation.dart';

import 'dartway_example_app.dart';

void main() {
  // Concrete development parameters live here; the app itself stays environment
  // agnostic. Android devices/emulators reach the dev host via its LAN IP,
  // every other platform (web, desktop, iOS sim) talks to localhost.
  //
  // `defaultTargetPlatform` works on every platform — unlike `dart:io`'s
  // `Platform`, which does not compile for Flutter web.
  final backendUrl =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://192.168.0.100:8080/'
      : 'http://localhost:8080/';

  DartwayExampleApp(backendUrl: backendUrl, appVersion: 'local').run();
}
