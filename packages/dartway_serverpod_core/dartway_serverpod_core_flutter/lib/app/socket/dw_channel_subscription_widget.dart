import 'package:flutter/widgets.dart';
import 'package:serverpod_client/serverpod_client.dart';

import '../../../private/dw_singleton.dart';
import 'service/dw_socket_service.dart';

class DwChannelSubscriptionWidget extends StatefulWidget {
  final String channel;
  final Widget child;

  const DwChannelSubscriptionWidget({
    super.key,
    required this.channel,
    required this.child,
  });

  @override
  State<DwChannelSubscriptionWidget> createState() =>
      _DwChannelSubscriptionWidgetState();
}

class _DwChannelSubscriptionWidgetState
    extends State<DwChannelSubscriptionWidget> {
  late final DwSocketService _socket;

  void _handleStatusChange() {
    if (_socket.statusNotifier.value == StreamingConnectionStatus.connected) {
      _socket.subscribeToChannel(widget.channel);
    }
  }

  @override
  void initState() {
    super.initState();

    final socket = dw.socketService;

    if (socket == null) {
      throw Exception(
        'DwSocketService is not initialized.\n'
        'Make sure DwCore.initDwCore() was called before using '
        'DwChannelSubscriptionWidget.',
      );
    }

    _socket = socket;

    _socket.statusNotifier.addListener(_handleStatusChange);

    if (_socket.statusNotifier.value == StreamingConnectionStatus.connected) {
      _socket.subscribeToChannel(widget.channel);
    }
  }

  @override
  void dispose() {
    _socket.statusNotifier.removeListener(_handleStatusChange);
    _socket.unsubscribeFromChannel(widget.channel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// import 'package:flutter/widgets.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import 'state/channel_subscription_provider.dart';

// class DwChannelSubscriptionWidget extends ConsumerStatefulWidget {
//   final String channel;
//   final Widget child;

//   const DwChannelSubscriptionWidget({
//     super.key,
//     required this.channel,
//     required this.child,
//   });

//   @override
//   ConsumerState<DwChannelSubscriptionWidget> createState() =>
//       _ChannelSubscriptionState();
// }

// class _ChannelSubscriptionState
//     extends ConsumerState<DwChannelSubscriptionWidget> {
//   // @override
//   // void initState() {
//   //   super.initState();

//   //   // если уже подключены — подпишемся после первой отрисовки
//   //   WidgetsBinding.instance.addPostFrameCallback((_) {
//   //     final status = ref.read(nitSocketStateProvider).websocketStatus;
//   //     if (status == StreamingConnectionStatus.connected) {
//   //       ref
//   //           .read(nitSocketStateProvider.notifier)
//   //           .subscribeToChannel(widget.channel);
//   //     }
//   //   });

//   // гарантированно отписываемся при уничтожении
//   // }

//   // @override
//   // void dispose() {
//   //   // гарантированно отписываемся при уходе виджета
//   //   ref
//   //       .read(nitSocketStateProvider.notifier)
//   //       .unsubscribeFromChannel(widget.channel);
//   //   super.dispose();
//   // }

//   @override
//   Widget build(BuildContext context) {
//     // слушаем статус соединения и подписываемся при переходе в connected
//     // ref.listen<NitSocketStateModel>(
//     //   nitSocketStateProvider,
//     //   (prev, next) {
//     //     if (next.websocketStatus == StreamingConnectionStatus.connected) {
//     //       ref
//     //           .read(nitSocketStateProvider.notifier)
//     //           .subscribeToChannel(widget.channel);
//     //     }
//     //   },
//     // );

//     ref.watch(channelSubscriptionProvider(widget.channel));

//     return widget.child;
//   }
// }
