// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:serverpod_client/serverpod_client.dart';

// import '../../../private/dw_singleton.dart';
// import '../domain/dw_socket_state_model.dart';
// import '../service/dw_socket_service.dart';

// final dwSocketStateProvider =
//     NotifierProvider<DwSocketStateNotifier, DwSocketStateModel>(
//       DwSocketStateNotifier.new,
//     );

// class DwSocketStateNotifier extends Notifier<DwSocketStateModel> {
//   late final DwSocketService _service;

//   @override
//   DwSocketStateModel build() {
//     _service = dw.socketService!;

//     void listener() {
//       state = state.copyWith(websocketStatus: _service.status.value);
//     }

//     _service.status.addListener(listener);

//     ref.onDispose(() {
//       _service.status.removeListener(listener);
//     });

//     return DwSocketStateModel(websocketStatus: _service.status.value);
//   }

//   Future<void> subscribeToChannel(String channel) =>
//       _service.subscribeToChannel(channel);

//   Future<void> unsubscribeFromChannel(String channel) =>
//       _service.unsubscribeFromChannel(channel);
// }
