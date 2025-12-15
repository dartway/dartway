import 'package:collection/collection.dart';
import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart'
    as dartway;
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../private/dw_singleton.dart';
import '../session/logic/dw_session_state.dart';
import '../session/logic/dw_session_state_model.dart';

class DwCore<
  ServerpodClientClass extends ServerpodClientShared,
  UserProfileClass extends SerializableModel
>
    extends DwFlutter {
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

    sessionProvider =
        (client.authenticationKeyManager == null)
            ? null
            : StateNotifierProvider<
              DwSessionStateNotifier<UserProfileClass>,
              DwSessionStateModel<UserProfileClass>
            >(
              (ref) => DwSessionStateNotifier<UserProfileClass>(
                ref,
                client.authenticationKeyManager as DwAuthenticationKeyManager,
              ),
            );
  }

  final ServerpodClientClass client;
  final DwAlerts dwAlerts;
  late final StateNotifierProvider<
    DwSessionStateNotifier<UserProfileClass>,
    DwSessionStateModel<UserProfileClass>
  >?
  sessionProvider;

  late final dartway.Caller endpointCaller;

  final int? Function(UserProfileClass? user) getUserId;

  Future<void> initDwCore({
    // TODO: remove ref
    required WidgetRef ref,
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

    if (sessionProvider != null) {
      await ref.read(sessionProvider!.notifier).initialize();
    }

    if (kDebugMode) {
      debugPrint('[DwCore] initialized for $UserProfileClass');
    }
  }
}
