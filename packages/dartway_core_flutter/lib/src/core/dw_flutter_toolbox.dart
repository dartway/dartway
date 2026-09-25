import 'dart:async';

import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_core_flutter/src/ui/notifications/logic/dw_notifications_controller.dart';
import 'package:dartway_core_flutter/src/private/dw_singleton.dart';
import 'package:flutter/material.dart';

part 'logic/dw_notifications.dart';

class DwFlutterToolbox {
  /// Builds the core and makes it the live one. Nothing runs yet: [init] does
  /// that, and [dispose] ends it.
  DwFlutterToolbox({required this.config, List<DwFlutterPlugin> plugins = const []})
    : plugins = DwPluginRegistry(plugins) {
    attachDwInstance(this);
  }

  /// What the app configured.
  final DwFlutterConfig config;

  DwFlutterConfig get _config => config;

  /// The integrations the app connected, reached as `dw.plugins.<name>` — kept
  /// apart from the core's own services. An integration package adds its named
  /// accessor via `extension on DwPluginRegistry`.
  final DwPluginRegistry plugins;

  final notify = _DwNotifications._();

  /// Lazy app-state sources captured into every error report — register the
  /// route source and custom entries (user, tenant, ...) at app start.
  final errorContext = DwErrorContext();

  Future<void> init() async {
    await plugins.initAll(this);
  }

  /// Ends this core and releases the live slot, so another can be built — a
  /// test builds and disposes one per test. A disposed core is not reused.
  @mustCallSuper
  Future<void> dispose() async {
    detachDwInstance(this);
  }

  /// Reports an error through the framework pipeline: captures the app-state
  /// context snapshot and dispatches the [DwErrorReport] to [dispatchReport].
  /// The optional metadata names the interception point — the framework's
  /// own catches (DwUiAction, async builders, the zone handler) fill it.
  void handleError(
    Object error,
    StackTrace stackTrace, {
    DwErrorSource source = DwErrorSource.manual,
    String? label,
    String? failedCall,
  }) => dispatchReport(
    DwErrorReport(
      error: error,
      stackTrace: stackTrace,
      source: source,
      label: label,
      failedCall: failedCall,
      context: errorContext.capture(appVersion: _config.appVersion),
    ),
  );

  /// Dispatch point for every reported error: runs the configured
  /// [DwFlutterConfig.onErrorReport] hook, or logs via `debugPrint` when none
  /// is set.
  void dispatchReport(DwErrorReport report) {
    final onReport = _config.onErrorReport;
    if (onReport != null) return onReport(report);
    debugPrint('${report.error}\n${report.stackTrace}');
  }

  /// Shows a confirmation for [confirmation]: the app-supplied
  /// [DwFlutterConfig.confirmDialogBuilder] when set, the built-in [DwConfirmDialog]
  /// otherwise. Used by `DwUiAction(confirmation: ...)`.
  Future<bool?> confirm(BuildContext context, DwUiConfirmation confirmation) =>
      (_config.confirmDialogBuilder ?? DwConfirmDialog.show)(
        context,
        confirmation,
      );
}
