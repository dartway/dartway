import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:dartway_shared_preferences/dartway_shared_preferences.dart';
import 'package:flutter/foundation.dart';

import 'app_l10n.dart';
import 'refusal_text.dart';
import 'update_required_page.dart';

/// The app's DartWay core: `dw.request`, `dw.table`, `dw.window`,
/// `dw.command`, `dw.uploader`, `dw.action`, `dw.notify` — reachable from
/// anywhere in the app.
///
/// Assigned by [AppDwCore.create]: once by the app bootstrap, and once per
/// test by a widget test, which disposes it in `tearDown`. It is not `final`
/// for exactly that reason — the core holds no static state, so a test builds
/// a fresh one against its own fake server rather than sharing the app's.
late DwFlutterCore dw;

/// Building the app's core.
abstract final class AppDwCore {
  /// Builds the core and makes it [dw]. Nothing connects until `dw.init()`.
  ///
  /// The app passes [baseUrl] and keeps the session through the
  /// shared-preferences plugin. A widget test passes the fake server's
  /// [httpTransport] and [liveConnector] (and a fake storage's
  /// [storageTransport]), an in-memory [tokenStore] and short
  /// [clientOptions] instead — and with a token store of its own the core needs
  /// no storage plugin at all.
  static DwFlutterCore create({
    required Uri baseUrl,
    required String appVersion,
    DwHttpTransport? httpTransport,
    DwLiveConnector? liveConnector,
    DwStorageTransport? storageTransport,
    DwTokenStore? tokenStore,
    DwClientOptions clientOptions = const DwClientOptions(),
  }) => dw = DwFlutterCore(
    config: DwFlutterConfig(
      appVersion: appVersion,
      refusalText: (refusal) => appL10n.refusalText(refusal),
      updateRequiredScreen: (context, refusal) =>
          UpdateRequiredPage(refusal: refusal),
      onErrorReport: _onErrorReport,
    ),
    protocol: dartwayStarterProtocol,
    baseUrl: baseUrl,
    httpTransport: httpTransport,
    liveConnector: liveConnector,
    storageTransport: storageTransport,
    tokenStore: tokenStore,
    clientOptions: clientOptions,
    plugins: [if (tokenStore == null) DwSharedPreferences()],
  );

  /// What the app does with an error the framework intercepted.
  ///
  /// A refusal is an answer, already rendered through [refusalText] where it
  /// was asked for; a not-authenticated answer ends the session, and the
  /// sign-in screen is the message. Neither is an incident. Everything else is
  /// logged — and when it broke something the user pressed, they are told it
  /// did not work: a command that timed out or failed on the server would
  /// otherwise end in silence.
  static void _onErrorReport(DwErrorReport report) {
    if (report.error
        case DwRefusalException() || DwNotAuthenticatedException()) {
      return;
    }
    if (report.source == DwErrorSource.uiAction) {
      dw.notify.error(appL10n.actionFailed);
    }
    debugPrint(
      '[${report.source.name}] ${report.error} '
      '(route: ${report.context.route}, ${report.context.entries})\n'
      '${report.stackTrace}',
    );
  }
}
