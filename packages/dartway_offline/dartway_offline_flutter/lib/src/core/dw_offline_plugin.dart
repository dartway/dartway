import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';

import 'dw_offline_config.dart';
import 'dw_offline_user_scope.dart';

/// An optional DartWay plugin that owns offline user-scope lifecycle, and the
/// local store `dw.repo` reads and writes through.
///
/// Declared with the core, which is what gives it the core's lifetime:
///
/// ```dart
/// dw = DwCore(
///   config: ..., client: ..., dwAlerts: ..., getUserId: ...,
///   plugins: [DwOfflinePlugin(config: offlineConfig)],
/// );
/// ```
///
/// Call [activateUserScope] after authenticated startup, [deactivateUserScope]
/// on sign-out, and [dispose] when the application integration is torn down.
/// Runtime operations are serialized: an old scope is cleared and purged before
/// another scope can become observable.
///
/// Being a [DwRepoLocalStorePlugin] is how the repository finds it — there is
/// nothing to register, and nothing that could stay registered after the core
/// it belongs to is gone. Both halves report `null` until the runtime is
/// initialized and again once it is disposed, which leaves `dw.repo`
/// network-only on the way in and on the way out.
class DwOfflinePlugin extends DwRepoLocalStorePlugin {
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
  DwRepoLocalReads? get localReads => _runtime?.localReads;

  @override
  DwRepoLocalWrites? get localWrites => _runtime?.localWrites;

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

/// Reaches the offline plugin as `dw.plugins.offline`.
///
/// The app talks to it for the things only it knows — the active scope, whether
/// there are unsaved changes waiting for a connection. Reads and writes need no
/// mention of it at all: they stay `dw.repo.saveModel(...)` and route
/// themselves.
extension DwOfflineAccess on DwPlugins {
  DwOfflinePlugin get offline => of<DwOfflinePlugin>();
}
