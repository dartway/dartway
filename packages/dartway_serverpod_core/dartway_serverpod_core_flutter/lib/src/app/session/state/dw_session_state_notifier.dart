import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../private/dw_singleton.dart';
import '../domain/dw_session_state_model.dart';
import '../service/dw_session_service.dart';

class DwSessionStateNotifier<UserProfileClass extends SerializableModel>
    extends Notifier<DwSessionStateModel<UserProfileClass>> {
  late DwSessionService<UserProfileClass> _service;
  late DwSessionUserChangedListener<UserProfileClass> _listener;

  @override
  DwSessionStateModel<UserProfileClass> build() {
    _service = dw.sessionService! as DwSessionService<UserProfileClass>;

    _listener = (profile, id) {
      state = state.copyWith(signedInUserProfile: profile, signedInUserId: id);
    };

    _service.addUserChangedListener(_listener, fireImmediately: false);
    ref.onDispose(() => _service.removeUserChangedListener(_listener));

    return DwSessionStateModel<UserProfileClass>(
      signedInUserProfile: _service.currentUserProfile,
      signedInUserId: _service.currentUserId,
    );
  }

  Future<void> initialize() => _service.initialize();

  Future<void> signOut() => _service.signOut();
}
