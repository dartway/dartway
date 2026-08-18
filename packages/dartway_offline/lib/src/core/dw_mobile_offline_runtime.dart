import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';

import '../download/dw_download_scheduler.dart';
import '../repository/dw_offline_read_delegate.dart';
import '../repository/dw_offline_write_delegate.dart';
import '../storage/dw_offline_asset_store.dart';
import '../storage/dw_offline_database.dart';
import 'dw_offline_config.dart';
import 'dw_offline_user_scope.dart';

/// Mobile persistence adapter for opt-in repository snapshots, outbox writes,
/// assets, and background downloads.
final class DwMobileOfflineRuntime implements DwOfflineRuntime {
  DwMobileOfflineRuntime({
    required DwOfflineDatabase database,
    required DwOfflineAssetStore assetStore,
    required DwDownloadScheduler downloadScheduler,
    required DwOfflineReadDelegate readDelegate,
    required DwOfflineWriteDelegate writeDelegate,
    DwRepo repository = const DwRepo(),
  }) : _database = database,
       _assetStore = assetStore,
       _downloadScheduler = downloadScheduler,
       _readDelegate = readDelegate,
       _writeDelegate = writeDelegate,
       _repository = repository;

  final DwOfflineDatabase _database;
  final DwOfflineAssetStore _assetStore;
  final DwDownloadScheduler _downloadScheduler;
  final DwOfflineReadDelegate _readDelegate;
  final DwOfflineWriteDelegate _writeDelegate;
  final DwRepo _repository;
  String? _activeUserScopeId;
  bool _isInitialized = false;
  bool _isDisposed = false;
  Future<void> _operationTail = Future<void>.value();

  @override
  Future<void> initialize() {
    return _serialize(() async {
      _requireNotDisposed();
      if (_isInitialized) return;
      final existingReadDelegate = _repository.readDelegate;
      final existingWriteDelegate = _repository.writeDelegate;
      if (existingReadDelegate != null &&
          !identical(existingReadDelegate, _readDelegate)) {
        throw StateError('Another repository read delegate is registered.');
      }
      if (existingWriteDelegate != null &&
          !identical(existingWriteDelegate, _writeDelegate)) {
        throw StateError('Another repository write delegate is registered.');
      }
      await _downloadScheduler.initialize();
      _repository.readDelegate = _readDelegate;
      _repository.writeDelegate = _writeDelegate;
      _isInitialized = true;
    });
  }

  @override
  Future<void> activateUserScope(DwOfflineUserScope userScope) {
    return _serialize(() async {
      _requireInitialized();
      if (_activeUserScopeId == userScope.userScopeId) return;
      await _readDelegate.activateUserScope(userScope.userScopeId);
      try {
        await _writeDelegate.activateUserScope(userScope.userScopeId);
        await _downloadScheduler.activateUserScope(userScope.userScopeId);
      } on Object {
        await _rollbackActivation(userScope.userScopeId);
        rethrow;
      }
      _activeUserScopeId = userScope.userScopeId;
    });
  }

  @override
  Future<void> deactivateUserScope(DwOfflineUserScope userScope) {
    return _serialize(() async {
      _requireInitialized();
      await _deactivateScope(userScope.userScopeId);
    });
  }

  /// Selects the small set of user-scoped repository reads that may persist.
  Future<void> retainScopeQueries(Iterable<String> queryStorageKeys) {
    final distinctKeys = Set<String>.of(queryStorageKeys);
    return _serialize(() async {
      _requireInitialized();
      if (_activeUserScopeId == null) {
        throw StateError('Activate an offline user scope first.');
      }
      for (final queryStorageKey in distinctKeys) {
        await _readDelegate.retainScopeQueryStorageKey(queryStorageKey);
      }
    });
  }

  @override
  Future<void> purgeUserScope(DwOfflineUserScope userScope) {
    return _serialize(() async {
      _requireInitialized();
      await _deactivateScope(userScope.userScopeId);
      await _assetStore.purgeUserScope(userScope.userScopeId);
    });
  }

  @override
  Future<void> dispose() {
    return _serialize(() async {
      if (_isDisposed) return;
      final activeUserScopeId = _activeUserScopeId;
      if (_isInitialized && activeUserScopeId != null) {
        await _deactivateScope(activeUserScopeId);
      }
      if (identical(_repository.readDelegate, _readDelegate)) {
        _repository.readDelegate = null;
      }
      if (identical(_repository.writeDelegate, _writeDelegate)) {
        _repository.writeDelegate = null;
      }
      await _downloadScheduler.dispose();
      await _database.close();
      _isInitialized = false;
      _isDisposed = true;
    }, allowDisposed: true);
  }

  Future<void> _deactivateScope(String userScopeId) async {
    if (_activeUserScopeId != null && _activeUserScopeId != userScopeId) {
      throw StateError('Cannot deactivate a different offline user scope.');
    }
    await _downloadScheduler.deactivateUserScope(userScopeId);
    await _readDelegate.deactivateUserScope();
    await _writeDelegate.deactivateUserScope();
    if (_activeUserScopeId == userScopeId) _activeUserScopeId = null;
  }

  Future<void> _rollbackActivation(String userScopeId) async {
    await _downloadScheduler.deactivateUserScope(userScopeId);
    await _readDelegate.deactivateUserScope();
    await _writeDelegate.deactivateUserScope();
  }

  void _requireInitialized() {
    _requireNotDisposed();
    if (!_isInitialized) {
      throw StateError('Initialize the offline runtime first.');
    }
  }

  void _requireNotDisposed() {
    if (_isDisposed) throw StateError('Offline runtime is disposed.');
  }

  Future<T> _serialize<T>(
    Future<T> Function() operation, {
    bool allowDisposed = false,
  }) {
    if (_isDisposed && !allowDisposed) {
      return Future<T>.error(StateError('Offline runtime is disposed.'));
    }
    final queued = _operationTail.then((_) => operation());
    _operationTail = queued.then<void>((_) {}, onError: (_, _) {});
    return queued;
  }
}
