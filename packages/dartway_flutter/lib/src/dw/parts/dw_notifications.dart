part of '../dw.dart';

class _DwNotifications {
  _DwNotifications._();

  static const defaultUiNotificationsDuration = Duration(seconds: 3);

  void custom<NotificationClass>(NotificationClass notification) {
    DwNotificationsController.emit(notification);
  }

  void info(String message) {
    custom(
      DwUiNotification(
        message: message,
        type: DwUiNotificationType.info,
        duration: defaultUiNotificationsDuration,
      ),
    );
  }

  void success(String message) {
    custom(
      DwUiNotification(
        message: message,
        type: DwUiNotificationType.success,
        duration: defaultUiNotificationsDuration,
      ),
    );
  }

  void warning(String message) {
    custom(
      DwUiNotification(
        message: message,
        type: DwUiNotificationType.warning,
        duration: defaultUiNotificationsDuration,
      ),
    );
  }

  void error(String message) {
    custom(
      DwUiNotification(
        message: message,
        type: DwUiNotificationType.error,
        duration: defaultUiNotificationsDuration,
      ),
    );
  }
}
