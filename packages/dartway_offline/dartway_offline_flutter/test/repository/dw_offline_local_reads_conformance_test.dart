import 'package:dartway_offline_flutter/src/repository/dw_offline_local_reads.dart';
import 'package:dartway_offline_flutter/src/storage/dw_offline_database.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The core's own suite, run against the real snapshot store.
///
/// Passing the offline package's own tests says the store does what this
/// package meant. Passing these says it does what `dw.repo` is entitled to
/// assume of any store, including the parts no signature can state.
void main() {
  dwRepoLocalReadsConformance(
    'DwOfflineLocalReads',
    createFixture: () async {
      final database = DwOfflineDatabase(NativeDatabase.memory());
      final localReads = DwOfflineLocalReads(
        database: database,
        packageAccessPolicy: _NoPackagesPolicy(),
      );
      await localReads.activateUserScope('conformance-scope');
      final kept = DwRepoQueryKey<Object>.getAll(
        modelClassName: 'ConformanceModel',
        filters: const {'kept': true},
      );
      await localReads.retainScopeQueryStorageKey(kept.toStorageKey());
      return _DwOfflineLocalReadsFixture(
        database: database,
        localReads: localReads,
        keptQuery: kept,
      );
    },
  );
}

final class _DwOfflineLocalReadsFixture implements DwRepoLocalReadsFixture {
  _DwOfflineLocalReadsFixture({
    required DwOfflineDatabase database,
    required DwOfflineLocalReads localReads,
    required DwRepoQueryKey<Object> keptQuery,
  }) : _database = database,
       _localReads = localReads,
       _keptQuery = keptQuery;

  final DwOfflineDatabase _database;
  final DwOfflineLocalReads _localReads;
  final DwRepoQueryKey<Object> _keptQuery;

  @override
  DwRepoLocalReads get store => _localReads;

  @override
  ({DwRepoQueryKey<Object> queryKey, DwRepoReadSnapshot snapshot}) keptQueryFor(
    DwRepoBinding binding,
  ) => (
    queryKey: _keptQuery,
    snapshot: DwRepoReadSnapshot(
      schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
      scope: binding.scope,
      responseJson: const <String, dynamic>{'isOk': true, 'value': <dynamic>[]},
    ),
  );

  /// This store keeps only what a scope explicitly retained, so anything else
  /// is declined.
  @override
  DwRepoQueryKey<Object>? ignoredQueryFor(DwRepoBinding binding) =>
      DwRepoQueryKey<Object>.getAll(
        modelClassName: 'ConformanceModel',
        filters: const {'kept': false},
      );

  @override
  Future<void> signOut() => _localReads.deactivateUserScope();

  @override
  Future<List<String>> keptStorageKeysFor(DwRepoScope scope) async {
    final rows = await (_database.select(
      _database.dwOfflineSnapshots,
    )..where((row) => row.userScopeId.equals(scope.storageKey))).get();
    return rows.map((row) => row.queryKey).toList();
  }

  @override
  Future<void> dispose() => _database.close();
}

/// No offline packages, so a snapshot is only ever kept by scope retention.
final class _NoPackagesPolicy implements DwOfflineRepositoryReadPolicy {
  @override
  Future<String?> authorizedRepositoryContentDigest({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
  }) async => null;

  @override
  Future<bool> canReadPackage({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
  }) async => false;
}
