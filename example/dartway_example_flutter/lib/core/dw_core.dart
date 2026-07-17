import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:flutter/foundation.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

import 'app_l10n.dart';

/// Runtime error reports sink. Pass a [DwTelegramAlertsConfig] to send them to
/// Telegram; without one they degrade to logging, which is fine for a fresh
/// project.
final dwAlerts = DwAlerts.init();

/// App version label shown by [AppScaffold]. Assigned from the development
/// parameters passed in `main` via [DartwayExampleApp]; no generated build file.
String exampleAppVersion = 'local';

/// Application-level DartWay core, typed with this project's Serverpod [Client]
/// and [UserProfile] model. Exposes `dw.notify`, `dw.sessionProvider`,
/// `dw.client`, etc. across the app. Built once by [initExampleDwCore] so the
/// backend URL can be supplied as a runtime development parameter.
late final DwCore<Client, UserProfile> dw;

/// Builds the global [dw] core using the development [backendUrl]. Called once
/// from `DartwayExampleApp.run` before any widget reads `dw`.
void initExampleDwCore({required String backendUrl}) {
  dw = DwCore<Client, UserProfile>(
    config: DwConfig(
      defaultModelGetter: DwRepository.getDefault,
      // Shown in error reports next to the platform and user.
      appVersion: exampleAppVersion,
    ),
    client: Client(
      backendUrl,
      // Connection-level failures (timeout/offline) → a toast, not an alert;
      // everything else enters the dw error pipeline with `endpoint.method`
      // attached and is alerted out of the box with the app context.
      onFailedCall: dwReportingOnFailedCall(
        onConnectionError: (_, _) =>
            dw.notify.error(appL10n.networkErrorTryAgain),
      ),
    )
      ..connectivityMonitor = FlutterConnectivityMonitor()
      ..authKeyProvider = DwAuthenticationKeyManager(),
    // No telegram config here: locally the alerts degrade to logging. To see
    // the full formatted alert in the console use
    // `DwAlerts.init(logErrors: true, logFunction: debugPrint)`.
    dwAlerts: dwAlerts,
    getUserId: (userProfile) => userProfile?.id,
    onStreamingStatusChanged: (status) =>
        debugPrint('[example] streaming status → $status'),
  );
}
