import 'dart:io';

import 'package:flutter/foundation.dart';

import 'dartway_example_app.dart';

void main() {
  // Concrete development parameters live here; the app itself stays environment
  // agnostic. Android devices/emulators reach the dev host via its LAN IP,
  // every other platform talks to localhost.
  final backendUrl = !kIsWeb && Platform.isAndroid
      ? 'http://192.168.0.100:8080/'
      : 'http://localhost:8080/';

  DartwayExampleApp(backendUrl: backendUrl, appVersion: 'local').run();
}
