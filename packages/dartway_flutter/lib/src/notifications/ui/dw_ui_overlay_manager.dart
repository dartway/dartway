// import 'package:flutter/material.dart';

// import '../domain/dw_ui_notification.dart';
// import 'dw_ui_notification_widget.dart';

// class DwUiOverlayManager {
//   static final _queue = <OverlayEntry>[];

//   static void show(BuildContext context, DwUiNotification notification) {
//     final overlay = Overlay.maybeOf(context);

//     if (overlay == null) return;

//     final entry = OverlayEntry(
//       builder: (ctx) => DwUiNotificationWidget(notification: notification),
//     );

//     overlay.insert(entry);
//     _queue.add(entry);

//     Future.delayed(notification.duration, () {
//       entry.remove();
//       _queue.remove(entry);
//     });
//   }
// }
