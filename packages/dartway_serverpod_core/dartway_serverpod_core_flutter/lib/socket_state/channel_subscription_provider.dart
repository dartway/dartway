import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:serverpod_client/serverpod_client.dart';

import 'dw_socket_state.dart';

final channelSubscriptionProvider =
    Provider.family<void, String>((ref, channel) {
  final socketState = ref.watch(dwSocketStateProvider);
  final notifier = ref.read(dwSocketStateProvider.notifier);

  if (socketState.websocketStatus == StreamingConnectionStatus.connected) {
    notifier.subscribeToChannel(channel);
  }

  ref.onDispose(() {
    notifier.unsubscribeFromChannel(channel);
  });
});
