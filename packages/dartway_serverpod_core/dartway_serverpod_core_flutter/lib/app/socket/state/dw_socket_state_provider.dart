import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:serverpod_client/serverpod_client.dart';

import '../../../private/dw_singleton.dart';
import '../domain/dw_socket_state_model.dart';
import '../service/dw_socket_service.dart';

final dwSocketStateProvider =
    NotifierProvider<DwSocketStateNotifier, DwSocketStateModel>(
      DwSocketStateNotifier.new,
    );

class DwSocketStateNotifier extends Notifier<DwSocketStateModel> {
  late final DwSocketService _service;

  @override
  DwSocketStateModel build() {
    final client = dw.client;
    final endpointCaller = dw.endpointCaller;

    _service = DwSocketService(
      client: client,
      endpointCaller: endpointCaller,
      onStatusChanged: (status) {
        state = state.copyWith(websocketStatus: status);
      },
    );

    ref.onDispose(_service.dispose);

    // слушаем сессию
    if (dw.sessionService != null) {
      // предполагаем, что sessionService теперь в core
      // и имеет onUserChanged callback
      // либо можно подписаться через отдельный callback
    }

    return const DwSocketStateModel(
      websocketStatus: StreamingConnectionStatus.disconnected,
    );
  }

  Future<void> init() async {
    _service.init();
  }

  Future<void> subscribeToChannel(String channel) =>
      _service.subscribeToChannel(channel);

  Future<void> unsubscribeFromChannel(String channel) =>
      _service.unsubscribeFromChannel(channel);
}
