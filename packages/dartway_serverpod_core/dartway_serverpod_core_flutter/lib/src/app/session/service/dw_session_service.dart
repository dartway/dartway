import 'dart:async';

import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:flutter/foundation.dart';

import '../../../repository/dw_repository.dart';
import '../../socket/service/streaming_error_classifier.dart';
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

  /// Loads the user profile from the server, or `null` when the server has no
  /// profile to give for the stored session. Injected rather than called
  /// directly — the service must not reach for the `dw` singleton.
  final Future<UserProfileClass?> Function(int userId) fetchUserProfile;

  /// Deletes an auth key, injected for the same reason as [fetchUserProfile].
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
    final (int? id, UserProfileClass? cachedProfile) = await keyManager
        .loadLocalUserProfile<UserProfileClass>();

    _addRepositoryUpdateListeners();

    if (id == null) {
      // Nothing usable is stored: no key at all, or a key whose cached profile
      // cannot be read back — and without a user id there is nothing to ask the
      // server about. Clear both halves so a half-written session cannot linger,
      // and start signed out.
      await keyManager.remove();
      return;
    }

    // The cached profile is a *claim*, not a session — the server decides.
    // The profile fetch is filtered server-side by the authenticated user, so a
    // profile comes back only while the stored key is still valid and still
    // belongs to this user; an expired key, a deleted user or a different
    // database all answer with no profile instead of an error.
    try {
      final profile = await fetchUserProfile(id);

      if (profile == null) {
        // The server answered, and the answer is "no such session". Trusting
        // the cache here is what used to keep a signed-out user signed in.
        await invalidateSession();
        return;
      }

      await keyManager.storeUserProfile(profile);
      _setCurrentUser(profile, id);
    } catch (error) {
      // A connection-level failure is not an answer: with a cached profile we
      // start from it and keep working offline — fresh data arrives once
      // connectivity returns. Without one there is nothing to fall back to, and
      // any other error is a real bug; both propagate.
      if (cachedProfile == null || !isStreamingConnectionError(error)) rethrow;

      debugPrint(
        '[DwSessionService] kept cached profile; validation failed: $error',
      );
      _setCurrentUser(cachedProfile, id);
    }
  }

  /// Drops a session the server no longer recognizes: the stored key and the
  /// cached profile go, and every listener sees a signed-out user. Unlike
  /// [signOut] it makes no server call — there is no live session left to
  /// delete a key with.
  ///
  /// Called on startup when the stored key no longer identifies a user, and
  /// when a live subscription is closed with
  /// `DwChannelClosedReason.authenticationRevoked` — the server saying, mid
  /// session, that this account is done.
  Future<void> invalidateSession() async {
    await keyManager.remove();
    _setCurrentUser(null, null);
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
