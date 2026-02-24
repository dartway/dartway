// import 'dart:async';

// import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
// import 'package:dartway_serverpod_core_flutter/private/dw_singleton.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../../repository/dw_repository.dart';
// import 'domain/dw_socket_state_model.dart';

// final dwSocketStateProvider =
//     NotifierProvider<DwSocketStateNotifier, DwSocketStateModel>(
//       DwSocketStateNotifier.new,
//     );

// class DwSocketStateNotifier extends Notifier<DwSocketStateModel> {
//   StreamingConnectionHandler? _connectionHandler;
//   final Map<String, StreamSubscription<SerializableModel>> _channelSubs = {};
//   StreamSubscription<SerializableModel>? _mainStreamSub;

//   @override
//   DwSocketStateModel build() {
//     ref.onDispose(() async {
//       await _mainStreamSub?.cancel();
//       await unsubscribeAllChannels();
//       _connectionHandler?.client.closeStreamingConnection();
//     });

//     if (dw.sessionProvider != null) {
//       ref.listen(dw.sessionProvider!, (previousState, nextState) {
//         if (nextState.signedInUserId != previousState?.signedInUserId) {
//           _connectionHandler?.client.closeStreamingConnection();
//           unsubscribeAllChannels();
//         }
//       });
//     }

//     return const DwSocketStateModel(
//       websocketStatus: StreamingConnectionStatus.disconnected,
//     );
//   }

//   Future<void> init({required ServerpodClientShared client}) async {
//     _connectionHandler = StreamingConnectionHandler(
//       client: client,
//       retryEverySeconds: 1,
//       listener: (_) => _refresh(),
//     );

//     _connectionHandler!.connect();
//   }

//   void _refresh() {
//     final status =
//         _connectionHandler?.status.status ??
//         StreamingConnectionStatus.disconnected;

//     if (state.websocketStatus != StreamingConnectionStatus.connected &&
//         status == StreamingConnectionStatus.connected) {
//       _startMainStream();
//     }

//     state = state.copyWith(websocketStatus: status);
//   }

//   void _processUpdatedModels(List<DwModelWrapper> updatedModels) {
//     DwRepository.updateListeningStates(
//       wrappedModelUpdates: updatedModels
//           .where((e) => e.modelId != null)
//           .toList(),
//     );
//   }

//   void _processUpdate(SerializableModel update) {
//     if (update is DwModelWrapper) {
//       _processUpdatedModels([update]);
//     } else if (update is DwUpdatesTransport) {
//       _processUpdatedModels(update.wrappedModelUpdates);
//     }
//   }

//   Future<void> _startMainStream() async {
//     await _mainStreamSub?.cancel();

//     dw.endpointCaller.dwRealTime.resetStream();

//     _mainStreamSub = dw.endpointCaller.dwRealTime.stream.listen(
//       _processUpdate,
//       onError: (e, st) {
//         debugPrint("Main stream error: $e");
//       },
//     );
//   }

//   Future<void> subscribeToChannel(String channel) async {
//     if (_connectionHandler?.status.status !=
//         StreamingConnectionStatus.connected) {
//       debugPrint("⚠️ Cannot subscribe, not connected yet");
//       return;
//     }

//     if (_channelSubs.containsKey(channel)) {
//       return;
//     }

//     final sub = dw.endpointCaller.dwCrud
//         .subscribeOnUpdates(channel: channel)
//         .listen(
//           _processUpdate,
//           onDone: () => _channelSubs.remove(channel),
//           onError: (_, __) => _channelSubs.remove(channel),
//           cancelOnError: true,
//         );

//     _channelSubs[channel] = sub;
//   }

//   Future<void> unsubscribeFromChannel(String channel) async {
//     final sub = _channelSubs.remove(channel);
//     await sub?.cancel();
//   }

//   Future<void> unsubscribeAllChannels() async {
//     final subs = _channelSubs.values.toList();
//     _channelSubs.clear();

//     for (final sub in subs) {
//       await sub.cancel();
//     }
//   }
// }
