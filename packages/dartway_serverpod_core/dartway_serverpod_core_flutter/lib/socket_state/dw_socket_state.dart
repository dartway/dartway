import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:dartway_serverpod_core_flutter/private/dw_singleton.dart';
import 'package:dartway_serverpod_core_flutter/repository/access_extensions/ref_update_actions_extension.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dw_socket_state.freezed.dart';
part 'dw_socket_state.g.dart';

@freezed
abstract class DwSocketStateModel with _$DwSocketStateModel {
  const factory DwSocketStateModel({
    required StreamingConnectionStatus websocketStatus,
  }) = _DwSocketStateModel;
}

@Riverpod(keepAlive: true)
class DwSocketState extends _$DwSocketState {
  StreamingConnectionHandler? _connectionHandler;

  @override
  DwSocketStateModel build() {
    if (dw.sessionProvider != null) {
      ref.listen(dw.sessionProvider!, (previousState, nextState) {
        if (nextState.signedInUserId != previousState?.signedInUserId) {
          _connectionHandler?.client.closeStreamingConnection();
        }
      });
    }

    return DwSocketStateModel(
      websocketStatus: StreamingConnectionStatus.disconnected,
    );
  }

  Future<bool> init({required ServerpodClientShared client}) async {
    _connectionHandler = StreamingConnectionHandler(
      client: client,
      retryEverySeconds: 1,
      listener: (connectionState) async {
        debugPrint('listener called ${connectionState.status}');
        _refresh();
      },
    );

    _connectionHandler!.connect();

    return true;
  }

  _refresh() async {
    if (state.websocketStatus != StreamingConnectionStatus.connected &&
        _connectionHandler?.status.status ==
            StreamingConnectionStatus.connected) {
      _listenToUpdates();
    }

    state = DwSocketStateModel(
      websocketStatus:
          _connectionHandler?.status.status ??
          StreamingConnectionStatus.disconnected,
    );
  }

  _proccessUpdate(DwModelWrapper update) {
    debugPrint("Received ${update.className} with id ${update.modelId}");
    // TODO: setup app notifications processing
    // if (update.model is DwAppNotification) {
    //   ref.notifyUser(update.model as DwAppNotification);
    //   // for (var enclosedObject
    //   //     in (update.model as DwAppNotification).updatedModels ?? []) {
    //   //   ref.updateFromStream(enclosedObject);
    //   // }
    // }

    ref.updateFromStream(update);
  }

  Future<void> _listenToUpdates() async {
    dw.endpointCaller.dwRealTime.resetStream();

    // final t = nitToolsCaller!.nitCrud.stream.listen(onData)

    await for (var update in dw.endpointCaller.dwRealTime.stream) {
      if (update is DwModelWrapper) {
        _proccessUpdate(update);
      } else if (update is DwUpdatesTransport) {
        for (var e in update.wrappedModelUpdates) {
          _proccessUpdate(e);
        }
      }
    }
  }
}
