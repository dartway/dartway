import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_shared_preferences/dartway_shared_preferences.dart';
import 'package:dartway_starter_client/dartway_starter_client.dart';
import 'package:flutter/foundation.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

import 'app_l10n.dart';

/// Runtime error reports sink. Pass a [DwTelegramAlertsConfig] to send them to
/// Telegram; without one they degrade to logging, which is fine for a fresh
/// project.
final dwAlerts = DwAlerts.init();

/// App version label shown by [AppScaffold]. Assigned from the development
/// parameters passed in `main` via [DartwayStarterApp]; no generated build file.
String exampleAppVersion = 'local';

/// Application-level DartWay core, typed with this project's Serverpod [Client]
/// and [UserProfile] model. Exposes `dw.notify`, `dw.sessionProvider`,
/// `dw.client`, etc. across the app. Built once by [initExampleDwCore] so the
/// backend URL can be supplied as a runtime development parameter.
late final DwCore<Client, UserProfile> dw;

bool _coreInitialized = false;

/// Builds the global [dw] core using the development [backendUrl]. Called from
/// `DartwayStarterApp.run` before any widget reads `dw`.
///
/// Calling it again does nothing, and that is what makes it usable from a
/// widget test's `setUpAll`. Tests need it more often than it looks: anything
/// reached through `dw.` — `dw.userProfileProvider` among them — needs the core
/// to exist merely to be *named*, so a test that pumps a subtree touching the
/// router needs a booted core even when it knows nothing about the session.
/// Without the guard, the second test file in a run would meet a
/// `LateInitializationError` on an already-initialized field.
///
/// The app passes [backendUrl]; a widget test passes [transport] instead and no
/// Serverpod client is built at all. That is not an optimisation: a client
/// brings a connectivity monitor and an auth key manager with it, both of which
/// reach for platform channels a widget test has no business answering. Without
/// a key manager there is no session either, so a test that needs a signed-in
/// profile overrides `dw.requireUserProfileProvider` in its own `ProviderScope`.
void initExampleDwCore({String? backendUrl, DwServerTransport? transport}) {
  if (_coreInitialized) return;
  _coreInitialized = true;

  dw = DwCore<Client, UserProfile>(
    // The session's key lives here. The core asks the plugins for whoever
    // claimed the DwKeyValueStorePlugin role rather than reaching for a
    // storage package of its own — see DwSharedPreferences.
    plugins: [DwSharedPreferences()],
    config: DwConfig(
      defaultModelGetter: dwGetDefault,
      // Shown in error reports next to the platform and user.
      appVersion: exampleAppVersion,
    ),
    client: backendUrl == null ? null : _buildClient(backendUrl),
    transport: transport,
    // No telegram config here: locally the alerts degrade to logging. To see
    // the full formatted alert in the console use
    // `DwAlerts.init(logErrors: true, logFunction: debugPrint)`.
    dwAlerts: dwAlerts,
    getUserId: (userProfile) => userProfile?.id,
    onSocketStatusChanged: (status) =>
        debugPrint('[app] realtime status → $status'),
  );
}

Client _buildClient(String backendUrl) =>
    Client(
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
      ..authKeyProvider = DwAuthenticationKeyManager();
