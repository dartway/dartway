import 'dart:async';

import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_flutter/src/notifications/service/dw_notifications_controller.dart';
import 'package:dartway_flutter/src/private/dw_singleton.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/dw_shared_preferences.dart';
import 'telegram_app/telegram_app.dart';

part 'parts/dw_navigation.dart';
part 'parts/dw_notifications.dart';
part 'parts/dw_services.dart';

class DwFlutter {
  DwFlutter({required DwConfig config}) : _config = config {
    setDwInstance(this);
  }

  final DwConfig _config;

  final notify = _DwNotifications._();
  final services = _DwServices._();
  final navigation = _DwNavigation._();

  /// Lazy app-state sources captured into every error report — register the
  /// route source and custom entries (user, tenant, ...) at app start.
  final errorContext = DwErrorContext();

  Future<void> init() async {
    await services._init(config: _config);
  }

  /// Reports an error through the framework pipeline: captures the app-state
  /// context snapshot and dispatches the [DwErrorReport] to [reportError].
  /// The optional metadata names the interception point — the framework's
  /// own catches (DwUiAction, async builders, the zone handler) fill it.
  void handleError(
    Object error,
    StackTrace stackTrace, {
    DwErrorSource source = DwErrorSource.manual,
    String? actionLabel,
    String? failedCall,
  }) =>
      reportError(DwErrorReport(
        error: error,
        stackTrace: stackTrace,
        source: source,
        actionLabel: actionLabel,
        failedCall: failedCall,
        context: errorContext.capture(appVersion: _config.appVersion),
      ));

  /// Dispatch point for every reported error. The base implementation runs
  /// the configured handlers; `DwCore` overrides it to alert out of the box
  /// when the app has not installed its own policy.
  void reportError(DwErrorReport report) {
    final onReport = _config.onErrorReport;
    if (onReport != null) return onReport(report);
    _config.globalErrorHandler?.call(report.error, report.stackTrace);
  }

  /// True when the app supplied its own error handling in [DwConfig] — the
  /// out-of-the-box alerting then steps aside.
  bool get hasCustomErrorHandling =>
      _config.onErrorReport != null ||
      !identical(_config.globalErrorHandler, DwConfig.debugInfoErrorHandler);

  /// Shows a confirmation for [confirmation]: the app-supplied
  /// [DwConfig.confirmDialogBuilder] when set, the built-in [DwConfirmDialog]
  /// otherwise. Used by `DwUiAction(confirmation: ...)`.
  Future<bool?> confirm(
    BuildContext context,
    DwUiConfirmation confirmation,
  ) =>
      (_config.confirmDialogBuilder ?? DwConfirmDialog.show)(
        context,
        confirmation,
      );

  bool get isDefaultModelsGetterSetUp => _config.defaultModelGetter != null;

  T getDefaultModel<T>() {
    final getter = _config.defaultModelGetter;

    if (getter == null) {
      throw StateError(
        'DwFlutter.defaultModelGetter is not set. '
        'Please provide it in DwConfig when initializing DwApp',
      );
    }

    return getter<T>();
  }

  DwUiAction<T> action<T>(
    FutureOr<T> Function(BuildContext context) action, {
    String? label,
    DwUiConfirmation? confirmation,
    FutureOr<void> Function(BuildContext mountedContext, T actionResult)?
    followUpIfMountedAction,
    String? onSuccessNotification,

    String? onErrorNotification,
    FutureOr<DwUiNotification> Function(T actionResult)?
    customNotificationBuilder,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    return DwUiAction<T>.create(
      action,
      label: label,
      confirmation: confirmation,
      followUpIfMountedAction: followUpIfMountedAction,
      onSuccessNotification: onSuccessNotification,
      customNotificationBuilder: customNotificationBuilder,
      onErrorNotification: onErrorNotification,
      onError: onError,
    );
  }
}
