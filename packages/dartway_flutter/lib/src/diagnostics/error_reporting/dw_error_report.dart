import 'logic/dw_error_context.dart';
import 'logic/dw_error_source.dart';

export 'logic/dw_error_context.dart';
export 'logic/dw_error_source.dart';

/// Everything known about a reported error: the error itself plus the app-state
/// snapshot and the interception metadata. This is what a
/// `DwConfig.onErrorReport` hook receives.
class DwErrorReport {
  const DwErrorReport({
    required this.error,
    required this.stackTrace,
    required this.source,
    required this.context,
    this.actionLabel,
    this.failedCall,
  });

  final Object error;
  final StackTrace stackTrace;
  final DwErrorSource source;
  final DwErrorContextSnapshot context;

  /// Label of the `DwUiAction` that failed.
  final String? actionLabel;

  /// `endpointName.methodName` of the failed server call.
  final String? failedCall;
}
