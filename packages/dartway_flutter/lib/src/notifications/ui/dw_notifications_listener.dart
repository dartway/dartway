import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../service/dw_notifications_service_provider.dart';
import 'dw_notification_handler.dart';

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

// static final messengerKey = GlobalKey<ScaffoldMessengerState>();

// static void showGlobal(String message) {
//   final messenger = messengerKey.currentState;
//   if (messenger != null) {
//     messenger.showSnackBar(SnackBar(content: Text(message)));
//   }
// }
// }

class _DwNotificationsListenerState
    extends ConsumerState<DwNotificationsListener> {
  @override
  void initState() {
    super.initState();

    final service = ref.read(dwNotificationsServiceProvider);
    service.stream.listen((event) {
      final handler = widget.handlers[event.runtimeType];
      final safeContext = DwNotificationsListener.overlay.context;

      if (handler != null && safeContext.mounted) {
        // WidgetsBinding.instance.addPostFrameCallback((_) {
        handler.show(safeContext, event);
        // });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection:
          TextDirection.ltr, // Или автоматически из Theme/Locale, если доступно
      child: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (context) {
              // сохраняем overlay глобально
              DwNotificationsListener.overlay = Overlay.of(context);

              return widget.child;
            },
          ),
        ],
      ),
    );
  }
}

// class _DwNotificationsListenerState
//     extends ConsumerState<DwNotificationsListener> {
//   @override
//   void initState() {
//     super.initState();
//     final service = ref.read(dwNotificationsServiceProvider);
//     debugPrint('Listener active');
//     service.stream.listen((event) {
//       final handler = widget.handlers[event.runtimeType];
//       final safeContext =
//           // dwNavigation.context ??
//           DwNotificationsListener.messengerKey.currentContext;

//       if (handler != null && safeContext != null) {
//         // WidgetsBinding.instance.addPostFrameCallback((_) {
//         handler.show(safeContext, event);
//         // });
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     // debugPrint('Start listening');

//     // ref.listen(dwNotificationsServiceProvider, (_, service) {
//     //   debugPrint('Listener active');

//     //   service.stream.listen((event) {
//     //     final handler = widget.handlers[event.runtimeType];
//     //     if (handler != null) {
//     //       WidgetsBinding.instance.addPostFrameCallback((_) {
//     //         handler.show(context, event);
//     //       });
//     //     }
//     //   });
//     // });
//     return widget.child;
//   }
// }
