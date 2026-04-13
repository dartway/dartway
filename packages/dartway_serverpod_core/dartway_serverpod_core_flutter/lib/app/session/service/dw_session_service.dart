import 'dart:async';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

import '../../../repository/dw_repository.dart';
import 'dw_authentification_key_manager.dart';

typedef DwSessionUserChangedListener<
  UserProfileClass extends SerializableModel
> = void Function(UserProfileClass? profile, int? id);

class DwSessionService<UserProfileClass extends SerializableModel> {
  DwSessionService({
    required this.keyManager,
    required DwSessionUserChangedListener<UserProfileClass> onUserChanged,
    required this.fetchUserProfile,
    required this.deleteAuthKey,
  }) {
    addUserChangedListener(onUserChanged, fireImmediately: false);
  }

  final DwAuthenticationKeyManager keyManager;

  /// Абстракция для догрузки профиля
  final Future<void> Function(int userId) fetchUserProfile;

  /// Абстракция для удаления authKey (чтобы не зависеть от dw singleton)
  final Future<void> Function(int authKeyId) deleteAuthKey;

  int? _currentUserId;
  UserProfileClass? _currentUserProfile;
  Future<void>? _initializeFuture;
  bool _isInitialized = false;
  bool _repositoryListenersRegistered = false;
  final List<DwSessionUserChangedListener<UserProfileClass>>
  _userChangedListeners = [];

  int? get currentUserId => _currentUserId;
  UserProfileClass? get currentUserProfile => _currentUserProfile;

  void addUserChangedListener(
    DwSessionUserChangedListener<UserProfileClass> listener, {
    bool fireImmediately = true,
  }) {
    _userChangedListeners.add(listener);
    if (fireImmediately) {
      listener(_currentUserProfile, _currentUserId);
    }
  }

  void removeUserChangedListener(
    DwSessionUserChangedListener<UserProfileClass> listener,
  ) {
    _userChangedListeners.remove(listener);
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    final pendingInitialize = _initializeFuture;
    if (pendingInitialize != null) {
      await pendingInitialize;
      return;
    }

    _initializeFuture = _doInitialize();

    try {
      await _initializeFuture;
      _isInitialized = true;
    } catch (_) {
      _removeRepositoryUpdateListeners();
      rethrow;
    } finally {
      _initializeFuture = null;
    }
  }

  Future<void> _doInitialize() async {
    final (int? id, UserProfileClass? profile) = await keyManager
        .loadLocalUserProfile<UserProfileClass>();

    if (profile != null) {
      _setCurrentUser(profile, id);
    }

    _addRepositoryUpdateListeners();

    if (id != null) {
      await fetchUserProfile(id);
    }
  }

  void dispose() {
    _removeRepositoryUpdateListeners();
    _isInitialized = false;
    _initializeFuture = null;
  }

  void _addRepositoryUpdateListeners() {
    if (_repositoryListenersRegistered) return;

    DwRepository.addUpdatesListener<DwAuthData>(_handleAuthDataUpdates);
    DwRepository.addUpdatesListener<UserProfileClass>(
      _handleUserProfileUpdates,
    );
    _repositoryListenersRegistered = true;
  }

  void _removeRepositoryUpdateListeners() {
    if (!_repositoryListenersRegistered) return;

    DwRepository.removeUpdatesListener<DwAuthData>(_handleAuthDataUpdates);
    DwRepository.removeUpdatesListener<UserProfileClass>(
      _handleUserProfileUpdates,
    );
    _repositoryListenersRegistered = false;
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

      _setCurrentUser(profile, currentUserId);

      return;
    }
  }

  Future<void> _signIn(DwAuthData authData) async {
    final user = authData.userProfile as UserProfileClass;
    final id = authData.userId;

    await keyManager.put('${authData.keyId}:${authData.key}');
    await keyManager.storeUserProfile(user);

    _setCurrentUser(user, id);
  }

  Future<void> signOut() async {
    final authKeyId = keyManager.authKeyId;

    if (authKeyId != null) {
      await deleteAuthKey(authKeyId);
    }

    _currentUserId = null;

    await keyManager.remove();

    _setCurrentUser(null, null);
  }

  void _setCurrentUser(UserProfileClass? profile, int? id) {
    _currentUserProfile = profile;
    _currentUserId = id;

    for (final listener in List.of(_userChangedListeners)) {
      listener(profile, id);
    }
  }
}
