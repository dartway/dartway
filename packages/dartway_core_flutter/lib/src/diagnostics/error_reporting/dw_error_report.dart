import 'logic/dw_error_context.dart';
import 'logic/dw_error_source.dart';

export 'logic/dw_error_context.dart';
export 'logic/dw_error_source.dart';

/// Everything known about a reported error: the error itself plus the app-state
/// snapshot and the interception metadata. This is what a
/// `DwFlutterConfig.onErrorReport` hook receives.
class DwErrorReport {
  const DwErrorReport({
    required this.error,
    required this.stackTrace,
    required this.source,
    required this.context,
    this.label,
    this.failedCall,
  });

  final Object error;
  final StackTrace stackTrace;
  final DwErrorSource source;
  final DwErrorContextSnapshot context;

  /// What failed, in words the reader of a report recognises — for a
  /// `DwUiAction` its label; for any other source what the caller of
  /// `handleError` named. Every source may carry one.
  final String? label;

  /// The wire name of the request or command that failed.
  final String? failedCall;
}
