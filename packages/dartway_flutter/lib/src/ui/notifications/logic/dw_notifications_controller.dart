import 'package:flutter/foundation.dart';

import 'dw_notifications_service.dart';

/// The static bridge between `dw.notify.*` and the riverpod-provided service.
/// The service registers itself when a [DwNotificationsListener] first mounts;
/// until then there is nothing to deliver to.
class DwNotificationsController {
  static DwNotificationsService? _service;

  static void register(DwNotificationsService service) {
    _service = service;
  }

  static void emit(dynamic event) {
    final service = _service;
    if (service == null) {
      // A common standalone footgun: posting a notification before wrapping the
      // app in a DwNotificationsListener. Warn in debug, stay silent in release
      // rather than throw — an app may legitimately post before its first
      // listener mounts, or use no notifications at all.
      if (kDebugMode) {
        debugPrint(
          'dw.notify: no DwNotificationsListener is mounted — the notification '
          'was dropped. Wrap your app in a DwNotificationsListener to see it.',
        );
      }
      return;
    }
    service.emit(event);
  }
}
