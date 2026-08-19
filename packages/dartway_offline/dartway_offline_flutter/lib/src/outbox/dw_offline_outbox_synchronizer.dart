import 'dart:async';

import '../network/dw_network_class.dart';
import 'dw_offline_outbox.dart';

/// Replays the active user's durable mutation queue whenever network returns.
final class DwOfflineOutboxSynchronizer {
  DwOfflineOutboxSynchronizer({
    required DwOfflineOutbox outbox,
    required DwNetworkClassSource networkSource,
    required DwOutboxReplayTransport replayTransport,
  }) : _outbox = outbox,
       _networkSource = networkSource,
       _replayTransport = replayTransport;

  final DwOfflineOutbox _outbox;
  final DwNetworkClassSource _networkSource;
  final DwOutboxReplayTransport _replayTransport;
  StreamSubscription<DwNetworkClass>? _networkSubscription;
  Future<void> _operationTail = Future<void>.value();
  String? _activeUserScopeId;
  int _scopeGeneration = 0;
  bool _isInitialized = false;
  bool _isDisposed = false;

  Future<void> initialize() async {
    _requireNotDisposed();
    if (_isInitialized) return;
    _networkSubscription = _networkSource.networkClassChanges.listen((
      networkClass,
    ) {
      if (networkClass != DwNetworkClass.offline) {
        unawaited(synchronizeNow());
      }
    });
    _isInitialized = true;
  }

  Future<void> activateUserScope(String userScopeId) async {
    _requireInitialized();
    if (userScopeId.trim().isEmpty || userScopeId != userScopeId.trim()) {
      throw ArgumentError.value(userScopeId, 'userScopeId');
    }
    if (_activeUserScopeId == userScopeId) {
      await synchronizeNow();
      return;
    }
    _scopeGeneration += 1;
    final activationGeneration = _scopeGeneration;
    _activeUserScopeId = userScopeId;
    try {
      await synchronizeNow();
    } on Object {
      if (_activeUserScopeId == userScopeId &&
          _scopeGeneration == activationGeneration) {
        _scopeGeneration += 1;
        _activeUserScopeId = null;
      }
      rethrow;
    }
  }

  Future<void> deactivateUserScope(String userScopeId) {
    _requireInitialized();
    if (_activeUserScopeId != null && _activeUserScopeId != userScopeId) {
      return Future<void>.error(
        StateError('Cannot deactivate a different outbox user scope.'),
      );
    }
    _scopeGeneration += 1;
    _activeUserScopeId = null;
    return _operationTail;
  }

  Future<void> synchronizeNow() {
    _requireInitialized();
    return _serialize(_synchronizeActiveScope);
  }

  Future<void> _synchronizeActiveScope() async {
    final userScopeId = _activeUserScopeId;
    if (userScopeId == null) return;
    if (await _networkSource.currentNetworkClass() == DwNetworkClass.offline) {
      return;
    }
    final scopeGeneration = _scopeGeneration;
    await _outbox.replay(
      userScopeId: userScopeId,
      transport: (mutation) async {
        if (!_isCurrentScope(userScopeId, scopeGeneration)) {
          return const DwOutboxReplayResult.connectionFailure();
        }
        final replayResult = await _replayTransport(mutation);
        if (!_isCurrentScope(userScopeId, scopeGeneration)) {
          return const DwOutboxReplayResult.connectionFailure();
        }
        return replayResult;
      },
    );
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _scopeGeneration += 1;
    _activeUserScopeId = null;
    await _operationTail;
    await _networkSubscription?.cancel();
    _networkSubscription = null;
    _isInitialized = false;
    _isDisposed = true;
  }

  bool _isCurrentScope(String userScopeId, int scopeGeneration) =>
      !_isDisposed &&
      _activeUserScopeId == userScopeId &&
      _scopeGeneration == scopeGeneration;

  void _requireInitialized() {
    _requireNotDisposed();
    if (!_isInitialized) {
      throw StateError('Initialize the offline outbox synchronizer first.');
    }
  }

  void _requireNotDisposed() {
    if (_isDisposed) {
      throw StateError('Offline outbox synchronizer is disposed.');
    }
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final queued = _operationTail.then((_) => operation());
    _operationTail = queued.then<void>((_) {}, onError: (_, _) {});
    return queued;
  }
}
