/// Structured context rendered into an error alert. Pure Dart — the Flutter
/// side fills it from its error-report pipeline, the server side may fill it
/// with request data. Every field is optional; empty fields are omitted from
/// the message.
class DwAlertContext {
  const DwAlertContext({
    this.platform,
    this.appVersion,
    this.userLabel,
    this.route,
    this.features = const [],
    this.actionLabel,
    this.failedCall,
    this.extra = const {},
  });

  /// E.g. `web/android`, `ios`, `server`.
  final String? platform;

  final String? appVersion;

  /// E.g. `user 42`.
  final String? userLabel;

  /// Current route path of the app, e.g. `/admin/users`.
  final String? route;

  /// Ids of the product features mounted on the current screen.
  final List<String> features;

  /// Label of the UI action that failed (see `DwUiAction`).
  final String? actionLabel;

  /// `endpointName.methodName` of the failed server call.
  final String? failedCall;

  /// App-defined entries (tenant, locale, ...), rendered as `key: value`.
  final Map<String, String> extra;

  bool get isEmpty =>
      platform == null &&
      appVersion == null &&
      userLabel == null &&
      route == null &&
      features.isEmpty &&
      actionLabel == null &&
      failedCall == null &&
      extra.isEmpty;
}
