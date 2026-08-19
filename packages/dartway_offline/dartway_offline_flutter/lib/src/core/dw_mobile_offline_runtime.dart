import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';

import '../download/dw_download_scheduler.dart';
import '../repository/dw_offline_local_reads.dart';
import '../repository/dw_offline_local_writes.dart';
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
    required DwOfflineLocalReads localReads,
    required DwOfflineLocalWrites localWrites,
  }) : _database = database,
       _assetStore = assetStore,
       _downloadScheduler = downloadScheduler,
       _localReads = localReads,
       _localWrites = localWrites;

  final DwOfflineDatabase _database;
  final DwOfflineAssetStore _assetStore;
  final DwDownloadScheduler _downloadScheduler;
  final DwOfflineLocalReads _localReads;
  final DwOfflineLocalWrites _localWrites;
  String? _activeUserScopeId;
  bool _isInitialized = false;
  bool _isDisposed = false;
  Future<void> _operationTail = Future<void>.value();

  /// The local copy of reads, offered to `dw.repo` through the plugin.
  ///
  /// `null` until [initialize] and again after [dispose], so the repository
  /// stops reaching a runtime that is closing its database.
  @override
  DwRepoLocalReads? get localReads =>
      _isInitialized && !_isDisposed ? _localReads : null;

  /// The local copy of writes, on the same terms as [localReads].
  @override
  DwRepoLocalWrites? get localWrites =>
      _isInitialized && !_isDisposed ? _localWrites : null;

  @override
  Future<void> initialize() {
    return _serialize(() async {
      _requireNotDisposed();
      if (_isInitialized) return;
      await _downloadScheduler.initialize();
      _isInitialized = true;
    });
  }

  @override
  Future<void> activateUserScope(DwOfflineUserScope userScope) {
    return _serialize(() async {
      _requireInitialized();
      if (_activeUserScopeId == userScope.userScopeId) return;
      await _localReads.activateUserScope(userScope.userScopeId);
      try {
        await _localWrites.activateUserScope(userScope.userScopeId);
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
        await _localReads.retainScopeQueryStorageKey(queryStorageKey);
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
    await _localReads.deactivateUserScope();
    await _localWrites.deactivateUserScope();
    if (_activeUserScopeId == userScopeId) _activeUserScopeId = null;
  }

  Future<void> _rollbackActivation(String userScopeId) async {
    await _downloadScheduler.deactivateUserScope(userScopeId);
    await _localReads.deactivateUserScope();
    await _localWrites.deactivateUserScope();
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
