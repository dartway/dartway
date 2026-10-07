import 'package:dartway_analytics_flutter/dartway_analytics_flutter.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/refusal_text.dart';
import 'package:dartway_example_flutter/core/update_required_page.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_media_flutter/dartway_media_flutter.dart';
import 'package:dartway_push_flutter/dartway_push_flutter.dart';
import 'package:dartway_shared_preferences/dartway_shared_preferences.dart';
import 'package:flutter/widgets.dart';

/// The app's DartWay core: `dw.request`, `dw.table`, `dw.window`,
/// `dw.command`, `dw.action`, `dw.notify` — reachable from anywhere in the app.
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
  /// [httpTransport] and [liveConnector], an in-memory [tokenStore] and short
  /// [clientOptions] instead — and with a token store of its own the core needs
  /// no storage plugin at all.
  ///
  /// [pushTransports] deliver notifications — FCM when Firebase is configured;
  /// a test passes a fake one. With none, push is inert. A test passes an
  /// in-memory [analyticsStore] too, where the recorded events wait.
  ///
  /// [onErrorReport] observes reports after the app's normal error policy has
  /// run; the widget-test harness uses this existing hook to assert reports.
  static DwFlutterCore create({
    required Uri baseUrl,
    required String appVersion,
    DwHttpTransport? httpTransport,
    DwLiveConnector? liveConnector,
    DwTokenStore? tokenStore,
    DwClientOptions clientOptions = const DwClientOptions(),
    List<DwPushTransportClient> pushTransports = const [],
    DwAnalyticsStore? analyticsStore,
    void Function(DwErrorReport report)? onErrorReport,
  }) => dw = DwFlutterCore(
    config: DwFlutterConfig(
      appVersion: appVersion,
      refusalText: (refusal) => appL10n.refusalText(refusal),
      updateRequiredScreen: (context, refusal) =>
          UpdateRequiredPage(refusal: refusal),
      onErrorReport: (report) {
        _onErrorReport(report);
        onErrorReport?.call(report);
      },
      readLoadingBuilder: (context) =>
          const Center(child: AppProgressIndicator()),
      readFailedBuilder: (context, error, retry) => LoadFailedMessage(
        message: switch (error) {
          DwRefusalException(:final refusal) => appL10n.refusalText(refusal),
          _ => appL10n.loadFailed,
        },
        retryLabel: appL10n.retry,
        onRetry: dw.action((_) => retry()),
      ),
    ),
    protocol: appProtocol,
    baseUrl: baseUrl,
    httpTransport: httpTransport,
    liveConnector: liveConnector,
    tokenStore: tokenStore,
    clientOptions: clientOptions,
    plugins: [
      if (tokenStore == null) DwSharedPreferences(),
      DwPush(transports: pushTransports),
      // Opening, resuming and signing in are recorded from the first build.
      DwAnalytics(store: analyticsStore),
      // Workout videos: speeds on, the next workout previewed and started
      // after a countdown; everything else is the package's default.
      DwMedia(
        config: const DwMediaConfig(
          speeds: [1, 1.25, 1.5, 2],
          autoplayNext: true,
          nextPreview: true,
        ),
      ),
    ],
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
