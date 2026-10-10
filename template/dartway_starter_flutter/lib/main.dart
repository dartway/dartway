import 'package:dartway_starter_flutter/core/app_version.dart';
import 'package:dartway_starter_flutter/dartway_starter_app.dart';
import 'package:flutter/foundation.dart';

void main() {
  // Concrete development parameters live here; the app itself stays
  // environment agnostic.
  //
  // Without a define, a web release calls its own origin. Kamal routes /dw, /health and
  // project HTTP routes to the API; the same web image serves every environment.
  // Native releases keep the address supplied by --dart-define.
  const deployedBackendUrl = String.fromEnvironment('DW_BACKEND_URL');

  // Empty on a local run, where the machine decides instead: the Android
  // emulator reaches the development host at 10.0.2.2, every other platform
  // (web, desktop, iOS simulator) at localhost.
  //
  // `defaultTargetPlatform` works on every platform — unlike `dart:io`'s
  // `Platform`, which does not compile for Flutter web.
  final backendUrl = deployedBackendUrl.isNotEmpty
      ? deployedBackendUrl
      : kIsWeb && kReleaseMode
      ? Uri.base.origin
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8080'
      : 'http://localhost:8080';

  DartwayStarterApp(
    baseUrl: Uri.parse(backendUrl),
    appVersion: appBuildVersion,
  ).run();
}
