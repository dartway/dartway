import 'dart:async';
import 'dart:io';

import 'package:dartway_offline_flutter/dartway_offline_flutter.dart';
import 'package:dartway_offline_flutter/src/download/dw_background_download_transport.dart';
import 'package:dartway_offline_flutter/src/download/dw_download_asset_publisher.dart';
import 'package:dartway_offline_flutter/src/download/dw_download_job_store.dart';
import 'package:dartway_offline_flutter/src/download/dw_download_scheduler.dart';
import 'package:dartway_offline_flutter/src/network/dw_network_class.dart';
import 'package:dartway_offline_flutter/src/repository/dw_offline_local_reads.dart';
import 'package:dartway_offline_flutter/src/repository/dw_offline_local_writes.dart';
import 'package:dartway_offline_flutter/src/storage/disk_space_plus_source.dart';
import 'package:dartway_offline_flutter/src/storage/dw_offline_asset_store.dart';
import 'package:dartway_offline_flutter/src/storage/dw_offline_database.dart';
import 'package:dartway_offline_shared/dartway_offline_shared.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory supportDirectory;
  late DwOfflineDatabase database;
  late DwOfflineLocalReads localReads;
  late DwOfflineLocalWrites localWrites;
  late _Transport transport;
  late DwMobileOfflineRuntime runtime;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'dw_mobile_runtime_',
    );
    database = DwOfflineDatabase(NativeDatabase.memory());
    final assetStore = DwOfflineAssetStore(
      applicationSupportDirectory: supportDirectory,
      database: database,
    );
    localReads = DwOfflineLocalReads(
      database: database,
      packageAccessPolicy: _AllowPackageAccess(),
    );
    localWrites = DwOfflineLocalWrites(
      database: database,
      mutationPlanner: _NoOfflineMutations(),
    );
    transport = _Transport();
    final scheduler = DwDownloadScheduler(
      jobStore: DwDownloadJobStore(database),
      transport: transport,
      networkSource: _NetworkSource(),
      diskSpaceSource: _DiskSpaceSource(),
      assetPublisher: DwOfflineAssetStorePublisher(assetStore),
      nowEpochMs: () => 1000,
    );
    runtime = DwMobileOfflineRuntime(
      database: database,
      assetStore: assetStore,
      downloadScheduler: scheduler,
      localReads: localReads,
      localWrites: localWrites,
    );
  });

  tearDown(() async {
    await runtime.dispose();
    await supportDirectory.delete(recursive: true);
  });

  test('offers the local store and activates one shared user scope', () async {
    await runtime.initialize();
    await runtime.activateUserScope(DwOfflineUserScope(userScopeId: 'scope-a'));

    expect(runtime.localReads, same(localReads));
    expect(runtime.localWrites, same(localWrites));
    expect((await localReads.resolveBinding())!.scope.storageKey, 'scope-a');
    expect((await localWrites.resolveBinding())!.scope.storageKey, 'scope-a');
    expect(transport.initializeCalls, 1);
  });

  test('retains only explicitly selected scope query keys', () async {
    await runtime.initialize();
    await runtime.activateUserScope(DwOfflineUserScope(userScopeId: 'scope-a'));
    final retainedQuery = DwRepoQueryKey<Object>.getAll(
      modelClassName: 'AccountResourceState',
      filters: const {'userProfileId': 7},
    );
    final ignoredQuery = DwRepoQueryKey<Object>.getAll(
      modelClassName: 'AppSettings',
    );

    await runtime.retainScopeQueries({retainedQuery.toStorageKey()});
    final binding = (await localReads.resolveBinding())!;

    expect(
      await _keepIfCurrent(
        localReads,
        binding: binding,
        queryKey: retainedQuery,
        snapshot: DwRepoReadSnapshot(
          schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
          scope: binding.scope,
          responseJson: const {'isOk': true, 'value': []},
        ),
      ),
      DwRepoReadSnapshotStoreResult.stored,
    );
    expect(
      await _keepIfCurrent(
        localReads,
        binding: binding,
        queryKey: ignoredQuery,
        snapshot: DwRepoReadSnapshot(
          schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
          scope: binding.scope,
          responseJson: const {'isOk': true, 'value': []},
        ),
      ),
      DwRepoReadSnapshotStoreResult.ignored,
    );
  });

  test(
    'purge deactivates repository access before deleting scope rows',
    () async {
      await runtime.initialize();
      final scope = DwOfflineUserScope(userScopeId: 'scope-a');
      await runtime.activateUserScope(scope);
      await database
          .into(database.dwOfflineSnapshots)
          .insert(
            DwOfflineSnapshotsCompanion.insert(
              userScopeId: scope.userScopeId,
              queryKey: 'query-a',
              envelopeJson: '{}',
              capturedAtEpochMs: 1000,
            ),
          );

      await runtime.purgeUserScope(scope);

      expect(await localReads.resolveBinding(), null);
      expect(await localWrites.resolveBinding(), null);
      expect(await database.select(database.dwOfflineSnapshots).get(), isEmpty);
    },
  );

  test('dispose stops offering the local store and owns scheduler lifecycle', () async {
    await runtime.initialize();

    await runtime.dispose();

    expect(runtime.localReads, isNull);
    expect(runtime.localWrites, isNull);
    expect(transport.disposeCalls, 1);
    await expectLater(
      runtime.activateUserScope(DwOfflineUserScope(userScopeId: 'scope-a')),
      throwsA(isA<StateError>()),
    );
  });
}

final class _AllowPackageAccess implements DwOfflineRepositoryReadPolicy {
  @override
  Future<String?> authorizedRepositoryContentDigest({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
  }) async => DwOfflineRepositoryContentRevision.compute(const []);

  @override
  Future<bool> canReadPackage({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
  }) async => true;
}

final class _NoOfflineMutations implements DwOfflineMutationPlanner {
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

  @override
  DwOfflineMutationTarget? targetFor(DwRepoMutation mutation) => null;
}

final class _NetworkSource implements DwNetworkClassSource {
  @override
  Future<DwNetworkClass> currentNetworkClass() async =>
      DwNetworkClass.unmetered;

  @override
  Stream<DwNetworkClass> get networkClassChanges => const Stream.empty();
}

final class _DiskSpaceSource implements DwDiskSpaceSource {
  @override
  Future<DwDiskSpaceSnapshot> read() async => DwDiskSpaceSnapshot(
    freeBytes: BigInt.from(1024 * 1024 * 1024),
    totalBytes: BigInt.from(2 * 1024 * 1024 * 1024),
  );
}

final class _Transport implements DwBackgroundDownloadTransport {
  final _updates = StreamController<DwBackgroundDownloadUpdate>.broadcast();
  int initializeCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<DwBackgroundDownloadUpdate> get updates => _updates.stream;

  @override
  Future<void> initialize() async => initializeCalls += 1;

  @override
  Future<Set<String>> activeTaskIds() async => {};

  @override
  Future<bool> cancel(String taskId) async => true;

  @override
  Future<bool> enqueue(DwBackgroundDownloadRequest request) async => true;

  @override
  Future<bool> pause(String taskId) async => true;

  @override
  Future<bool> resume(String taskId) async => true;

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    await _updates.close();
  }
}

/// The core's own snapshot-commit body, so these tests exercise the same order
/// of operations `dw.repo` does rather than a shortcut of their own.
Future<DwRepoReadSnapshotStoreResult> _keepIfCurrent<Model>(
  DwOfflineLocalReads localReads, {
  required DwRepoBinding binding,
  required DwRepoQueryKey<Model> queryKey,
  required DwRepoReadSnapshot snapshot,
}) {
  return localReads.keep<DwRepoReadSnapshotStoreResult>((tx) async {
    if (!await tx.isBindingCurrent(binding)) {
      return DwRepoReadSnapshotStoreResult.stale;
    }
    final kept = await tx.storeSnapshot(queryKey: queryKey, snapshot: snapshot);
    return kept
        ? DwRepoReadSnapshotStoreResult.stored
        : DwRepoReadSnapshotStoreResult.ignored;
  });
}
