enum DwUiNotificationType { info, success, warning, error }

/// A notification value: a message, a type and how long it shows. Create one
/// with the type factories (`DwUiNotification.success(...)`) — this is data, so
/// it lives on the type, not on `dw`. Deliver a simple one with `dw.notify.*`;
/// build a custom one to return from `dw.action(customNotificationBuilder:)`.
class DwUiNotification {
  static const defaultDuration = Duration(seconds: 3);

  final String message;
  final DwUiNotificationType type;
  final Duration duration;

  DwUiNotification({
    required this.message,
    required this.type,
    this.duration = defaultDuration,
  });

  factory DwUiNotification.success(
    String message, {
    Duration duration = defaultDuration,
  }) => DwUiNotification(
    message: message,
    type: DwUiNotificationType.success,
    duration: duration,
  );

  factory DwUiNotification.info(
    String message, {
    Duration duration = defaultDuration,
  }) => DwUiNotification(
    message: message,
    type: DwUiNotificationType.info,
    duration: duration,
  );

  factory DwUiNotification.warning(
    String message, {
    Duration duration = defaultDuration,
  }) => DwUiNotification(
    message: message,
    type: DwUiNotificationType.warning,
    duration: duration,
  );

  factory DwUiNotification.error(
    String message, {
    Duration duration = defaultDuration,
  }) => DwUiNotification(
    message: message,
    type: DwUiNotificationType.error,
    duration: duration,
  );
}
