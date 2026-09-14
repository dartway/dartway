/// Where in the framework the error was intercepted.
enum DwErrorSource {
  /// FlutterError.onError / PlatformDispatcher.onError (uncaught).
  zone,

  /// The catch inside a `DwUiAction`.
  uiAction,

  /// An AsyncValue error branch (`dwBuildAsync` family).
  asyncBuild,

  /// A failed server call (the request or command name attached).
  failedCall,

  /// An explicit `dw.handleError(...)` call from app code.
  manual,

  /// Reported by the data client with no caller to throw to: a server message
  /// it could not read, a request's `onUpdate` that threw, a channel the
  /// server does not declare, a sign-out that did not revoke the key.
  client,
}
