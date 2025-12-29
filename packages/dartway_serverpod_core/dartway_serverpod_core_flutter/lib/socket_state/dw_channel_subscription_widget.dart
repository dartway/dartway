import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'channel_subscription_provider.dart';

class DwChannelSubscriptionWidget extends ConsumerStatefulWidget {
  final String channel;
  final Widget child;

  const DwChannelSubscriptionWidget({
    super.key,
    required this.channel,
    required this.child,
  });

  @override
  ConsumerState<DwChannelSubscriptionWidget> createState() =>
      _ChannelSubscriptionState();
}

class _ChannelSubscriptionState
    extends ConsumerState<DwChannelSubscriptionWidget> {
  // @override
  // void initState() {
  //   super.initState();

  //   // если уже подключены — подпишемся после первой отрисовки
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     final status = ref.read(nitSocketStateProvider).websocketStatus;
  //     if (status == StreamingConnectionStatus.connected) {
  //       ref
  //           .read(nitSocketStateProvider.notifier)
  //           .subscribeToChannel(widget.channel);
  //     }
  //   });

  // гарантированно отписываемся при уничтожении
  // }

  // @override
  // void dispose() {
  //   // гарантированно отписываемся при уходе виджета
  //   ref
  //       .read(nitSocketStateProvider.notifier)
  //       .unsubscribeFromChannel(widget.channel);
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    // слушаем статус соединения и подписываемся при переходе в connected
    // ref.listen<NitSocketStateModel>(
    //   nitSocketStateProvider,
    //   (prev, next) {
    //     if (next.websocketStatus == StreamingConnectionStatus.connected) {
    //       ref
    //           .read(nitSocketStateProvider.notifier)
    //           .subscribeToChannel(widget.channel);
    //     }
    //   },
    // );

    ref.watch(channelSubscriptionProvider(widget.channel));

    return widget.child;
  }
}
