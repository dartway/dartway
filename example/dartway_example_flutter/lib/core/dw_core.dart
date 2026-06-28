import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:flutter/foundation.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

import '../build_info.dart';

/// Telegram/email/etc. alerts sink. Configure with a [DwTelegramAlertsConfig]
/// when you want runtime error reports; the default no-op is fine for a fresh
/// project.
final dwAlerts = DwAlerts.init();

/// Application-level DartWay core, typed with this project's Serverpod [Client]
/// and [UserProfile] model. Exposes `dw.notify`, `dw.sessionProvider`,
/// `dw.client`, etc. across the app.
final DwCore<Client, UserProfile> dw = DwCore<Client, UserProfile>(
  config: const DwConfig(
    defaultModelGetter: DwRepository.getDefault,
  ),
  client: Client(BuildInfo.backendUrl)
    ..connectivityMonitor = FlutterConnectivityMonitor()
    ..authKeyProvider = DwAuthenticationKeyManager(),
  dwAlerts: dwAlerts,
  getUserId: (userProfile) => userProfile?.id,
  onStreamingStatusChanged: (status) =>
      debugPrint('[example] streaming status → $status'),
);
