import 'package:dartway_push_firebase/dartway_push_firebase.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_version.dart';
import 'dartway_example_app.dart';

Future<void> main() async {
  // Firebase, when the build names a project: `--dart-define=FIREBASE_API_KEY=…`
  // with `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID` and
  // `FIREBASE_PROJECT_ID` (and the web push key, `FIREBASE_WEB_VAPID_KEY`). The
  // example ships no Firebase project, so by default push is inert.
  Future<bool> firebaseConfigured() async {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    if (apiKey.isEmpty) return false;
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: apiKey,
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
        messagingSenderId: String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
        ),
        projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
      ),
    );
    DwFirebasePush.registerBackgroundHandler();
    return true;
  }

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
    pushTransports: [
      if (await firebaseConfigured())
        DwFirebasePush(
          webVapidKey: const String.fromEnvironment('FIREBASE_WEB_VAPID_KEY'),
        ),
    ],
  ).run();
}
