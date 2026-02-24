import 'package:collection/collection.dart';
import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart'
    as dartway;
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/session/domain/dw_session_state_model.dart';
import '../app/session/service/dw_session_service.dart';
import '../app/session/state/dw_session_state_notifier.dart';
import '../app/socket/service/dw_socket_service.dart';
import '../private/dw_singleton.dart';

class DwCore<
  ServerpodClientClass extends ServerpodClientShared,
  UserProfileClass extends SerializableModel
>
    extends DwFlutter {
  final ServerpodClientClass client;
  final DwAlerts dwAlerts;
  late final DwSessionService<UserProfileClass>? sessionService;
  late final DwSocketService? socketService;
  late final NotifierProvider<
    DwSessionStateNotifier<UserProfileClass>,
    DwSessionStateModel<UserProfileClass>
  >?
  sessionProvider;

  late final dartway.Caller endpointCaller;

  final int? Function(UserProfileClass? user) getUserId;

  DwCore({
    required super.config,
    required this.client,
    required this.dwAlerts,
    required this.getUserId,
  }) {
    setDwInstance(this);

    DwCoreServerpodClient.protocol = client.serializationManager;

    final dartwayCaller = client.moduleLookup.values.firstWhereOrNull(
      (e) => e is dartway.Caller,
    );

    if (dartwayCaller == null) {
      throw Exception(
        'DartWay Core module not found. '
        'Add dartway_serverpod_core module to the client.',
      );
    }
    endpointCaller = dartwayCaller as dartway.Caller;
    socketService = DwSocketService(
      client: client,
      endpointCaller: endpointCaller,
      onStatusChanged: (_) {},
    );

    if (client.authenticationKeyManager != null &&
        client.authenticationKeyManager is DwAuthenticationKeyManager) {
      sessionService = DwSessionService<UserProfileClass>(
        keyManager:
            client.authenticationKeyManager! as DwAuthenticationKeyManager,
        onUserChanged: (profile, id) {
          socketService!.onUserChanged(
            null, // можно хранить prev внутри сервиса
            id,
          );
        },
        fetchUserProfile: (_) async {},
        deleteAuthKey: (_) async {},
      );
      sessionProvider =
          NotifierProvider<
            DwSessionStateNotifier<UserProfileClass>,
            DwSessionStateModel<UserProfileClass>
          >(DwSessionStateNotifier<UserProfileClass>.new);
    } else {
      sessionProvider = null;
      sessionService = null;
    }
  }

  Future<void> initDwCore({
    // TODO: remove initRepositoryFunction
    required Function() initRepositoryFunction,
  }) async {
    await super.init();

    await initRepositoryFunction();
    DwRepository.setupRepository(
      defaultModel: DwAuthKey(
        id: DwRepository.mockModelId,
        userId: DwRepository.mockModelId,
        key: 'mockKey',
        hash: 'mockHash',
      ),
    );
    DwRepository.setupRepository(
      defaultModel: DwAuthData(
        userProfile: DwRepository.getDefault<UserProfileClass>(),
        userId: DwRepository.mockModelId,
        key: 'mockKey',
        keyId: DwRepository.mockModelId,
      ),
    );

    // TODO: check if this is needed and actally works
    final defaultModels = <Type, SerializableModel>{
      UserProfileClass: DwRepository.getDefault<UserProfileClass>(),
    };

    for (final entry in defaultModels.entries) {
      DwRepository.setupRepository(defaultModel: entry.value);
    }

    if (sessionService != null) {
      await sessionService!.initialize();
      socketService!.init();
    }

    if (kDebugMode) {
      debugPrint('[DwCore] initialized for $UserProfileClass');
    }
  }
}
