import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/dw_notifications_service_provider.dart';
import '../logic/dw_notification_handler.dart';

/// Mounts an [Overlay] and dispatches notification events from the service
/// stream to the matching handler by runtime type. Wrap the app in one and
/// supply a handler per notification type: `handlers: {DwUiNotification:
/// DwUiNotificationHandler()}`.
class DwNotificationsListener extends ConsumerStatefulWidget {
  final Widget child;
  final Map<Type, DwNotificationHandler<dynamic>> handlers;

  const DwNotificationsListener({
    required this.child,
    required this.handlers,
    super.key,
  });

  static late OverlayState overlay;

  static OverlayState? get maybeOverlay => overlay.mounted ? overlay : null;

  @override
  ConsumerState<DwNotificationsListener> createState() =>
      _DwNotificationsListenerState();
}

class _DwNotificationsListenerState
    extends ConsumerState<DwNotificationsListener> {
  StreamSubscription<dynamic>? _streamSubscription;

  @override
  void initState() {
    super.initState();

    final service = ref.read(dwNotificationsServiceProvider);
    _streamSubscription = service.stream.listen((event) {
      final handler = widget.handlers[event.runtimeType];
      final safeContext = DwNotificationsListener.overlay.context;

      if (handler != null && safeContext.mounted) {
        handler.show(safeContext, event);
      }
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (context) {
              DwNotificationsListener.overlay = Overlay.of(context);
              return widget.child;
            },
          ),
        ],
      ),
    );
  }
}
