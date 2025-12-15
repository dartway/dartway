enum DwUiNotificationType { info, success, warning, error }

class DwUiNotification {
  final String message;
  final DwUiNotificationType type;
  final Duration duration;

  DwUiNotification({
    required this.message,
    required this.type,
    this.duration = const Duration(seconds: 3),
  });

  factory DwUiNotification.success(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) => DwUiNotification(
    message: message,
    type: DwUiNotificationType.success,
    duration: duration,
  );

  factory DwUiNotification.info(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) => DwUiNotification(
    message: message,
    type: DwUiNotificationType.info,
    duration: duration,
  );

  factory DwUiNotification.warning(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) => DwUiNotification(
    message: message,
    type: DwUiNotificationType.warning,
    duration: duration,
  );

  factory DwUiNotification.error(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) => DwUiNotification(
    message: message,
    type: DwUiNotificationType.error,
    duration: duration,
  );
}
