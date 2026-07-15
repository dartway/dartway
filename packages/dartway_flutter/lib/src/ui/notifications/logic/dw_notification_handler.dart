import 'package:flutter/material.dart';

/// Renders one notification type. Implement this to add a notification type of
/// your own, and register it in `DwNotificationsListener.handlers` keyed by that
/// type. For the built-in [DwUiNotification], the ready-made
/// [DwUiNotificationHandler] already implements this — you do not write one.
abstract class DwNotificationHandler<T> {
  void show(BuildContext context, T event);
}
