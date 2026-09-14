part of '../dw_flutter.dart';

class _DwNotifications {
  _DwNotifications._();

  /// Delivers a notification of any type through the pipeline. The type
  /// factories above build simple ones; pass a custom value here directly.
  void custom<NotificationClass>(NotificationClass notification) {
    DwNotificationsController.emit(notification);
  }

  void info(String message) => custom(DwUiNotification.info(message));
  void success(String message) => custom(DwUiNotification.success(message));
  void warning(String message) => custom(DwUiNotification.warning(message));
  void error(String message) => custom(DwUiNotification.error(message));
}
