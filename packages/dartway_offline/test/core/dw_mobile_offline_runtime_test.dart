import 'dart:async';
import 'dart:io';

import 'package:dartway_offline/dartway_offline.dart';
import 'package:dartway_offline/src/download/dw_background_download_transport.dart';
import 'package:dartway_offline/src/download/dw_download_asset_publisher.dart';
import 'package:dartway_offline/src/download/dw_download_job_store.dart';
import 'package:dartway_offline/src/download/dw_download_scheduler.dart';
import 'package:dartway_offline/src/network/dw_network_class.dart';
import 'package:dartway_offline/src/repository/dw_offline_read_delegate.dart';
import 'package:dartway_offline/src/repository/dw_offline_write_delegate.dart';
import 'package:dartway_offline/src/storage/disk_space_plus_source.dart';
import 'package:dartway_offline/src/storage/dw_offline_asset_store.dart';
import 'package:dartway_offline/src/storage/dw_offline_database.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory supportDirectory;
  late DwOfflineDatabase database;
  late DwOfflineReadDelegate readDelegate;
  late DwOfflineWriteDelegate writeDelegate;
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
    readDelegate = DwOfflineReadDelegate(
      database: database,
      packageAccessPolicy: _AllowPackageAccess(),
    );
    writeDelegate = DwOfflineWriteDelegate(
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
      readDelegate: readDelegate,
      writeDelegate: writeDelegate,
    );
  });

  tearDown(() async {
    if (const DwRepo().readDelegate == readDelegate ||
        const DwRepo().writeDelegate == writeDelegate) {
      await runtime.dispose();
    }
    await supportDirectory.delete(recursive: true);
    const DwRepo().readDelegate = null;
    const DwRepo().writeDelegate = null;
  });

  test('registers delegates and activates one shared user scope', () async {
    await runtime.initialize();
    await runtime.activateUserScope(DwOfflineUserScope(userScopeId: 'scope-a'));

    expect(const DwRepo().readDelegate, same(readDelegate));
    expect(const DwRepo().writeDelegate, same(writeDelegate));
    expect((await readDelegate.resolveBinding())!.scope.storageKey, 'scope-a');
    expect((await writeDelegate.resolveBinding())!.scope.storageKey, 'scope-a');
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
    final binding = (await readDelegate.resolveBinding())!;

    expect(
      await readDelegate.storeSnapshotIfCurrent(
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
      await readDelegate.storeSnapshotIfCurrent(
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

      expect(await readDelegate.resolveBinding(), null);
      expect(await writeDelegate.resolveBinding(), null);
      expect(await database.select(database.dwOfflineSnapshots).get(), isEmpty);
    },
  );

  test('dispose detaches delegates and owns scheduler lifecycle', () async {
    await runtime.initialize();

    await runtime.dispose();

    expect(const DwRepo().readDelegate, null);
    expect(const DwRepo().writeDelegate, null);
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
