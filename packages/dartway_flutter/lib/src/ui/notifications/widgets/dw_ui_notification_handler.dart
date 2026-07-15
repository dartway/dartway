import 'package:flutter/material.dart';

import '../dw_ui_notification.dart';
import '../logic/dw_notification_handler.dart';
import 'dw_notifications_listener.dart';
import 'dw_ui_notification_widget.dart';

/// The built-in handler for [DwUiNotification]: inserts a toast overlay entry
/// and removes it after the notification's duration.
class DwUiNotificationHandler
    implements DwNotificationHandler<DwUiNotification> {
  @override
  void show(BuildContext context, DwUiNotification notification) {
    final overlay = DwNotificationsListener.maybeOverlay;
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (ctx) => DwUiNotificationWidget(notification: notification),
    );

    overlay.insert(entry);

    Future.delayed(notification.duration, () {
      entry.remove();
    });
  }
}
