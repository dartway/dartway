import 'package:dartway_flutter/dartway_flutter.dart';

import 'dw_offline_config.dart';
import 'dw_offline_user_scope.dart';

/// An optional DartWay plugin that owns offline user-scope lifecycle.
///
/// Call [activateUserScope] after authenticated startup, [deactivateUserScope]
/// on sign-out, and [dispose] when the application integration is torn down.
/// Runtime operations are serialized: an old scope is cleared and purged before
/// another scope can become observable.
class DwOfflinePlugin extends DwPlugin {
  DwOfflinePlugin({required DwOfflineConfig config}) : _config = config;

  final DwOfflineConfig _config;
  Future<void> _operationQueue = Future<void>.value();
  DwOfflineRuntime? _runtime;
  DwOfflineUserScope? _activeUserScope;
  DwOfflineUserScope? _pendingPurgeUserScope;
  DwOfflineStatus _status = DwOfflineStatus.uninitialized;

  /// The plugin capability and lifecycle state.
  DwOfflineStatus get status => _status;

  /// The protected scope currently eligible for offline operations, if any.
  DwOfflineUserScope? get activeUserScope => _activeUserScope;

  @override
  Future<void> init(DwFlutter core) {
    return _enqueue(() async {
      if (_status == DwOfflineStatus.disposed) {
        throw StateError('Cannot initialize a disposed DwOfflinePlugin.');
      }
      if (_status != DwOfflineStatus.uninitialized) return;

      final platform = _config.platformDetector();
      if (!_isMobilePlatform(platform)) {
        _status = DwOfflineStatus.disabled;
        return;
      }

      final initializedRuntime = _runtime ??= _config.nativeRuntimeFactory();
      await initializedRuntime.initialize();
      _status = DwOfflineStatus.available;
    });
  }

  /// Activates [userScope] after securely removing the preceding scope.
  Future<void> activateUserScope(DwOfflineUserScope userScope) {
    return _enqueue(() async {
      _requireAvailableLifecycle();
      if (_activeUserScope == userScope && _pendingPurgeUserScope == null) {
        return;
      }

      await _purgeProtectedUserScope();
      await _runtime!.activateUserScope(userScope);
      _activeUserScope = userScope;
      _status = DwOfflineStatus.active;
    });
  }

  /// Removes the active authenticated scope during sign-out.
  Future<void> deactivateUserScope() {
    return _enqueue(() async {
      _requireAvailableLifecycle();
      await _purgeProtectedUserScope();
    });
  }

  /// Releases the optional runtime and detaches application lifecycle listeners.
  Future<void> dispose() {
    return _enqueue(() async {
      if (_status == DwOfflineStatus.disposed) return;

      if (_pendingPurgeUserScope != null) {
        await _purgeProtectedUserScope();
      } else if (_activeUserScope case final activeUserScope?) {
        await _runtime!.deactivateUserScope(activeUserScope);
        _activeUserScope = null;
        _status = DwOfflineStatus.available;
      }
      await _config.detachLifecycleListeners?.call();
      await _runtime?.dispose();
      _status = DwOfflineStatus.disposed;
    });
  }

  Future<void> _purgeProtectedUserScope() async {
    final userScopeToPurge = _pendingPurgeUserScope ?? _activeUserScope;
    if (userScopeToPurge == null) return;

    _activeUserScope = null;
    _pendingPurgeUserScope = userScopeToPurge;
    _status = DwOfflineStatus.available;
    await _runtime!.purgeUserScope(userScopeToPurge);
    _pendingPurgeUserScope = null;
  }

  void _requireAvailableLifecycle() {
    if (_status == DwOfflineStatus.disabled) {
      throw StateError('Offline support is disabled on this platform.');
    }
    if (_status == DwOfflineStatus.disposed) {
      throw StateError('Cannot use a disposed DwOfflinePlugin.');
    }
    if (_status == DwOfflineStatus.uninitialized) {
      throw StateError(
        'Initialize DwOfflinePlugin before activating a user scope.',
      );
    }
  }

  bool _isMobilePlatform(DwOfflinePlatform platform) {
    return platform == DwOfflinePlatform.android ||
        platform == DwOfflinePlatform.ios;
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final queuedOperation = _operationQueue.then<T>((_) => operation());
    _operationQueue = queuedOperation.then<void>((_) {}, onError: (_, _) {});
    return queuedOperation;
  }
}
