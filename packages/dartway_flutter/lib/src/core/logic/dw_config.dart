import 'package:flutter/material.dart';

import '../../diagnostics/error_reporting/dw_error_report.dart';
import '../../ui/confirmation/dw_ui_confirmation.dart';

class DwConfig {
  const DwConfig({
    this.onErrorReport,
    this.appVersion,
    this.confirmDialogBuilder,
    this.defaultModelGetter,
  });

  /// Called for every reported error with its full [DwErrorReport] — the error
  /// itself plus the app-state context snapshot (route, mounted features,
  /// action, platform, version, user). When set, it replaces the default
  /// (which logs the error via `debugPrint`) and disables the `DwCore`
  /// out-of-the-box alerting.
  final void Function(DwErrorReport report)? onErrorReport;

  /// App version shown in error reports.
  final String? appVersion;

  /// Custom confirmation UI for `dw.action(confirmation: ...)`. Defaults to
  /// the built-in `DwConfirmDialog`.
  final Future<bool?> Function(
    BuildContext context,
    DwUiConfirmation confirmation,
  )? confirmDialogBuilder;

  /// Returns a placeholder instance of any model `T` for skeleton loading
  /// states — the data layer wires this to its mock-model registry. When unset,
  /// skeletons fall back to a generic shimmer.
  final T Function<T>()? defaultModelGetter;
}
