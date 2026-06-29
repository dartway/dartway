import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:flutter/foundation.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

/// Telegram/email/etc. alerts sink. Configure with a [DwTelegramAlertsConfig]
/// when you want runtime error reports; the default no-op is fine for a fresh
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
    config: const DwConfig(
      defaultModelGetter: DwRepository.getDefault,
    ),
    client: Client(
      backendUrl,
      // Connection-level failures (timeout/offline) → a toast, not an alert;
      // everything else → the app's report sink. Built from the framework's
      // helper, so no classifier duplication.
      onFailedCall: dwConnectionAwareOnFailedCall(
        onConnectionError: (_, _) =>
            dw.notify.error('Ошибка сети. Попробуйте снова.'),
        onUnexpectedError: (ctx, error, _) =>
            debugPrint('[FAILED] ${ctx.endpointName}.${ctx.methodName}: $error'),
      ),
    )
      ..connectivityMonitor = FlutterConnectivityMonitor()
      ..authKeyProvider = DwAuthenticationKeyManager(),
    dwAlerts: dwAlerts,
    getUserId: (userProfile) => userProfile?.id,
    onStreamingStatusChanged: (status) =>
        debugPrint('[example] streaming status → $status'),
  );
}
