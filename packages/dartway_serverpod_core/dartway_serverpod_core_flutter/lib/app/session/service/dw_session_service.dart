import 'dart:async';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

import '../../../repository/dw_repository.dart';
import 'dw_authentification_key_manager.dart';

class DwSessionService<UserProfileClass extends SerializableModel> {
  DwSessionService({
    required this.keyManager,
    required this.onUserChanged,
    required this.fetchUserProfile,
    required this.deleteAuthKey,
  });

  final DwAuthenticationKeyManager keyManager;

  /// Вызывается при любом изменении пользователя
  final void Function(UserProfileClass? profile, int? id) onUserChanged;

  /// Абстракция для догрузки профиля
  final Future<void> Function(int userId) fetchUserProfile;

  /// Абстракция для удаления authKey (чтобы не зависеть от dw singleton)
  final Future<void> Function(int authKeyId) deleteAuthKey;

  int? _currentUserId;

  Future<void> initialize() async {
    final (int? id, UserProfileClass? profile) = await keyManager
        .loadLocalUserProfile<UserProfileClass>();

    _currentUserId = id;

    onUserChanged(profile, id);

    DwRepository.addUpdatesListener<DwAuthData>(_handleAuthDataUpdates);
    DwRepository.addUpdatesListener<UserProfileClass>(
      _handleUserProfileUpdates,
    );

    if (id != null) {
      await fetchUserProfile(id);
    }
  }

  void dispose() {
    DwRepository.removeUpdatesListener<DwAuthData>(_handleAuthDataUpdates);
    DwRepository.removeUpdatesListener<UserProfileClass>(
      _handleUserProfileUpdates,
    );
  }

  void _handleAuthDataUpdates(List<DwModelWrapper> updates) async {
    for (final wrapped in updates) {
      if (wrapped.model is DwAuthData && !wrapped.isDeleted) {
        await _signIn(wrapped.model as DwAuthData);
        return;
      }
    }
  }

  void _handleUserProfileUpdates(List<DwModelWrapper> updates) async {
    final currentUserId = _currentUserId;

    if (currentUserId == null) return;

    for (final wrapped in updates) {
      if (wrapped.model is! UserProfileClass) continue;

      if (wrapped.modelId == null || wrapped.modelId != currentUserId) {
        continue;
      }

      final profile = wrapped.model as UserProfileClass;

      await keyManager.storeUserProfile(profile);

      onUserChanged(profile, currentUserId);

      return;
    }
  }

  Future<void> _signIn(DwAuthData authData) async {
    final user = authData.userProfile as UserProfileClass;
    final id = authData.userId;

    _currentUserId = id;

    await keyManager.put('${authData.keyId}:${authData.key}');
    await keyManager.storeUserProfile(user);

    onUserChanged(user, id);
  }

  Future<void> signOut() async {
    final authKeyId = keyManager.authKeyId;

    if (authKeyId != null) {
      await deleteAuthKey(authKeyId);
    }

    _currentUserId = null;

    await keyManager.remove();

    onUserChanged(null, null);
  }
}
