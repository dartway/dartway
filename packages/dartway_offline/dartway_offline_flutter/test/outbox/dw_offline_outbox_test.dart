import 'dart:async';

import 'package:dartway_offline_flutter/src/outbox/dw_offline_outbox.dart';
import 'package:dartway_offline_flutter/src/repository/dw_offline_local_writes.dart';
import 'package:dartway_offline_flutter/src/storage/dw_offline_database.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DwOfflineDatabase database;
  late _MutationPlanner mutationPlanner;
  late DwOfflineLocalWrites localWrites;
  late DwOfflineOutbox outbox;

  setUp(() async {
    database = DwOfflineDatabase(NativeDatabase.memory());
    mutationPlanner = _MutationPlanner();
    localWrites = DwOfflineLocalWrites(
      database: database,
      mutationPlanner: mutationPlanner,
    );
    outbox = DwOfflineOutbox(database);
    await localWrites.activateUserScope('scope-a');
  });

  tearDown(() async {
    await localWrites.deactivateUserScope();
    await database.close();
  });

  test(
    'enqueue keeps the latest intent and the original queue position',
    () async {
      final binding = (await localWrites.resolveBinding())!;
      await _enqueueIfCurrent(
      localWrites,
        binding: binding,
        mutation: mutation(
          mutationId: 'first',
          desiredCompleted: true,
          createdAtUtc: DateTime.utc(2026, 1, 1),
        ),
      );
      await _enqueueIfCurrent(
      localWrites,
        binding: binding,
        mutation: mutation(
          mutationId: 'latest',
          desiredCompleted: false,
          createdAtUtc: DateTime.utc(2026, 1, 2),
        ),
      );

      final rows = await database.select(database.dwOfflineOutbox).get();
      expect(rows, hasLength(1));
      expect(rows.single.mutationId, 'latest');
      expect(
        rows.single.createdAtEpochMs,
        DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
      );
    },
  );

  test('pending mutation stream restores the latest durable intent', () async {
    final binding = (await localWrites.resolveBinding())!;
    final pending = outbox
        .watchPendingMutations('scope-a')
        .firstWhere((mutations) => mutations.isNotEmpty);

    await _enqueueIfCurrent(
      localWrites,
      binding: binding,
      mutation: mutation(mutationId: 'first', desiredCompleted: true),
    );
    await _enqueueIfCurrent(
      localWrites,
      binding: binding,
      mutation: mutation(mutationId: 'latest', desiredCompleted: false),
    );

    final mutations = await pending;
    expect(mutations, hasLength(1));
    expect(mutations.single.mutationId, anyOf('first', 'latest'));

    final latest = await outbox
        .watchPendingMutations('scope-a')
        .firstWhere((items) => items.singleOrNull?.mutationId == 'latest');
    expect(latest.single.protocolPayload['completed'], isFalse);
    expect(() => outbox.watchPendingMutations(' scope-a'), throwsArgumentError);
  });

  test('mutation outside the application allowlist is rejected', () async {
    mutationPlanner.allowMutations = false;
    final binding = (await localWrites.resolveBinding())!;

    await expectLater(
      _enqueueIfCurrent(
      localWrites,
        binding: binding,
        mutation: mutation(mutationId: 'not-allowed'),
      ),
      throwsStateError,
    );
    expect(await database.select(database.dwOfflineOutbox).get(), isEmpty);
  });

  test(
    'accepted replay is sequential and removes acknowledged mutations',
    () async {
      final binding = (await localWrites.resolveBinding())!;
      await _enqueueIfCurrent(
      localWrites,
        binding: binding,
        mutation: mutation(mutationId: 'first', targetId: 'resource-1'),
      );
      await _enqueueIfCurrent(
      localWrites,
        binding: binding,
        mutation: mutation(mutationId: 'second', targetId: 'resource-2'),
      );
      final replayedIds = <String>[];

      final outcomes = await outbox.replay(
        userScopeId: 'scope-a',
        transport: (queuedMutation) async {
          replayedIds.add(queuedMutation.mutationId);
          return const DwOutboxReplayResult.accepted();
        },
      );

      expect(replayedIds, ['first', 'second']);
      expect(
        outcomes.map((outcome) => outcome.status),
        everyElement(DwOutboxReplayStatus.accepted),
      );
      expect(await database.select(database.dwOfflineOutbox).get(), isEmpty);
    },
  );

  test('device clock rollback cannot reorder later queued mutations', () async {
    final binding = (await localWrites.resolveBinding())!;
    await _enqueueIfCurrent(
      localWrites,
      binding: binding,
      mutation: mutation(
        mutationId: 'first',
        targetId: 'resource-1',
        createdAtUtc: DateTime.utc(2026, 1, 2),
      ),
    );
    await _enqueueIfCurrent(
      localWrites,
      binding: binding,
      mutation: mutation(
        mutationId: 'second',
        targetId: 'resource-2',
        createdAtUtc: DateTime.utc(2026, 1, 1),
      ),
    );
    final replayedIds = <String>[];

    await outbox.replay(
      userScopeId: 'scope-a',
      transport: (queuedMutation) async {
        replayedIds.add(queuedMutation.mutationId);
        return const DwOutboxReplayResult.accepted();
      },
    );

    expect(replayedIds, ['first', 'second']);
  });

  test('connection failure keeps the queue and stops later replay', () async {
    final binding = (await localWrites.resolveBinding())!;
    await _enqueueIfCurrent(
      localWrites,
      binding: binding,
      mutation: mutation(mutationId: 'first', targetId: 'resource-1'),
    );
    await _enqueueIfCurrent(
      localWrites,
      binding: binding,
      mutation: mutation(mutationId: 'second', targetId: 'resource-2'),
    );
    final replayedIds = <String>[];

    final outcomes = await outbox.replay(
      userScopeId: 'scope-a',
      transport: (queuedMutation) async {
        replayedIds.add(queuedMutation.mutationId);
        return const DwOutboxReplayResult.connectionFailure();
      },
    );

    expect(replayedIds, ['first']);
    expect(outcomes.single.status, DwOutboxReplayStatus.connectionFailure);
    expect(await database.select(database.dwOfflineOutbox).get(), hasLength(2));
  });

  test(
    'acknowledging an old intent never deletes a newer coalesced intent',
    () async {
      final binding = (await localWrites.resolveBinding())!;
      await _enqueueIfCurrent(
      localWrites,
        binding: binding,
        mutation: mutation(mutationId: 'first'),
      );
      final replayStarted = Completer<void>();
      final allowReplay = Completer<void>();
      final replay = outbox.replay(
        userScopeId: 'scope-a',
        transport: (queuedMutation) async {
          replayStarted.complete();
          await allowReplay.future;
          return const DwOutboxReplayResult.accepted();
        },
      );
      await replayStarted.future;

      await _enqueueIfCurrent(
      localWrites,
        binding: binding,
        mutation: mutation(mutationId: 'latest', desiredCompleted: false),
      );
      allowReplay.complete();
      await replay;

      final rows = await database.select(database.dwOfflineOutbox).get();
      expect(rows, hasLength(1));
      expect(rows.single.mutationId, 'latest');
    },
  );
}

DwRepoMutation mutation({
  required String mutationId,
  String targetId = 'resource-42',
  bool desiredCompleted = true,
  DateTime? createdAtUtc,
}) {
  return DwRepoMutation.save(
    scope: DwRepoScope('scope-a'),
    className: 'AccountResourceState',
    entityType: 'AccountResourceState',
    mutationId: mutationId,
    protocolPayload: {'resourceId': 42, 'completed': desiredCompleted},
    opaqueMetadata: {'offlineTargetId': targetId},
    createdAtUtc: createdAtUtc ?? DateTime.utc(2026, 1, 1),
  );
}

final class _MutationPlanner implements DwOfflineMutationPlanner {
  bool allowMutations = true;

  @override
  DwOfflineMutationTarget? targetFor(DwRepoMutation mutation) {
    if (!allowMutations) return null;
    return DwOfflineMutationTarget(
      entityType: mutation.entityType,
      entityId: mutation.opaqueMetadata!['offlineTargetId']! as String,
    );
  }

  @override
  Future<DwRepoWritePlan<bool>?>
  prepareDeleteMutation<Model extends SerializableModel>({
    required DwRepoBinding binding,
    required Model model,
    String? apiGroup,
  }) async => null;

  @override
  Future<DwRepoWritePlan<DwModelWrapper>?>
  prepareSaveMutation<Model extends SerializableModel>({
    required DwRepoBinding binding,
    required Model model,
    String? apiGroup,
  }) async => null;
}

/// The core's own enqueue body, so these tests exercise the same order of
/// operations `dw.repo` does rather than a shortcut of their own.
Future<DwRepoEnqueue> _enqueueIfCurrent(
  DwOfflineLocalWrites localWrites, {
  required DwRepoBinding binding,
  required DwRepoMutation mutation,
}) {
  return localWrites.write<DwRepoEnqueue>((tx) async {
    if (!await tx.isBindingCurrent(binding)) return DwRepoEnqueue.stale;
    await tx.enqueue(mutation);
    return DwRepoEnqueue.accepted;
  });
}
