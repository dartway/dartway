import 'dart:async';

import 'package:dartway_offline/src/network/dw_network_class.dart';
import 'package:dartway_offline/src/outbox/dw_offline_outbox.dart';
import 'package:dartway_offline/src/outbox/dw_offline_outbox_synchronizer.dart';
import 'package:dartway_offline/src/repository/dw_offline_write_delegate.dart';
import 'package:dartway_offline/src/storage/dw_offline_database.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DwOfflineDatabase database;
  late DwOfflineWriteDelegate writeDelegate;
  late _NetworkSource networkSource;

  setUp(() async {
    database = DwOfflineDatabase(NativeDatabase.memory());
    writeDelegate = DwOfflineWriteDelegate(
      database: database,
      mutationPlanner: _MutationPlanner(),
    );
    await writeDelegate.activateUserScope('scope-a');
    networkSource = _NetworkSource();
  });

  tearDown(() async {
    await networkSource.dispose();
    await writeDelegate.deactivateUserScope();
    await database.close();
  });

  test('replays the active scope when connectivity returns', () async {
    await _enqueueMutation(writeDelegate);
    final replayedMutations = <String>[];
    final synchronizer = DwOfflineOutboxSynchronizer(
      outbox: DwOfflineOutbox(database),
      networkSource: networkSource,
      replayTransport: (mutation) async {
        replayedMutations.add(mutation.mutationId);
        return const DwOutboxReplayResult.accepted();
      },
    );
    await synchronizer.initialize();
    await synchronizer.activateUserScope('scope-a');

    networkSource.emit(DwNetworkClass.unmetered);
    await synchronizer.synchronizeNow();

    expect(replayedMutations, ['mutation-a']);
    expect(await database.select(database.dwOfflineOutbox).get(), isEmpty);
    await synchronizer.dispose();
  });

  test('scope deactivation retains an in-flight acknowledgement', () async {
    await _enqueueMutation(writeDelegate);
    final replayStarted = Completer<void>();
    final allowReplay = Completer<void>();
    final synchronizer = DwOfflineOutboxSynchronizer(
      outbox: DwOfflineOutbox(database),
      networkSource: networkSource,
      replayTransport: (mutation) async {
        replayStarted.complete();
        await allowReplay.future;
        return const DwOutboxReplayResult.accepted();
      },
    );
    await synchronizer.initialize();
    await synchronizer.activateUserScope('scope-a');
    networkSource.emit(DwNetworkClass.unmetered);
    await replayStarted.future;

    final deactivation = synchronizer.deactivateUserScope('scope-a');
    allowReplay.complete();
    await deactivation;

    expect(await database.select(database.dwOfflineOutbox).get(), hasLength(1));
    await synchronizer.dispose();
  });

  test('failed activation does not retain the attempted scope', () async {
    final synchronizer = DwOfflineOutboxSynchronizer(
      outbox: DwOfflineOutbox(database),
      networkSource: networkSource,
      replayTransport: (_) async => const DwOutboxReplayResult.accepted(),
    );
    await synchronizer.initialize();
    networkSource.failNextRead = true;

    await expectLater(
      synchronizer.activateUserScope('scope-a'),
      throwsStateError,
    );
    await expectLater(synchronizer.deactivateUserScope('scope-b'), completes);

    await synchronizer.dispose();
  });
}

Future<void> _enqueueMutation(DwOfflineWriteDelegate writeDelegate) async {
  final binding = (await writeDelegate.resolveBinding())!;
  await writeDelegate.enqueueMutationIfCurrent(
    binding: binding,
    mutation: DwRepoMutation.save(
      scope: DwRepoScope('scope-a'),
      className: 'AccountResourceState',
      entityType: 'AccountResourceState',
      mutationId: 'mutation-a',
      protocolPayload: const {'resourceId': 42},
      opaqueMetadata: const {'offlineTargetId': 'resource-42'},
    ),
  );
}

final class _NetworkSource implements DwNetworkClassSource {
  final StreamController<DwNetworkClass> _changes =
      StreamController.broadcast();
  DwNetworkClass current = DwNetworkClass.offline;
  bool failNextRead = false;

  @override
  Future<DwNetworkClass> currentNetworkClass() async {
    if (failNextRead) {
      failNextRead = false;
      throw StateError('Network read failed.');
    }
    return current;
  }

  @override
  Stream<DwNetworkClass> get networkClassChanges => _changes.stream;

  void emit(DwNetworkClass networkClass) {
    current = networkClass;
    _changes.add(networkClass);
  }

  Future<void> dispose() => _changes.close();
}

final class _MutationPlanner implements DwOfflineMutationPlanner {
  @override
  Future<DwRepoWritePlan<bool>?>
  prepareDeleteMutation<Model extends SerializableModel>({
    required DwRepoWriteBinding binding,
    required Model model,
    String? apiGroup,
  }) async => null;

  @override
  Future<DwRepoWritePlan<DwModelWrapper>?>
  prepareSaveMutation<Model extends SerializableModel>({
    required DwRepoWriteBinding binding,
    required Model model,
    String? apiGroup,
  }) async => null;

  @override
  DwOfflineMutationTarget? targetFor(DwRepoMutation mutation) =>
      DwOfflineMutationTarget(
        entityType: mutation.entityType,
        entityId: mutation.opaqueMetadata!['offlineTargetId']! as String,
      );
}
