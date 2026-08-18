import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dartway_offline/src/access/dw_offline_lease_policy.dart';
import 'package:dartway_offline/src/download/dw_download_job_store.dart';
import 'package:dartway_offline/src/download/dw_download_plan.dart';
import 'package:dartway_offline/src/download/dw_download_asset_publisher.dart';
import 'package:dartway_offline/src/download/dw_download_state.dart';
import 'package:dartway_offline/src/storage/dw_offline_asset_store.dart';
import 'package:dartway_offline/src/storage/dw_offline_database.dart';

import '../support/signed_manifest_fixture.dart';

void main() {
  late Directory supportDirectory;
  late DwOfflineDatabase offlineDatabase;
  late TestSignedManifestFixture manifestFixture;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp('asset_store_');
    offlineDatabase = DwOfflineDatabase(NativeDatabase.memory());
    manifestFixture = await TestSignedManifestFixture.create();
  });

  tearDown(() async {
    await offlineDatabase.close();
    if (supportDirectory.existsSync()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test(
    'stages durably without replacing active state then activates required assets',
    () async {
      final store = DwOfflineAssetStore(
        applicationSupportDirectory: supportDirectory,
        database: offlineDatabase,
      );
      final firstManifest = await manifestFixture.verify();
      await store.beginStagingManifest(firstManifest);
      await store.publishAsset(
        userScopeId: 'scope-a',
        assetDescriptor: firstManifest.manifest.assets.single,
        bytes: Stream.value(const [1, 2, 3, 4, 5]),
      );
      await store.activateStagingManifest(
        userScopeId: 'scope-a',
        packageId: 'package-a',
        manifestRevision: 'manifest-1',
        payloadDigest: firstManifest.payloadDigest,
      );

      final secondManifest = await manifestFixture.verify(
        manifestRevision: 'manifest-2',
        leaseRecordVersion: 2,
        assets: [
          manifestFixture.assetMap(
            assetId: 'asset-b',
            assetRevision: 'r2',
            bytes: const [6, 7, 8],
          ),
        ],
        previousLeaseRecord: firstManifest.acceptedLeaseRecord,
      );
      await store.beginStagingManifest(secondManifest);
      expect(
        (await offlineDatabase
                .select(offlineDatabase.dwOfflinePackages)
                .getSingle())
            .activeManifestRevision,
        'manifest-1',
      );
      await expectLater(
        store.activateStagingManifest(
          userScopeId: 'scope-a',
          packageId: 'package-a',
          manifestRevision: 'manifest-2',
          payloadDigest: secondManifest.payloadDigest,
        ),
        throwsStateError,
      );
      expect(
        (await offlineDatabase
                .select(offlineDatabase.dwOfflinePackages)
                .getSingle())
            .activeManifestRevision,
        'manifest-1',
      );
    },
  );

  test(
    'publication rejects short long and SHA-256-mismatched streams',
    () async {
      final store = DwOfflineAssetStore(
        applicationSupportDirectory: supportDirectory,
        database: offlineDatabase,
      );
      final manifest = await manifestFixture.verify();
      await store.beginStagingManifest(manifest);
      final descriptor = manifest.manifest.assets.single;

      for (final bytes in <List<int>>[
        [1, 2],
        [1, 2, 3, 4, 5, 6],
        [5, 4, 3, 2, 1],
      ]) {
        await expectLater(
          store.publishAsset(
            userScopeId: 'scope-a',
            assetDescriptor: descriptor,
            bytes: Stream.value(bytes),
          ),
          throwsA(isA<DwOfflineAssetIntegrityException>()),
        );
      }
      expect(
        await store.scopeStagingDirectory('scope-a').list().toList(),
        isEmpty,
      );
    },
  );

  test(
    'publisher accepts a crash-replayed asset that is already durable',
    () async {
      final store = DwOfflineAssetStore(
        applicationSupportDirectory: supportDirectory,
        database: offlineDatabase,
      );
      final manifest = await manifestFixture.verify();
      final descriptor = manifest.manifest.assets.single;
      await store.beginStagingManifest(manifest);
      await store.publishAsset(
        userScopeId: 'scope-a',
        assetDescriptor: descriptor,
        bytes: Stream.value(const [1, 2, 3, 4, 5]),
      );

      await DwOfflineAssetStorePublisher(store).publish(
        userScopeId: 'scope-a',
        assetDescriptor: descriptor,
        temporaryFilePath: '${supportDirectory.path}/already-moved.download',
      );

      expect(
        await store.isAssetReady(
          userScopeId: 'scope-a',
          assetDescriptor: descriptor,
        ),
        isTrue,
      );
    },
  );

  test('deleting packages keeps shared blobs until their last owner', () async {
    final store = DwOfflineAssetStore(
      applicationSupportDirectory: supportDirectory,
      database: offlineDatabase,
    );
    final firstManifest = await manifestFixture.verify();
    await store.beginStagingManifest(firstManifest);
    await store.publishAsset(
      userScopeId: 'scope-a',
      assetDescriptor: firstManifest.manifest.assets.single,
      bytes: Stream.value(const [1, 2, 3, 4, 5]),
    );
    await store.activateStagingManifest(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      manifestRevision: 'manifest-1',
      payloadDigest: firstManifest.payloadDigest,
    );
    final secondManifest = await manifestFixture.verify(
      packageId: 'package-b',
      leaseId: 'lease-package-b',
    );
    await store.beginStagingManifest(secondManifest);
    await store.activateStagingManifest(
      userScopeId: 'scope-a',
      packageId: 'package-b',
      manifestRevision: 'manifest-1',
      payloadDigest: secondManifest.payloadDigest,
    );
    final blobFile = store.blobFileFor(
      userScopeId: 'scope-a',
      assetId: 'asset-a',
      assetRevision: 'r1',
    );

    await store.deletePackage(userScopeId: 'scope-a', packageId: 'package-a');

    expect(blobFile.existsSync(), isTrue);
    expect(
      (await offlineDatabase
              .select(offlineDatabase.dwOfflineAssets)
              .getSingle())
          .refCount,
      1,
    );
    expect(
      (await offlineDatabase.select(offlineDatabase.dwOfflinePackages).get())
          .map((package) => package.packageId),
      ['package-b'],
    );

    await store.deletePackage(userScopeId: 'scope-a', packageId: 'package-b');

    expect(blobFile.existsSync(), isFalse);
    expect(
      await offlineDatabase.select(offlineDatabase.dwOfflineAssets).get(),
      isEmpty,
    );
  });

  test('tombstone retains a blob until both reader handles close', () async {
    final store = DwOfflineAssetStore(
      applicationSupportDirectory: supportDirectory,
      database: offlineDatabase,
    );
    final manifest = await manifestFixture.verify();
    await store.beginStagingManifest(manifest);
    final descriptor = manifest.manifest.assets.single;
    await store.publishAsset(
      userScopeId: 'scope-a',
      assetDescriptor: descriptor,
      bytes: Stream.value(const [1, 2, 3, 4, 5]),
    );
    await offlineDatabase.delete(offlineDatabase.dwOfflineStagingAssets).go();
    final firstReader = await store.openReader(
      userScopeId: 'scope-a',
      assetId: 'asset-a',
      assetRevision: 'r1',
    );
    final secondReader = await store.openReader(
      userScopeId: 'scope-a',
      assetId: 'asset-a',
      assetRevision: 'r1',
    );
    final blobFile = store.blobFileFor(
      userScopeId: 'scope-a',
      assetId: 'asset-a',
      assetRevision: 'r1',
    );

    await store.tombstoneAsset(
      userScopeId: 'scope-a',
      assetId: 'asset-a',
      assetRevision: 'r1',
    );
    expect(blobFile.existsSync(), isTrue);
    await firstReader.close();
    expect(blobFile.existsSync(), isTrue);
    await secondReader.close();
    expect(blobFile.existsSync(), isFalse);
    await secondReader.close();
  });

  test(
    'reconciliation preserves a tombstoned blob with a live reader',
    () async {
      final store = DwOfflineAssetStore(
        applicationSupportDirectory: supportDirectory,
        database: offlineDatabase,
      );
      final manifest = await manifestFixture.verify();
      await store.beginStagingManifest(manifest);
      await store.publishAsset(
        userScopeId: 'scope-a',
        assetDescriptor: manifest.manifest.assets.single,
        bytes: Stream.value(const [1, 2, 3, 4, 5]),
      );
      await offlineDatabase.delete(offlineDatabase.dwOfflineStagingAssets).go();
      final reader = await store.openReader(
        userScopeId: 'scope-a',
        assetId: 'asset-a',
        assetRevision: 'r1',
      );
      addTearDown(reader.close);
      final blobFile = store.blobFileFor(
        userScopeId: 'scope-a',
        assetId: 'asset-a',
        assetRevision: 'r1',
      );
      await store.tombstoneAsset(
        userScopeId: 'scope-a',
        assetId: 'asset-a',
        assetRevision: 'r1',
      );

      await store.reconcileUserScope('scope-a');

      expect(blobFile.existsSync(), isTrue);
      await reader.close();
      expect(blobFile.existsSync(), isFalse);
    },
  );

  test(
    'recovery does not activate complete staging without a durable job',
    () async {
      final store = DwOfflineAssetStore(
        applicationSupportDirectory: supportDirectory,
        database: offlineDatabase,
      );
      final manifest = await manifestFixture.verify();
      await store.beginStagingManifest(manifest);
      await store.publishAsset(
        userScopeId: 'scope-a',
        assetDescriptor: manifest.manifest.assets.single,
        bytes: Stream.value(const [1, 2, 3, 4, 5]),
      );

      await store.reconcileUserScope('scope-a');

      final packageRow = await offlineDatabase
          .select(offlineDatabase.dwOfflinePackages)
          .getSingle();
      expect(packageRow.activeManifestRevision, isNull);
      expect(packageRow.stagingManifestRevision, 'manifest-1');
    },
  );

  test('recovery never activates staging owned by a cancelled job', () async {
    final store = DwOfflineAssetStore(
      applicationSupportDirectory: supportDirectory,
      database: offlineDatabase,
    );
    final manifest = await manifestFixture.verify();
    await store.beginStagingManifest(manifest);
    await store.publishAsset(
      userScopeId: 'scope-a',
      assetDescriptor: manifest.manifest.assets.single,
      bytes: Stream.value(const [1, 2, 3, 4, 5]),
    );
    final jobStore = DwDownloadJobStore(offlineDatabase);
    final jobId = await jobStore.createJob(
      DwDownloadPackagePlan.fromVerifiedManifest(manifest),
    );
    await jobStore.markJobState(
      userScopeId: 'scope-a',
      jobId: jobId,
      jobState: DwDownloadJobState.cancelled,
    );
    for (final task in await jobStore.loadTasks('scope-a')) {
      await jobStore.markCancelled(task.identity);
    }

    await store.reconcileUserScope('scope-a');

    final packageRow = await offlineDatabase
        .select(offlineDatabase.dwOfflinePackages)
        .getSingle();
    expect(packageRow.activeManifestRevision, isNull);
    expect(packageRow.stagingManifestRevision, 'manifest-1');
  });

  test('restart reconciliation removes orphan partials and stale pins', () async {
    final store = DwOfflineAssetStore(
      applicationSupportDirectory: supportDirectory,
      database: offlineDatabase,
    );
    final manifest = await manifestFixture.verify();
    await store.beginStagingManifest(manifest);
    final stagingDirectory = store.scopeStagingDirectory('scope-a');
    await stagingDirectory.create(recursive: true);
    await File(
      '${stagingDirectory.path}${Platform.pathSeparator}orphan.partial',
    ).writeAsBytes([1]);
    await offlineDatabase.customInsert(
      'INSERT INTO dw_offline_reader_pins '
      '(user_scope_id, reader_id, asset_id, asset_revision, pinned_at_epoch_ms) '
      "VALUES ('scope-a', 'stale', 'asset-a', 'r1', 1)",
    );

    await store.reconcileUserScope('scope-a');

    expect(await stagingDirectory.list().toList(), isEmpty);
    expect(
      await offlineDatabase.select(offlineDatabase.dwOfflineReaderPins).get(),
      isEmpty,
    );
  });

  test(
    'reconciles interruptions before and after publication rename',
    () async {
      await offlineDatabase.close();
      for (final checkpoint in <DwOfflineAssetStoreCheckpoint>[
        DwOfflineAssetStoreCheckpoint.beforeRename,
        DwOfflineAssetStoreCheckpoint.afterRenameBeforeReadyCommit,
      ]) {
        final localDirectory = await Directory.systemTemp.createTemp('fault_');
        final localDatabase = DwOfflineDatabase(NativeDatabase.memory());
        try {
          final manifest = await manifestFixture.verify(
            userScopeId: 'scope-$checkpoint',
          );
          final interruptedStore = DwOfflineAssetStore(
            applicationSupportDirectory: localDirectory,
            database: localDatabase,
            faultInjector: (observedCheckpoint) async {
              if (observedCheckpoint == checkpoint) {
                throw DwOfflineSimulatedProcessInterruption(checkpoint);
              }
            },
          );
          await interruptedStore.beginStagingManifest(manifest);
          await _createDurableDownloadJob(localDatabase, manifest);
          await expectLater(
            interruptedStore.publishAsset(
              userScopeId: manifest.manifest.userScopeId,
              assetDescriptor: manifest.manifest.assets.single,
              bytes: Stream.value(const [1, 2, 3, 4, 5]),
            ),
            throwsA(isA<DwOfflineSimulatedProcessInterruption>()),
          );

          final restartedStore = DwOfflineAssetStore(
            applicationSupportDirectory: localDirectory,
            database: localDatabase,
          );
          await restartedStore.reconcileUserScope(
            manifest.manifest.userScopeId,
          );
          final assetRow = await localDatabase
              .select(localDatabase.dwOfflineAssets)
              .getSingle();
          if (checkpoint == DwOfflineAssetStoreCheckpoint.beforeRename) {
            expect(assetRow.assetState, 'missing');
            expect(
              await restartedStore
                  .scopeStagingDirectory(manifest.manifest.userScopeId)
                  .list()
                  .toList(),
              isEmpty,
            );
          } else {
            expect(assetRow.assetState, 'ready');
            expect(
              (await localDatabase
                      .select(localDatabase.dwOfflinePackages)
                      .getSingle())
                  .activeManifestRevision,
              'manifest-1',
            );
          }
        } finally {
          await localDatabase.close();
          await localDirectory.delete(recursive: true);
        }
      }
    },
  );

  test(
    'ready and activation interruptions preserve committed transaction boundaries',
    () async {
      await offlineDatabase.close();
      for (final checkpoint in <DwOfflineAssetStoreCheckpoint>[
        DwOfflineAssetStoreCheckpoint.afterReadyBeforeActivation,
        DwOfflineAssetStoreCheckpoint.duringActivation,
        DwOfflineAssetStoreCheckpoint.afterActivation,
      ]) {
        final localDirectory = await Directory.systemTemp.createTemp('fault_');
        final localDatabase = DwOfflineDatabase(NativeDatabase.memory());
        try {
          final manifest = await manifestFixture.verify(
            userScopeId: 'scope-$checkpoint',
          );
          final store = DwOfflineAssetStore(
            applicationSupportDirectory: localDirectory,
            database: localDatabase,
            faultInjector: (observedCheckpoint) async {
              if (observedCheckpoint == checkpoint) {
                throw DwOfflineSimulatedProcessInterruption(checkpoint);
              }
            },
          );
          await store.beginStagingManifest(manifest);
          await _createDurableDownloadJob(localDatabase, manifest);
          if (checkpoint ==
              DwOfflineAssetStoreCheckpoint.afterReadyBeforeActivation) {
            await expectLater(
              store.publishAsset(
                userScopeId: manifest.manifest.userScopeId,
                assetDescriptor: manifest.manifest.assets.single,
                bytes: Stream.value(const [1, 2, 3, 4, 5]),
              ),
              throwsA(isA<DwOfflineSimulatedProcessInterruption>()),
            );
          } else {
            await store.publishAsset(
              userScopeId: manifest.manifest.userScopeId,
              assetDescriptor: manifest.manifest.assets.single,
              bytes: Stream.value(const [1, 2, 3, 4, 5]),
            );
            await expectLater(
              store.activateStagingManifest(
                userScopeId: manifest.manifest.userScopeId,
                packageId: 'package-a',
                manifestRevision: 'manifest-1',
                payloadDigest: manifest.payloadDigest,
              ),
              throwsA(isA<DwOfflineSimulatedProcessInterruption>()),
            );
            if (checkpoint == DwOfflineAssetStoreCheckpoint.duringActivation) {
              expect(
                (await localDatabase
                        .select(localDatabase.dwOfflinePackages)
                        .getSingle())
                    .activeManifestRevision,
                isNull,
              );
            }
          }
          final restartedStore = DwOfflineAssetStore(
            applicationSupportDirectory: localDirectory,
            database: localDatabase,
          );
          await restartedStore.reconcileUserScope(
            manifest.manifest.userScopeId,
          );
          expect(
            (await localDatabase
                    .select(localDatabase.dwOfflinePackages)
                    .getSingle())
                .activeManifestRevision,
            'manifest-1',
          );
        } finally {
          await localDatabase.close();
          await localDirectory.delete(recursive: true);
        }
      }
    },
  );

  test(
    'purge drains accepted publish and activation then rejects later scope work',
    () async {
      final publishReachedRename = Completer<void>();
      final allowPublishToFinish = Completer<void>();
      final store = DwOfflineAssetStore(
        applicationSupportDirectory: supportDirectory,
        database: offlineDatabase,
        faultInjector: (checkpoint) async {
          if (checkpoint == DwOfflineAssetStoreCheckpoint.beforeRename) {
            publishReachedRename.complete();
            await allowPublishToFinish.future;
          }
        },
      );
      final manifest = await manifestFixture.verify();
      await store.beginStagingManifest(manifest);
      final publishFuture = store.publishAsset(
        userScopeId: 'scope-a',
        assetDescriptor: manifest.manifest.assets.single,
        bytes: Stream.value(const [1, 2, 3, 4, 5]),
      );
      await publishReachedRename.future;
      final activationFuture = store.activateStagingManifest(
        userScopeId: 'scope-a',
        packageId: 'package-a',
        manifestRevision: 'manifest-1',
        payloadDigest: manifest.payloadDigest,
      );
      final purgeFuture = store.purgeUserScope('scope-a');
      final rejectedWork = expectLater(
        store.beginStagingManifest(manifest),
        throwsStateError,
      );

      allowPublishToFinish.complete();
      await publishFuture;
      await activationFuture;
      await purgeFuture;
      await rejectedWork;

      expect(
        await offlineDatabase.select(offlineDatabase.dwOfflinePackages).get(),
        isEmpty,
      );
      expect(
        await offlineDatabase.select(offlineDatabase.dwOfflineAssets).get(),
        isEmpty,
      );
      expect(
        await offlineDatabase
            .select(offlineDatabase.dwOfflinePackageAssets)
            .get(),
        isEmpty,
      );
      expect(
        await offlineDatabase
            .select(offlineDatabase.dwOfflineStagingAssets)
            .get(),
        isEmpty,
      );
      expect(
        await offlineDatabase.select(offlineDatabase.dwOfflineManifests).get(),
        isEmpty,
      );
      expect(
        store.scopeStagingDirectory('scope-a').parent.existsSync(),
        isFalse,
      );
    },
  );

  test(
    'failed purge leaves retryable debt without poisoning the scope queue',
    () async {
      final store = DwOfflineAssetStore(
        applicationSupportDirectory: supportDirectory,
        database: offlineDatabase,
      );
      final manifest = await manifestFixture.verify();
      await store.beginStagingManifest(manifest);
      await store.publishAsset(
        userScopeId: 'scope-a',
        assetDescriptor: manifest.manifest.assets.single,
        bytes: Stream.value(const [1, 2, 3, 4, 5]),
      );
      await offlineDatabase.customStatement('''
      CREATE TEMP TRIGGER abort_store_purge
      BEFORE DELETE ON dw_offline_packages
      WHEN OLD.user_scope_id = 'scope-a'
      BEGIN
        SELECT RAISE(ABORT, 'forced store purge failure');
      END
    ''');

      await expectLater(
        store.purgeUserScope('scope-a'),
        throwsA(isA<Exception>()),
      );
      expect(
        await offlineDatabase.select(offlineDatabase.dwOfflinePackages).get(),
        hasLength(1),
      );
      await offlineDatabase.customStatement('DROP TRIGGER abort_store_purge');

      await store.purgeUserScope('scope-a');

      expect(
        await offlineDatabase.select(offlineDatabase.dwOfflinePackages).get(),
        isEmpty,
      );
      expect(
        store.scopeStagingDirectory('scope-a').parent.existsSync(),
        isFalse,
      );
    },
  );

  test(
    'optional missing assets activate while required missing assets do not',
    () async {
      final store = DwOfflineAssetStore(
        applicationSupportDirectory: supportDirectory,
        database: offlineDatabase,
      );
      final optionalManifest = await manifestFixture.verify(
        assets: [manifestFixture.assetMap(isRequired: false)],
      );
      await store.beginStagingManifest(optionalManifest);
      await store.activateStagingManifest(
        userScopeId: 'scope-a',
        packageId: 'package-a',
        manifestRevision: 'manifest-1',
        payloadDigest: optionalManifest.payloadDigest,
      );
      expect(
        await offlineDatabase
            .select(offlineDatabase.dwOfflinePackageAssets)
            .get(),
        isEmpty,
      );
      expect(
        (await offlineDatabase
                .select(offlineDatabase.dwOfflinePackages)
                .getSingle())
            .activeManifestRevision,
        'manifest-1',
      );
    },
  );

  test(
    'reuses a valid destination and rejects a corrupt destination',
    () async {
      final store = DwOfflineAssetStore(
        applicationSupportDirectory: supportDirectory,
        database: offlineDatabase,
      );
      final manifest = await manifestFixture.verify();
      final descriptor = manifest.manifest.assets.single;
      await store.beginStagingManifest(manifest);
      await store.publishAsset(
        userScopeId: 'scope-a',
        assetDescriptor: descriptor,
        bytes: Stream.value(const [1, 2, 3, 4, 5]),
      );
      await store.publishAsset(
        userScopeId: 'scope-a',
        assetDescriptor: descriptor,
        bytes: Stream.error(StateError('must not consume a reusable stream')),
      );
      await store
          .blobFileFor(
            userScopeId: 'scope-a',
            assetId: 'asset-a',
            assetRevision: 'r1',
          )
          .writeAsBytes(const [9, 9, 9, 9, 9]);
      await expectLater(
        store.publishAsset(
          userScopeId: 'scope-a',
          assetDescriptor: descriptor,
          bytes: Stream.value(const [1, 2, 3, 4, 5]),
        ),
        throwsA(isA<DwOfflineAssetIntegrityException>()),
      );
    },
  );

  test(
    'reconciliation removes a corrupt owned blob so it can be downloaded again',
    () async {
      final store = DwOfflineAssetStore(
        applicationSupportDirectory: supportDirectory,
        database: offlineDatabase,
      );
      final manifest = await manifestFixture.verify();
      final descriptor = manifest.manifest.assets.single;
      await store.beginStagingManifest(manifest);
      await store.publishAsset(
        userScopeId: 'scope-a',
        assetDescriptor: descriptor,
        bytes: Stream.value(const [1, 2, 3, 4, 5]),
      );
      final blobFile = store.blobFileFor(
        userScopeId: 'scope-a',
        assetId: descriptor.assetId,
        assetRevision: descriptor.assetRevision,
      );
      await blobFile.writeAsBytes(const [9, 9, 9, 9, 9]);

      await store.reconcileUserScope('scope-a');
      await store.publishAsset(
        userScopeId: 'scope-a',
        assetDescriptor: descriptor,
        bytes: Stream.value(const [1, 2, 3, 4, 5]),
      );

      expect(await blobFile.readAsBytes(), const [1, 2, 3, 4, 5]);
      expect(
        (await offlineDatabase
                .select(offlineDatabase.dwOfflineAssets)
                .getSingle())
            .assetState,
        'ready',
      );
    },
  );

  test(
    'a newer staging revision replaces obsolete durable staging edges',
    () async {
      final store = DwOfflineAssetStore(
        applicationSupportDirectory: supportDirectory,
        database: offlineDatabase,
      );
      final firstManifest = await manifestFixture.verify();
      await store.beginStagingManifest(firstManifest);
      final secondManifest = await manifestFixture.verify(
        manifestRevision: 'manifest-2',
        leaseRecordVersion: 2,
        assets: [
          manifestFixture.assetMap(
            assetId: 'asset-b',
            assetRevision: 'r2',
            bytes: const [6, 7, 8],
          ),
        ],
        previousLeaseRecord: firstManifest.acceptedLeaseRecord,
      );

      await store.beginStagingManifest(secondManifest);

      final stagingRows = await offlineDatabase
          .select(offlineDatabase.dwOfflineStagingAssets)
          .get();
      expect(stagingRows, hasLength(1));
      expect(stagingRows.single.manifestRevision, 'manifest-2');
      expect(stagingRows.single.assetId, 'asset-b');
    },
  );

  test(
    'restart activation collects the superseded asset after the active swap',
    () async {
      final store = DwOfflineAssetStore(
        applicationSupportDirectory: supportDirectory,
        database: offlineDatabase,
      );
      final firstManifest = await manifestFixture.verify();
      await store.beginStagingManifest(firstManifest);
      await store.publishAsset(
        userScopeId: 'scope-a',
        assetDescriptor: firstManifest.manifest.assets.single,
        bytes: Stream.value(const [1, 2, 3, 4, 5]),
      );
      await store.activateStagingManifest(
        userScopeId: 'scope-a',
        packageId: 'package-a',
        manifestRevision: 'manifest-1',
        payloadDigest: firstManifest.payloadDigest,
      );
      final supersededBlob = store.blobFileFor(
        userScopeId: 'scope-a',
        assetId: 'asset-a',
        assetRevision: 'r1',
      );
      final secondManifest = await manifestFixture.verify(
        manifestRevision: 'manifest-2',
        leaseRecordVersion: 2,
        assets: [
          manifestFixture.assetMap(
            assetId: 'asset-b',
            assetRevision: 'r2',
            bytes: const [6, 7, 8],
          ),
        ],
        previousLeaseRecord: firstManifest.acceptedLeaseRecord,
      );
      await store.beginStagingManifest(secondManifest);
      await _createDurableDownloadJob(offlineDatabase, secondManifest);
      await store.publishAsset(
        userScopeId: 'scope-a',
        assetDescriptor: secondManifest.manifest.assets.single,
        bytes: Stream.value(const [6, 7, 8]),
      );

      await DwOfflineAssetStore(
        applicationSupportDirectory: supportDirectory,
        database: offlineDatabase,
      ).reconcileUserScope('scope-a');

      await store.activateStagingManifest(
        userScopeId: 'scope-a',
        packageId: 'package-a',
        manifestRevision: 'manifest-2',
        payloadDigest: secondManifest.payloadDigest,
      );

      final assetRows = await offlineDatabase
          .select(offlineDatabase.dwOfflineAssets)
          .get();
      expect(assetRows, hasLength(1));
      expect(assetRows.single.assetId, 'asset-b');
      expect(supersededBlob.existsSync(), isFalse);
      expect(
        (await offlineDatabase
                .select(offlineDatabase.dwOfflinePackages)
                .getSingle())
            .activeManifestRevision,
        'manifest-2',
      );
    },
  );

  test(
    'reconciliation repairs refcounts, flags missing active blobs, and removes orphans',
    () async {
      final store = DwOfflineAssetStore(
        applicationSupportDirectory: supportDirectory,
        database: offlineDatabase,
      );
      final manifest = await manifestFixture.verify();
      await store.beginStagingManifest(manifest);
      await store.publishAsset(
        userScopeId: 'scope-a',
        assetDescriptor: manifest.manifest.assets.single,
        bytes: Stream.value(const [1, 2, 3, 4, 5]),
      );
      await store.activateStagingManifest(
        userScopeId: 'scope-a',
        packageId: 'package-a',
        manifestRevision: 'manifest-1',
        payloadDigest: manifest.payloadDigest,
      );
      await offlineDatabase.customUpdate(
        'UPDATE dw_offline_assets SET ref_count = 77',
        updates: {offlineDatabase.dwOfflineAssets},
      );
      final blobFile = store.blobFileFor(
        userScopeId: 'scope-a',
        assetId: 'asset-a',
        assetRevision: 'r1',
      );
      await blobFile.delete();
      final orphanFile = File(
        '${blobFile.parent.path}${Platform.pathSeparator}orphan.blob',
      );
      await orphanFile.writeAsBytes(const [1]);

      await store.reconcileUserScope('scope-a');

      final assetRow = await offlineDatabase
          .select(offlineDatabase.dwOfflineAssets)
          .getSingle();
      expect(assetRow.refCount, 1);
      expect(assetRow.assetState, 'repairNeeded');
      expect(orphanFile.existsSync(), isFalse);
      expect(
        (await offlineDatabase
                .select(offlineDatabase.dwOfflinePackages)
                .getSingle())
            .activeManifestRevision,
        'manifest-1',
      );
    },
  );

  test(
    'reconciliation isolates corrupt redirect metadata and continues the scope',
    () async {
      final store = DwOfflineAssetStore(
        applicationSupportDirectory: supportDirectory,
        database: offlineDatabase,
      );
      final manifest = await manifestFixture.verify(
        assets: [
          manifestFixture.assetMap(),
          manifestFixture.assetMap(
            assetId: 'asset-b',
            assetRevision: 'r2',
            bytes: const [6, 7, 8],
          ),
        ],
      );
      await store.beginStagingManifest(manifest);
      await store.publishAsset(
        userScopeId: 'scope-a',
        assetDescriptor: manifest.manifest.assets.first,
        bytes: Stream.value(const [1, 2, 3, 4, 5]),
      );
      await store.publishAsset(
        userScopeId: 'scope-a',
        assetDescriptor: manifest.manifest.assets.last,
        bytes: Stream.value(const [6, 7, 8]),
      );
      await offlineDatabase.customUpdate(
        "UPDATE dw_offline_assets SET allowed_redirect_hosts_json = '{' "
        "WHERE asset_id = 'asset-a'",
        updates: {offlineDatabase.dwOfflineAssets},
      );
      await offlineDatabase.customUpdate(
        "UPDATE dw_offline_assets SET asset_state = 'missing', blob_name = NULL "
        "WHERE asset_id = 'asset-b'",
        updates: {offlineDatabase.dwOfflineAssets},
      );

      await store.reconcileUserScope('scope-a');

      final assetRows = await offlineDatabase
          .select(offlineDatabase.dwOfflineAssets)
          .get();
      expect(
        assetRows.singleWhere((row) => row.assetId == 'asset-a').assetState,
        'repairNeeded',
      );
      expect(
        assetRows.singleWhere((row) => row.assetId == 'asset-b').assetState,
        'ready',
      );
    },
  );

  test('unlink interruption is finalized by restart reconciliation', () async {
    var interruptUnlink = true;
    final store = DwOfflineAssetStore(
      applicationSupportDirectory: supportDirectory,
      database: offlineDatabase,
      faultInjector: (checkpoint) async {
        if (interruptUnlink &&
            checkpoint ==
                DwOfflineAssetStoreCheckpoint
                    .afterUnlinkBeforeDatabaseFinalize) {
          throw DwOfflineSimulatedProcessInterruption(checkpoint);
        }
      },
    );
    final manifest = await manifestFixture.verify();
    await store.beginStagingManifest(manifest);
    await store.publishAsset(
      userScopeId: 'scope-a',
      assetDescriptor: manifest.manifest.assets.single,
      bytes: Stream.value(const [1, 2, 3, 4, 5]),
    );
    await offlineDatabase.delete(offlineDatabase.dwOfflineStagingAssets).go();
    await expectLater(
      store.tombstoneAsset(
        userScopeId: 'scope-a',
        assetId: 'asset-a',
        assetRevision: 'r1',
      ),
      throwsA(isA<DwOfflineSimulatedProcessInterruption>()),
    );
    expect(
      await offlineDatabase.select(offlineDatabase.dwOfflineAssets).get(),
      hasLength(1),
    );
    interruptUnlink = false;

    await DwOfflineAssetStore(
      applicationSupportDirectory: supportDirectory,
      database: offlineDatabase,
    ).reconcileUserScope('scope-a');

    expect(
      await offlineDatabase.select(offlineDatabase.dwOfflineAssets).get(),
      isEmpty,
    );
  });

  test('scope-derived paths isolate identical asset identities', () async {
    final store = DwOfflineAssetStore(
      applicationSupportDirectory: supportDirectory,
      database: offlineDatabase,
    );
    for (final userScopeId in ['scope-a', 'scope-b']) {
      final manifest = await manifestFixture.verify(userScopeId: userScopeId);
      await store.beginStagingManifest(manifest);
      await store.publishAsset(
        userScopeId: userScopeId,
        assetDescriptor: manifest.manifest.assets.single,
        bytes: Stream.value(const [1, 2, 3, 4, 5]),
      );
    }
    final scopeAFile = store.blobFileFor(
      userScopeId: 'scope-a',
      assetId: 'asset-a',
      assetRevision: 'r1',
    );
    final scopeBFile = store.blobFileFor(
      userScopeId: 'scope-b',
      assetId: 'asset-a',
      assetRevision: 'r1',
    );
    expect(scopeAFile.path, isNot(scopeBFile.path));
    await offlineDatabase.delete(offlineDatabase.dwOfflineStagingAssets).go();
    await store.tombstoneAsset(
      userScopeId: 'scope-a',
      assetId: 'asset-a',
      assetRevision: 'r1',
    );
    expect(scopeAFile.existsSync(), isFalse);
    expect(scopeBFile.existsSync(), isTrue);
  });

  test('rejects an existing symbolic-link blob destination', () async {
    final store = DwOfflineAssetStore(
      applicationSupportDirectory: supportDirectory,
      database: offlineDatabase,
    );
    final manifest = await manifestFixture.verify();
    await store.beginStagingManifest(manifest);
    final outsideFile = File(
      '${supportDirectory.path}${Platform.pathSeparator}outside.bin',
    );
    await outsideFile.writeAsBytes(const [1, 2, 3, 4, 5]);
    final blobFile = store.blobFileFor(
      userScopeId: 'scope-a',
      assetId: 'asset-a',
      assetRevision: 'r1',
    );
    try {
      await Link(blobFile.path).create(outsideFile.path);
    } on FileSystemException {
      return;
    }

    await expectLater(
      store.publishAsset(
        userScopeId: 'scope-a',
        assetDescriptor: manifest.manifest.assets.single,
        bytes: Stream.value(const [1, 2, 3, 4, 5]),
      ),
      throwsA(isA<DwOfflineAssetIntegrityException>()),
    );
    expect(await outsideFile.readAsBytes(), const [1, 2, 3, 4, 5]);
  });

  test('reconciliation never readies or activates a linked blob', () async {
    final store = DwOfflineAssetStore(
      applicationSupportDirectory: supportDirectory,
      database: offlineDatabase,
    );
    final manifest = await manifestFixture.verify();
    await store.beginStagingManifest(manifest);
    final outsideFile = File(
      '${supportDirectory.path}${Platform.pathSeparator}recovery-outside.bin',
    );
    await outsideFile.writeAsBytes(const [1, 2, 3, 4, 5]);
    final blobFile = store.blobFileFor(
      userScopeId: 'scope-a',
      assetId: 'asset-a',
      assetRevision: 'r1',
    );
    try {
      await Link(blobFile.path).create(outsideFile.path);
    } on FileSystemException {
      markTestSkipped('The host does not permit creating symbolic links.');
      return;
    }

    await store.reconcileUserScope('scope-a');

    final assetRow = await offlineDatabase
        .select(offlineDatabase.dwOfflineAssets)
        .getSingle();
    final packageRow = await offlineDatabase
        .select(offlineDatabase.dwOfflinePackages)
        .getSingle();
    expect(assetRow.assetState, 'repairNeeded');
    expect(assetRow.blobName, isNull);
    expect(packageRow.activeManifestRevision, isNull);
    expect(await outsideFile.readAsBytes(), const [1, 2, 3, 4, 5]);
  });

  test('rejects a symbolic-link ancestor below the support root', () async {
    final outsideDirectory = await Directory.systemTemp.createTemp(
      'asset_store_outside_',
    );
    addTearDown(() async {
      if (outsideDirectory.existsSync()) {
        await outsideDirectory.delete(recursive: true);
      }
    });
    final storeRootLink = Link(
      '${supportDirectory.path}${Platform.pathSeparator}dartway_offline',
    );
    try {
      await storeRootLink.create(outsideDirectory.path);
    } on FileSystemException {
      markTestSkipped('The host does not permit creating symbolic links.');
      return;
    }
    final store = DwOfflineAssetStore(
      applicationSupportDirectory: supportDirectory,
      database: offlineDatabase,
    );
    final manifest = await manifestFixture.verify();

    await expectLater(
      store.beginStagingManifest(manifest),
      throwsA(isA<DwOfflineAssetIntegrityException>()),
    );
    expect(
      await outsideDirectory.list().toList(),
      isEmpty,
      reason: 'A link ancestor must not redirect store writes outside scope.',
    );
  });
}

Future<void> _createDurableDownloadJob(
  DwOfflineDatabase database,
  DwVerifiedOfflineManifest manifest,
) async {
  final jobStore = DwDownloadJobStore(database);
  final jobId = await jobStore.createJob(
    DwDownloadPackagePlan.fromVerifiedManifest(manifest),
  );
  await jobStore.markJobState(
    userScopeId: manifest.manifest.userScopeId,
    jobId: jobId,
    jobState: DwDownloadJobState.running,
  );
  for (final task in await jobStore.loadTasks(manifest.manifest.userScopeId)) {
    if (task.identity.jobId != jobId) continue;
    await jobStore.markTaskState(
      identity: task.identity,
      taskState: DwDownloadTaskState.completed,
    );
  }
}
