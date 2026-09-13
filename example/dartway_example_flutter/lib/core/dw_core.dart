import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_shared_preferences/dartway_shared_preferences.dart';
import 'package:flutter/foundation.dart';

import 'app_l10n.dart';
import 'refusal_text.dart';

/// The app's DartWay core: `dw.request`, `dw.pages`, `dw.command`,
/// `dw.action`, `dw.notify` — reachable from anywhere in the app.
///
/// Assigned by [createExampleDwCore]: once by the app bootstrap, and once per
/// test by a widget test, which disposes it in `tearDown`. It is not `final`
/// for exactly that reason — the core holds no static state, so a test builds
/// a fresh one against its own fake server rather than sharing the app's.
late DwCore dw;

/// Builds the core and makes it [dw]. Nothing connects until `dw.init()`.
///
/// The app passes [endpoint] and keeps the session through the
/// shared-preferences plugin. A widget test passes the fake server's
/// [connector], an in-memory [tokenStore] and short [clientOptions] instead —
/// and with a token store of its own the core needs no storage plugin at all.
DwCore createExampleDwCore({
  required Uri endpoint,
  String appVersion = 'local',
  DwConnector? connector,
  DwTokenStore? tokenStore,
  DwClientOptions clientOptions = const DwClientOptions(),
}) => dw = DwCore(
  config: DwConfig(
    appVersion: appVersion,
    refusalText: (refusal) => refusalText(appL10n, refusal),
    onErrorReport: _onErrorReport,
  ),
  protocol: dartwayExampleProtocol,
  endpoint: endpoint,
  connector: connector,
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
void _onErrorReport(DwErrorReport report) {
  if (report.error case DwRefusalException() || DwNotAuthenticatedException()) {
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
