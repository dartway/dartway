import 'dart:convert';

import 'package:dartway_offline_shared/dartway_offline_shared.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:drift/drift.dart';

import '../access/dw_offline_lease_policy.dart';
import '../storage/dw_offline_database.dart';

abstract interface class DwOfflinePackageAccessPolicy {
  Future<bool> canReadPackage({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
  });
}

abstract interface class DwOfflineRepositoryReadPolicy
    implements DwOfflinePackageAccessPolicy {
  Future<String?> authorizedRepositoryContentDigest({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
  });
}

/// Persists only explicitly selected repository states.
final class DwOfflineLocalReads implements DwRepoLocalReads {
  DwOfflineLocalReads({
    required DwOfflineDatabase database,
    required DwOfflineRepositoryReadPolicy packageAccessPolicy,
  }) : _database = database,
       _packageAccessPolicy = packageAccessPolicy;

  final DwOfflineDatabase _database;
  final DwOfflineRepositoryReadPolicy _packageAccessPolicy;
  final Set<String> _scopeQueryKeys = {};
  Future<void> _operationTail = Future<void>.value();
  DwRepoBinding? _currentBinding;

  Future<void> activateUserScope(String userScopeId) {
    return _serialize(() async {
      final scope = DwRepoScope(userScopeId);
      if (_currentBinding?.scope == scope) return;
      _currentBinding?.invalidate();
      _scopeQueryKeys.clear();
      _currentBinding = DwRepoBinding(scope: scope);
    });
  }

  Future<void> deactivateUserScope() {
    return _serialize(() async {
      _currentBinding?.invalidate();
      _currentBinding = null;
      _scopeQueryKeys.clear();
    });
  }

  Future<void> retainScopeQuery<Model>(DwRepoQueryKey<Model> queryKey) {
    return retainScopeQueryStorageKey(queryKey.toStorageKey());
  }

  Future<void> retainScopeQueryStorageKey(String queryStorageKey) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(queryStorageKey)) {
      throw ArgumentError.value(
        queryStorageKey,
        'queryStorageKey',
        'must be a lowercase SHA-256 key',
      );
    }
    return _serialize(() async {
      _requireActiveBinding();
      _scopeQueryKeys.add(queryStorageKey);
    });
  }

  Future<void> installPackageSnapshot<Model>({
    required DwVerifiedOfflineManifest verifiedManifest,
    required DwRepoQueryKey<Model> queryKey,
    required DwRepoReadSnapshot snapshot,
  }) => installPackageSnapshotStorageKey(
    verifiedManifest: verifiedManifest,
    queryStorageKey: queryKey.toStorageKey(),
    snapshot: snapshot,
  );

  Future<void> installPackageSnapshotStorageKey({
    required DwVerifiedOfflineManifest verifiedManifest,
    required String queryStorageKey,
    required DwRepoReadSnapshot snapshot,
  }) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(queryStorageKey)) {
      throw ArgumentError.value(
        queryStorageKey,
        'queryStorageKey',
        'must be a lowercase SHA-256 key',
      );
    }
    return _serialize(() async {
      final binding = _requireActiveBinding();
      final manifest = verifiedManifest.manifest;
      if (binding.scope.storageKey != manifest.userScopeId ||
          snapshot.scope != binding.scope ||
          snapshot.schemaVersion != DwRepoReadSnapshot.currentSchemaVersion) {
        throw StateError('Package snapshot binding does not match.');
      }
      await _database
          .into(_database.dwOfflinePackageSnapshots)
          .insertOnConflictUpdate(
            DwOfflinePackageSnapshotsCompanion.insert(
              userScopeId: manifest.userScopeId,
              packageId: manifest.packageId,
              manifestRevision: manifest.manifestRevision,
              queryKey: queryStorageKey,
              envelopeJson: jsonEncode(snapshot.responseJson),
              capturedAtEpochMs: DateTime.now().toUtc().millisecondsSinceEpoch,
            ),
          );
    });
  }

  /// Atomically replaces the exact repository snapshot set of one manifest.
  Future<void> replacePackageSnapshotsStorageKeys({
    required DwVerifiedOfflineManifest verifiedManifest,
    required Map<String, DwRepoReadSnapshot> snapshotsByStorageKey,
  }) {
    for (final queryStorageKey in snapshotsByStorageKey.keys) {
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(queryStorageKey)) {
        throw ArgumentError.value(
          queryStorageKey,
          'queryStorageKey',
          'must be a lowercase SHA-256 key',
        );
      }
    }
    return _serialize(() async {
      final binding = _requireActiveBinding();
      final manifest = verifiedManifest.manifest;
      if (binding.scope.storageKey != manifest.userScopeId ||
          snapshotsByStorageKey.values.any(
            (snapshot) =>
                snapshot.scope != binding.scope ||
                snapshot.schemaVersion !=
                    DwRepoReadSnapshot.currentSchemaVersion,
          )) {
        throw StateError('Package snapshot binding does not match.');
      }
      final capturedAtEpochMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      await _database.transaction(() async {
        await (_database.delete(_database.dwOfflinePackageSnapshots)..where(
              (row) =>
                  row.userScopeId.equals(manifest.userScopeId) &
                  row.packageId.equals(manifest.packageId) &
                  row.manifestRevision.equals(manifest.manifestRevision),
            ))
            .go();
        for (final entry in snapshotsByStorageKey.entries) {
          await _database
              .into(_database.dwOfflinePackageSnapshots)
              .insert(
                DwOfflinePackageSnapshotsCompanion.insert(
                  userScopeId: manifest.userScopeId,
                  packageId: manifest.packageId,
                  manifestRevision: manifest.manifestRevision,
                  queryKey: entry.key,
                  envelopeJson: jsonEncode(entry.value.responseJson),
                  capturedAtEpochMs: capturedAtEpochMs,
                ),
              );
        }
      });
    });
  }

  @override
  Future<DwRepoBinding?> resolveBinding() async => _currentBinding;

  @override
  Future<bool> isBindingCurrent(DwRepoBinding binding) async {
    return binding.isActive && identical(binding, _currentBinding);
  }

  @override
  Future<DwRepoReadSnapshot?> loadSnapshot<Model>({
    required DwRepoBinding binding,
    required DwRepoQueryKey<Model> queryKey,
  }) {
    return _serialize(() async {
      if (!_isCurrent(binding)) return null;
      final storageKey = queryKey.toStorageKey();
      final scopeSnapshot = await _loadScopeSnapshot(binding, storageKey);
      if (scopeSnapshot != null) return scopeSnapshot;
      return _loadPackageSnapshot(binding, storageKey);
    });
  }

  @override
  Future<R> keep<R>(Future<R> Function(DwRepoLocalReadTx tx) body) {
    // Two layers, and both are needed. `_serialize` orders this against
    // `activateUserScope` / `deactivateUserScope`, so a sign-out cannot land
    // between the binding check and the row write; the drift transaction makes
    // the row write itself atomic with whatever else the body did.
    return _serialize(
      () => _database.transaction(() => body(_DwOfflineReadTx(this))),
    );
  }

  Future<bool> _storeSnapshot<Model>({
    required DwRepoQueryKey<Model> queryKey,
    required DwRepoReadSnapshot snapshot,
  }) async {
    final binding = _currentBinding;
    if (binding == null) {
      throw StateError('Offline snapshots have no active user scope.');
    }
    final storageKey = queryKey.toStorageKey();
    // Not every read is worth keeping, and this store keeps only the handful a
    // scope explicitly asked for. Declining is an ordinary answer.
    if (!_scopeQueryKeys.contains(storageKey)) return false;
    if (snapshot.scope != binding.scope ||
        snapshot.schemaVersion != DwRepoReadSnapshot.currentSchemaVersion) {
      throw StateError('Repository snapshot binding does not match.');
    }
    await _database
        .into(_database.dwOfflineSnapshots)
        .insertOnConflictUpdate(
          DwOfflineSnapshotsCompanion.insert(
            userScopeId: binding.scope.storageKey,
            queryKey: storageKey,
            envelopeJson: jsonEncode(snapshot.responseJson),
            capturedAtEpochMs: DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
        );
    return true;
  }

  Future<DwRepoReadSnapshot?> _loadScopeSnapshot(
    DwRepoBinding binding,
    String queryKey,
  ) async {
    if (!_scopeQueryKeys.contains(queryKey)) return null;
    final row =
        await (_database.select(_database.dwOfflineSnapshots)..where(
              (snapshot) =>
                  snapshot.userScopeId.equals(binding.scope.storageKey) &
                  snapshot.queryKey.equals(queryKey),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    final expiresAt = row.expiresAtEpochMs;
    if (expiresAt != null &&
        expiresAt <= DateTime.now().toUtc().millisecondsSinceEpoch) {
      return null;
    }
    final snapshot = _decodeSnapshot(binding.scope, row.envelopeJson);
    if (snapshot != null) return snapshot;
    await (_database.delete(_database.dwOfflineSnapshots)..where(
          (storedSnapshot) =>
              storedSnapshot.userScopeId.equals(binding.scope.storageKey) &
              storedSnapshot.queryKey.equals(queryKey),
        ))
        .go();
    return null;
  }

  Future<DwRepoReadSnapshot?> _loadPackageSnapshot(
    DwRepoBinding binding,
    String queryKey,
  ) async {
    final joined =
        _database.select(_database.dwOfflinePackageSnapshots).join([
          innerJoin(
            _database.dwOfflinePackages,
            _database.dwOfflinePackages.userScopeId.equalsExp(
                  _database.dwOfflinePackageSnapshots.userScopeId,
                ) &
                _database.dwOfflinePackages.packageId.equalsExp(
                  _database.dwOfflinePackageSnapshots.packageId,
                ) &
                _database.dwOfflinePackages.activeManifestRevision.equalsExp(
                  _database.dwOfflinePackageSnapshots.manifestRevision,
                ),
          ),
        ])..where(
          _database.dwOfflinePackageSnapshots.userScopeId.equals(
                binding.scope.storageKey,
              ) &
              _database.dwOfflinePackageSnapshots.queryKey.equals(queryKey),
        );
    final rows = await joined.get();
    rows.sort((left, right) {
      final leftPackage = left.readTable(_database.dwOfflinePackages);
      final rightPackage = right.readTable(_database.dwOfflinePackages);
      final updatedAtComparison = rightPackage.updatedAtEpochMs.compareTo(
        leftPackage.updatedAtEpochMs,
      );
      if (updatedAtComparison != 0) return updatedAtComparison;
      return leftPackage.packageId.compareTo(rightPackage.packageId);
    });
    final authorizedSnapshots = <DwRepoReadSnapshot>[];
    final packageIntegrity = <String, bool>{};
    for (final result in rows) {
      final packageSnapshot = result.readTable(
        _database.dwOfflinePackageSnapshots,
      );
      final repositoryContentDigest = await _packageAccessPolicy
          .authorizedRepositoryContentDigest(
            userScopeId: packageSnapshot.userScopeId,
            packageId: packageSnapshot.packageId,
            manifestRevision: packageSnapshot.manifestRevision,
          );
      if (repositoryContentDigest == null) {
        continue;
      }
      final integrityKey =
          '${packageSnapshot.userScopeId}\u0000'
          '${packageSnapshot.packageId}\u0000'
          '${packageSnapshot.manifestRevision}\u0000'
          '$repositoryContentDigest';
      final matchesSignedContent = packageIntegrity[integrityKey] ??=
          await _packageSnapshotSetMatchesSignedContent(
            packageSnapshot,
            repositoryContentDigest,
          );
      if (!matchesSignedContent) continue;
      final snapshot = _decodeSnapshot(
        binding.scope,
        packageSnapshot.envelopeJson,
      );
      if (snapshot != null) authorizedSnapshots.add(snapshot);
    }
    if (authorizedSnapshots.isEmpty) return null;
    if (authorizedSnapshots.length == 1) return authorizedSnapshots.single;
    return _mergeListSnapshots(binding.scope, authorizedSnapshots) ??
        authorizedSnapshots.first;
  }

  Future<bool> _packageSnapshotSetMatchesSignedContent(
    DwOfflinePackageSnapshotRow packageSnapshot,
    String repositoryContentDigest,
  ) async {
    final manifestRevision = packageSnapshot.manifestRevision;
    final rows =
        await (_database.select(_database.dwOfflinePackageSnapshots)..where(
              (row) =>
                  row.userScopeId.equals(packageSnapshot.userScopeId) &
                  row.packageId.equals(packageSnapshot.packageId) &
                  row.manifestRevision.equals(manifestRevision),
            ))
            .get();
    final responses = <Map<String, Object?>>[];
    for (final row in rows) {
      final decoded = _decodeSnapshot(
        DwRepoScope(packageSnapshot.userScopeId),
        row.envelopeJson,
      );
      if (decoded == null) return false;
      responses.add(Map<String, Object?>.from(decoded.responseJson));
    }
    try {
      return DwOfflineRepositoryContentRevision.computeFromRepositoryResponses(
            responses,
          ) ==
          repositoryContentDigest;
    } on ArgumentError {
      return false;
    } on FormatException {
      return false;
    }
  }

  static DwRepoReadSnapshot? _mergeListSnapshots(
    DwRepoScope scope,
    List<DwRepoReadSnapshot> snapshots,
  ) {
    final values = snapshots
        .map((snapshot) => snapshot.responseJson['value'])
        .toList(growable: false);
    if (values.any((value) => value is! List)) return null;
    final mergedValues = <Object?>[];
    final seenIdentities = <String>{};
    for (final value in values.cast<List>()) {
      for (final item in value) {
        final identity = _snapshotListItemIdentity(item);
        if (seenIdentities.add(identity)) mergedValues.add(item);
      }
    }
    return DwRepoReadSnapshot(
      schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
      scope: scope,
      responseJson: <String, dynamic>{
        ...snapshots.first.responseJson,
        'value': mergedValues,
      },
    );
  }

  static String _snapshotListItemIdentity(Object? item) {
    if (item case {
      'className': final Object? className,
      'data': final Map data,
    }) {
      final modelId = data['id'];
      if (className is String && modelId != null) {
        return 'model:$className:$modelId';
      }
    }
    return 'json:${jsonEncode(item)}';
  }

  static DwRepoReadSnapshot? _decodeSnapshot(
    DwRepoScope scope,
    String envelopeJson,
  ) {
    try {
      final decoded = jsonDecode(envelopeJson);
      if (decoded is! Map) return null;
      return DwRepoReadSnapshot(
        schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
        scope: scope,
        responseJson: Map<String, dynamic>.from(decoded),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  DwRepoBinding _requireActiveBinding() {
    final binding = _currentBinding;
    if (binding == null || !binding.isActive) {
      throw StateError('Activate an offline user scope first.');
    }
    return binding;
  }

  bool _isCurrent(DwRepoBinding binding) {
    return binding.isActive && identical(binding, _currentBinding);
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final queued = _operationTail.then((_) => operation());
    _operationTail = queued.then<void>((_) {}, onError: (_, _) {});
    return queued;
  }
}

final class _DwOfflineReadTx implements DwRepoLocalReadTx {
  const _DwOfflineReadTx(this._store);

  final DwOfflineLocalReads _store;

  @override
  Future<bool> isBindingCurrent(DwRepoBinding binding) async =>
      binding.isActive && identical(binding, _store._currentBinding);

  @override
  Future<bool> storeSnapshot<Model>({
    required DwRepoQueryKey<Model> queryKey,
    required DwRepoReadSnapshot snapshot,
  }) => _store._storeSnapshot(queryKey: queryKey, snapshot: snapshot);
}
