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
