import 'package:flutter/material.dart';

import '../../error_reporting/dw_error_report.dart';
import '../../dialogs/dw_ui_confirmation.dart';

class DwConfig {
  const DwConfig({
    this.globalErrorHandler = debugInfoErrorHandler,
    this.onErrorReport,
    this.appVersion,
    this.confirmDialogBuilder,
    this.defaultModelGetter,
    this.useSharedPreferences = true,
  });
  final bool useSharedPreferences;

  /// Plain error hook, kept for compatibility. Prefer [onErrorReport] — it
  /// receives the full [DwErrorReport] with the app-state context snapshot.
  final void Function(Object error, StackTrace stackTrace)? globalErrorHandler;

  /// Rich error hook: receives every reported error with its context
  /// (route, mounted features, action label, ...). When set, it wins over
  /// [globalErrorHandler] and disables the DwCore out-of-the-box alerting.
  final void Function(DwErrorReport report)? onErrorReport;

  /// App version shown in error reports.
  final String? appVersion;

  /// Custom confirmation UI for `DwUiAction(confirmation: ...)`. Defaults to
  /// the built-in `DwConfirmDialog`.
  final Future<bool?> Function(
    BuildContext context,
    DwUiConfirmation confirmation,
  )? confirmDialogBuilder;

  final T Function<T>()? defaultModelGetter;

  static void debugInfoErrorHandler(Object error, StackTrace stackTrace) =>
      debugPrint('$error\n$stackTrace');
}
