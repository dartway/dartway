import 'dw_error_context.dart';

/// Where in the framework the error was intercepted.
enum DwErrorSource {
  /// FlutterError.onError / PlatformDispatcher.onError (uncaught).
  zone,

  /// The catch inside a `DwUiAction`.
  uiAction,

  /// An AsyncValue error branch (`dwBuildAsync` family).
  asyncBuild,

  /// A failed server call (`endpoint.method` attached).
  failedCall,

  /// An explicit `dw.handleError(...)` call from app code.
  manual,
}

/// Everything known about a reported error: the error itself plus the app
/// state snapshot and the interception metadata.
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
