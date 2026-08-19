import 'package:dartway_offline_flutter/src/outbox/dw_offline_outbox.dart';
import 'package:dartway_offline_flutter/src/repository/dw_offline_local_writes.dart';
import 'package:dartway_offline_flutter/src/storage/dw_offline_database.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:dartway_serverpod_core_flutter/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The core's own suite, run against the real store.
///
/// Passing the offline package's own tests says the outbox does what this
/// package meant. Passing these says it does what `dw.repo` is entitled to
/// assume of any store, including the parts no signature can state.
void main() {
  dwRepoLocalWritesConformance(
    'DwOfflineLocalWrites',
    createFixture: () async {
      final database = DwOfflineDatabase(NativeDatabase.memory());
      final localWrites = DwOfflineLocalWrites(
        database: database,
        mutationPlanner: _ConformanceMutationPlanner(),
      );
      await localWrites.activateUserScope('conformance-scope');
      return _DwOfflineLocalWritesFixture(
        database: database,
        localWrites: localWrites,
      );
    },
  );
}

final class _DwOfflineLocalWritesFixture implements DwRepoLocalWritesFixture {
  _DwOfflineLocalWritesFixture({
    required DwOfflineDatabase database,
    required DwOfflineLocalWrites localWrites,
  }) : _database = database,
       _localWrites = localWrites,
       _outbox = DwOfflineOutbox(database);

  final DwOfflineDatabase _database;
  final DwOfflineLocalWrites _localWrites;
  final DwOfflineOutbox _outbox;
  var _mutationCount = 0;

  @override
  DwRepoLocalWrites get store => _localWrites;

  @override
  DwRepoMutation mutationFor(DwRepoBinding binding) {
    _mutationCount += 1;
    return DwRepoMutation.save(
      scope: binding.scope,
      className: 'ConformanceModel',
      entityType: 'ConformanceModel',
      entityId: _mutationCount,
      mutationId: 'conformance-$_mutationCount',
      protocolPayload: <String, dynamic>{'id': _mutationCount},
      createdAtUtc: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<void> signOut() => _localWrites.deactivateUserScope();

  @override
  Future<List<DwRepoMutation>> queuedFor(DwRepoScope scope) =>
      _outbox.watchPendingMutations(scope.storageKey).first;

  @override
  Future<void> dispose() => _database.close();
}

final class _ConformanceMutationPlanner implements DwOfflineMutationPlanner {
  @override
  DwOfflineMutationTarget? targetFor(DwRepoMutation mutation) =>
      DwOfflineMutationTarget(
        entityType: mutation.entityType,
        entityId: '${mutation.entityId}',
      );

  @override
  Future<DwRepoWritePlan<DwModelWrapper>?>
  prepareSaveMutation<Model extends SerializableModel>({
    required DwRepoBinding binding,
    required Model model,
    String? apiGroup,
  }) async => null;

  @override
  Future<DwRepoWritePlan<bool>?>
  prepareDeleteMutation<Model extends SerializableModel>({
    required DwRepoBinding binding,
    required Model model,
    String? apiGroup,
  }) async => null;
}
