import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:project_name_client/project_name_client.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

class AppCore {
  // static late SharedPreferences _prefs;
  static late final Client _client;

  static ServerpodClientShared initServerpodClient(String backendUrl) {
    _client = Client(
      backendUrl,
      authenticationKeyManager: FlutterAuthenticationKeyManager(),
    )..connectivityMonitor = FlutterConnectivityMonitor();

    return _client;
  }

  static Client get serverpodClient => _client;
}
