import 'package:flutter/material.dart';

import '../domain/dw_ui_notification.dart';
import 'dw_notification_handler.dart';
import 'dw_notifications_listener.dart';
import 'dw_ui_notification_widget.dart';

// class DwUiNotificationHandler
//     implements DwNotificationHandler<DwUiNotification> {
//   @override
//   void show(BuildContext context, DwUiNotification notification) {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       DwUiOverlayManager.show(context, notification);
//     });
//   }
// }
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
