import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:dartway_serverpod_core_shared/dartway_serverpod_core_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../private/dw_singleton.dart';
import '../../../repository/access_extensions/ref_watch_and_read_extension.dart';
import '../domain/dw_session_state_model.dart';
import '../service/dw_authentification_key_manager.dart';
import '../service/dw_session_service.dart';

class DwSessionStateNotifier<UserProfileClass extends SerializableModel>
    extends Notifier<DwSessionStateModel<UserProfileClass>> {
  late DwSessionService<UserProfileClass> _service;

  @override
  DwSessionStateModel<UserProfileClass> build() {
    final keyManager =
        dw.client.authenticationKeyManager as DwAuthenticationKeyManager;

    _service = DwSessionService<UserProfileClass>(
      keyManager: keyManager,

      onUserChanged: (profile, id) {
        state = state.copyWith(
          signedInUserProfile: profile,
          signedInUserId: id,
        );
      },

      fetchUserProfile: (userId) async {
        await ref.readModel<UserProfileClass>(
          id: userId,
          apiGroupOverride: DwCoreConst.dartwayInternalApi,
        );
      },

      deleteAuthKey: (authKeyId) async {
        await dw.endpointCaller.dwCrud.delete(
          className: 'DwAuthKey',
          modelId: authKeyId,
          apiGroup: DwCoreConst.dartwayInternalApi,
        );
      },
    );

    ref.onDispose(_service.dispose);

    return const DwSessionStateModel(
      signedInUserProfile: null,
      signedInUserId: null,
    );
  }

  Future<void> initialize() => _service.initialize();

  Future<void> signOut() => _service.signOut();
}
