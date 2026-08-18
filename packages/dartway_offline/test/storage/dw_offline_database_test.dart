import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dartway_offline/src/storage/dw_offline_database.dart';

void main() {
  group('DwOfflineDatabase schema', () {
    late DwOfflineDatabase offlineDatabase;

    setUp(() {
      offlineDatabase = DwOfflineDatabase(NativeDatabase.memory());
    });

    tearDown(() => offlineDatabase.close());

    test('package identity is unique inside a scope only', () async {
      await StorageFixtures.insertPackage(offlineDatabase, 'scope-a', 'pkg');
      await StorageFixtures.insertPackage(offlineDatabase, 'scope-b', 'pkg');

      await expectLater(
        StorageFixtures.insertPackage(offlineDatabase, 'scope-a', 'pkg'),
        throwsA(isA<Exception>()),
      );
    });

    test('asset identity includes scope, asset id, and revision', () async {
      await StorageFixtures.insertAsset(
        offlineDatabase,
        'scope-a',
        'asset',
        'r1',
      );
      await StorageFixtures.insertAsset(
        offlineDatabase,
        'scope-a',
        'asset',
        'r2',
      );
      await StorageFixtures.insertAsset(
        offlineDatabase,
        'scope-b',
        'asset',
        'r1',
      );

      await expectLater(
        StorageFixtures.insertAsset(offlineDatabase, 'scope-a', 'asset', 'r1'),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'blank scope identifiers are rejected by every protected table',
      () async {
        final rejectedWrites = <Future<Object?>>[
          StorageFixtures.insertPackage(offlineDatabase, '   ', 'pkg'),
          StorageFixtures.insertAsset(offlineDatabase, '   ', 'asset', 'r1'),
          offlineDatabase
              .into(offlineDatabase.dwOfflineJobs)
              .insert(StorageFixtures.job('   ', 'job')),
          offlineDatabase
              .into(offlineDatabase.dwOfflineSnapshots)
              .insert(StorageFixtures.snapshot('   ', 'query')),
          offlineDatabase
              .into(offlineDatabase.dwOfflineOutbox)
              .insert(StorageFixtures.outbox('   ', 'mutation', 'entity')),
          offlineDatabase
              .into(offlineDatabase.dwOfflineLeases)
              .insert(StorageFixtures.lease('   ', 'lease')),
        ];

        for (final rejectedWrite in rejectedWrites) {
          await expectLater(rejectedWrite, throwsA(isA<Exception>()));
        }
      },
    );

    test('package edges reject cross-scope references and cascade', () async {
      await StorageFixtures.insertPackage(offlineDatabase, 'scope-a', 'pkg');
      await StorageFixtures.insertPackage(offlineDatabase, 'scope-b', 'pkg');
      await StorageFixtures.insertAsset(
        offlineDatabase,
        'scope-a',
        'asset',
        'r1',
      );
      await StorageFixtures.insertAsset(
        offlineDatabase,
        'scope-a',
        'asset',
        'r2',
      );
      await StorageFixtures.insertAsset(
        offlineDatabase,
        'scope-b',
        'asset',
        'r1',
      );

      await offlineDatabase
          .into(offlineDatabase.dwOfflinePackageAssets)
          .insert(
            StorageFixtures.packageAsset('scope-a', 'pkg', 'asset', 'r1'),
          );
      await expectLater(
        offlineDatabase
            .into(offlineDatabase.dwOfflinePackageAssets)
            .insert(
              StorageFixtures.packageAsset('scope-b', 'pkg', 'asset', 'r1'),
            ),
        completes,
      );
      await expectLater(
        offlineDatabase
            .into(offlineDatabase.dwOfflinePackageAssets)
            .insert(
              StorageFixtures.packageAsset('scope-a', 'missing', 'asset', 'r1'),
            ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        offlineDatabase
            .into(offlineDatabase.dwOfflinePackageAssets)
            .insert(
              StorageFixtures.packageAsset('scope-a', 'pkg', 'foreign', 'r1'),
            ),
        throwsA(isA<Exception>()),
      );

      await (offlineDatabase.delete(offlineDatabase.dwOfflinePackages)..where(
            (row) =>
                row.userScopeId.equals('scope-a') & row.packageId.equals('pkg'),
          ))
          .go();

      final remainingEdges = await offlineDatabase
          .select(offlineDatabase.dwOfflinePackageAssets)
          .get();
      expect(remainingEdges, hasLength(1));
      expect(remainingEdges.single.userScopeId, 'scope-b');

      await (offlineDatabase.delete(offlineDatabase.dwOfflineAssets)..where(
            (row) =>
                row.userScopeId.equals('scope-b') &
                row.assetId.equals('asset') &
                row.assetRevision.equals('r1'),
          ))
          .go();
      expect(
        await offlineDatabase
            .select(offlineDatabase.dwOfflinePackageAssets)
            .get(),
        isEmpty,
      );
    });

    test(
      'edge identity permits sharing one asset across packages once each',
      () async {
        await StorageFixtures.insertPackage(
          offlineDatabase,
          'scope-a',
          'pkg-1',
        );
        await StorageFixtures.insertPackage(
          offlineDatabase,
          'scope-a',
          'pkg-2',
        );
        await StorageFixtures.insertAsset(
          offlineDatabase,
          'scope-a',
          'asset',
          'r1',
        );
        await StorageFixtures.insertAsset(
          offlineDatabase,
          'scope-a',
          'asset',
          'r2',
        );
        final firstEdge = StorageFixtures.packageAsset(
          'scope-a',
          'pkg-1',
          'asset',
          'r1',
        );

        await offlineDatabase
            .into(offlineDatabase.dwOfflinePackageAssets)
            .insert(firstEdge);
        await offlineDatabase
            .into(offlineDatabase.dwOfflinePackageAssets)
            .insert(
              StorageFixtures.packageAsset('scope-a', 'pkg-2', 'asset', 'r1'),
            );
        await offlineDatabase
            .into(offlineDatabase.dwOfflinePackageAssets)
            .insert(
              StorageFixtures.packageAsset('scope-a', 'pkg-1', 'asset', 'r2'),
            );
        await expectLater(
          offlineDatabase
              .into(offlineDatabase.dwOfflinePackageAssets)
              .insert(firstEdge),
          throwsA(isA<Exception>()),
        );

        expect(
          await offlineDatabase.select(offlineDatabase.dwOfflineAssets).get(),
          hasLength(2),
        );
        expect(
          await offlineDatabase
              .select(offlineDatabase.dwOfflinePackageAssets)
              .get(),
          hasLength(3),
        );
      },
    );

    test('job package foreign key is scope-bound and cascades', () async {
      await StorageFixtures.insertPackage(offlineDatabase, 'scope-a', 'pkg');
      await StorageFixtures.insertPackage(offlineDatabase, 'scope-b', 'pkg');
      await offlineDatabase
          .into(offlineDatabase.dwOfflineJobs)
          .insert(StorageFixtures.job('scope-a', 'job', packageId: 'pkg'));
      await offlineDatabase
          .into(offlineDatabase.dwOfflineJobs)
          .insert(StorageFixtures.job('scope-b', 'job', packageId: 'pkg'));

      await expectLater(
        offlineDatabase
            .into(offlineDatabase.dwOfflineJobs)
            .insert(StorageFixtures.job('scope-a', 'job', packageId: 'pkg')),
        throwsA(isA<Exception>()),
      );
      await (offlineDatabase.delete(offlineDatabase.dwOfflinePackages)..where(
            (row) =>
                row.userScopeId.equals('scope-a') & row.packageId.equals('pkg'),
          ))
          .go();

      final remainingJobs = await offlineDatabase
          .select(offlineDatabase.dwOfflineJobs)
          .get();
      expect(remainingJobs, hasLength(1));
      expect(remainingJobs.single.userScopeId, 'scope-b');
    });

    test('download scheduling state is durable and scope-bound', () async {
      await StorageFixtures.insertPackage(offlineDatabase, 'scope-a', 'pkg');
      await StorageFixtures.insertAsset(
        offlineDatabase,
        'scope-a',
        'asset',
        'r1',
      );
      await offlineDatabase
          .into(offlineDatabase.dwOfflineJobs)
          .insert(
            StorageFixtures.job(
              'scope-a',
              'job',
              packageId: 'pkg',
              manifestRevision: 'manifest-r1',
              manifestDigest: 'manifest-digest',
              priority: 7,
              packageTotalBytes: 101000000,
              consentedManifestDigest: 'manifest-digest',
              nextEligibleAtEpochMs: StorageFixtures.timestampEpochMs + 5000,
              pauseReason: 'network',
            ),
          );
      await offlineDatabase
          .into(offlineDatabase.dwOfflineDownloadTasks)
          .insert(
            StorageFixtures.downloadTask(
              'scope-a',
              'job',
              'asset',
              'r1',
              nativeTaskId: 'native-task',
              temporaryFilePath: 'temporary/asset-r1',
              transferredBytes: 64,
              nextEligibleAtEpochMs: StorageFixtures.timestampEpochMs + 5000,
            ),
          );

      final job = await offlineDatabase
          .select(offlineDatabase.dwOfflineJobs)
          .getSingle();
      final task = await offlineDatabase
          .select(offlineDatabase.dwOfflineDownloadTasks)
          .getSingle();
      expect(job.manifestRevision, 'manifest-r1');
      expect(job.manifestDigest, 'manifest-digest');
      expect(job.priority, 7);
      expect(job.packageTotalBytes, 101000000);
      expect(job.consentedManifestDigest, 'manifest-digest');
      expect(
        job.nextEligibleAtEpochMs,
        StorageFixtures.timestampEpochMs + 5000,
      );
      expect(job.pauseReason, 'network');
      expect(task.nativeTaskId, 'native-task');
      expect(task.temporaryFilePath, 'temporary/asset-r1');
      expect(task.transferredBytes, 64);

      await (offlineDatabase.delete(offlineDatabase.dwOfflineJobs)..where(
            (row) =>
                row.userScopeId.equals('scope-a') & row.jobId.equals('job'),
          ))
          .go();
      expect(
        await offlineDatabase
            .select(offlineDatabase.dwOfflineDownloadTasks)
            .get(),
        isEmpty,
      );
    });

    test('standalone records use scope-qualified identities', () async {
      await offlineDatabase
          .into(offlineDatabase.dwOfflineSnapshots)
          .insert(StorageFixtures.snapshot('scope-a', 'query'));
      await offlineDatabase
          .into(offlineDatabase.dwOfflineSnapshots)
          .insert(StorageFixtures.snapshot('scope-b', 'query'));
      await offlineDatabase
          .into(offlineDatabase.dwOfflineLeases)
          .insert(StorageFixtures.lease('scope-a', 'lease'));
      await offlineDatabase
          .into(offlineDatabase.dwOfflineLeases)
          .insert(StorageFixtures.lease('scope-b', 'lease'));

      await expectLater(
        offlineDatabase
            .into(offlineDatabase.dwOfflineSnapshots)
            .insert(StorageFixtures.snapshot('scope-a', 'query')),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        offlineDatabase
            .into(offlineDatabase.dwOfflineLeases)
            .insert(StorageFixtures.lease('scope-a', 'lease')),
        throwsA(isA<Exception>()),
      );
    });

    test('reader pins are scope-bound and restrict asset deletion', () async {
      await StorageFixtures.insertAsset(
        offlineDatabase,
        'scope-a',
        'asset',
        'r1',
      );
      await StorageFixtures.insertAsset(
        offlineDatabase,
        'scope-a',
        'asset',
        'r2',
      );
      await StorageFixtures.insertAsset(
        offlineDatabase,
        'scope-b',
        'asset',
        'r1',
      );
      await offlineDatabase
          .into(offlineDatabase.dwOfflineReaderPins)
          .insert(
            StorageFixtures.readerPin('scope-a', 'reader', 'asset', 'r1'),
          );
      await offlineDatabase
          .into(offlineDatabase.dwOfflineReaderPins)
          .insert(
            StorageFixtures.readerPin('scope-b', 'reader', 'asset', 'r1'),
          );
      await offlineDatabase
          .into(offlineDatabase.dwOfflineReaderPins)
          .insert(
            StorageFixtures.readerPin('scope-a', 'reader', 'asset', 'r2'),
          );

      await expectLater(
        offlineDatabase
            .into(offlineDatabase.dwOfflineReaderPins)
            .insert(
              StorageFixtures.readerPin('scope-a', 'reader', 'asset', 'r1'),
            ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        (offlineDatabase.delete(offlineDatabase.dwOfflineAssets)..where(
              (row) =>
                  row.userScopeId.equals('scope-a') &
                  row.assetId.equals('asset') &
                  row.assetRevision.equals('r1'),
            ))
            .go(),
        throwsA(isA<Exception>()),
      );

      final remainingPins = await offlineDatabase
          .select(offlineDatabase.dwOfflineReaderPins)
          .get();
      expect(remainingPins, hasLength(3));
      expect(remainingPins.map((pinRow) => pinRow.assetRevision).toSet(), {
        'r1',
        'r2',
      });
    });

    test('outbox mutation identity is unique within a scope only', () async {
      await offlineDatabase
          .into(offlineDatabase.dwOfflineOutbox)
          .insert(StorageFixtures.outbox('scope-a', 'mutation', 'entity-a'));
      await offlineDatabase
          .into(offlineDatabase.dwOfflineOutbox)
          .insert(StorageFixtures.outbox('scope-b', 'mutation', 'entity-a'));

      await expectLater(
        offlineDatabase
            .into(offlineDatabase.dwOfflineOutbox)
            .insert(StorageFixtures.outbox('scope-a', 'mutation', 'entity-b')),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('DwOfflineDatabase transactions', () {
    late DwOfflineDatabase offlineDatabase;

    setUp(() {
      offlineDatabase = DwOfflineDatabase(NativeDatabase.memory());
    });

    tearDown(() => offlineDatabase.close());

    test(
      'manifest activation replaces edges and clears staging atomically',
      () async {
        await StorageFixtures.insertPackage(
          offlineDatabase,
          'scope-a',
          'pkg',
          activeRevision: 'manifest-1',
          stagingRevision: 'manifest-2',
        );
        await StorageFixtures.insertAsset(
          offlineDatabase,
          'scope-a',
          'old',
          'r1',
          refCount: 1,
        );
        await StorageFixtures.insertAsset(
          offlineDatabase,
          'scope-a',
          'new',
          'r2',
        );
        await offlineDatabase
            .into(offlineDatabase.dwOfflinePackageAssets)
            .insert(
              StorageFixtures.packageAsset('scope-a', 'pkg', 'old', 'r1'),
            );

        await offlineDatabase.activateManifest(
          userScopeId: 'scope-a',
          packageId: 'pkg',
          stagingManifestRevision: 'manifest-2',
          assetReferences: const [
            DwOfflineManifestAssetReference(
              assetId: 'new',
              assetRevision: 'r2',
              isRequired: true,
            ),
          ],
        );

        final packageRow =
            await (offlineDatabase.select(offlineDatabase.dwOfflinePackages)
                  ..where(
                    (row) =>
                        row.userScopeId.equals('scope-a') &
                        row.packageId.equals('pkg'),
                  ))
                .getSingle();
        final edgeRows = await offlineDatabase
            .select(offlineDatabase.dwOfflinePackageAssets)
            .get();
        expect(packageRow.activeManifestRevision, 'manifest-2');
        expect(packageRow.stagingManifestRevision, isNull);
        expect(edgeRows.single.assetId, 'new');
        expect(
          await StorageFixtures.assetRefCount(
            offlineDatabase,
            'scope-a',
            'old',
            'r1',
          ),
          0,
        );
        expect(
          await StorageFixtures.assetRefCount(
            offlineDatabase,
            'scope-a',
            'new',
            'r2',
          ),
          1,
        );
      },
    );

    test(
      'activation applies distinct edge ownership delta and preserves shared owners',
      () async {
        await StorageFixtures.insertPackage(
          offlineDatabase,
          'scope-a',
          'pkg-1',
          activeRevision: 'manifest-1',
          stagingRevision: 'manifest-2',
        );
        await StorageFixtures.insertPackage(
          offlineDatabase,
          'scope-a',
          'pkg-2',
        );
        await StorageFixtures.insertAsset(
          offlineDatabase,
          'scope-a',
          'removed',
          'r1',
          refCount: 1,
        );
        await StorageFixtures.insertAsset(
          offlineDatabase,
          'scope-a',
          'unchanged',
          'r1',
          refCount: 2,
        );
        await StorageFixtures.insertAsset(
          offlineDatabase,
          'scope-a',
          'added',
          'r1',
        );
        await offlineDatabase
            .into(offlineDatabase.dwOfflinePackageAssets)
            .insert(
              StorageFixtures.packageAsset('scope-a', 'pkg-1', 'removed', 'r1'),
            );
        await offlineDatabase
            .into(offlineDatabase.dwOfflinePackageAssets)
            .insert(
              StorageFixtures.packageAsset(
                'scope-a',
                'pkg-1',
                'unchanged',
                'r1',
              ),
            );
        await offlineDatabase
            .into(offlineDatabase.dwOfflinePackageAssets)
            .insert(
              StorageFixtures.packageAsset(
                'scope-a',
                'pkg-2',
                'unchanged',
                'r1',
              ),
            );

        await offlineDatabase.activateManifest(
          userScopeId: 'scope-a',
          packageId: 'pkg-1',
          stagingManifestRevision: 'manifest-2',
          assetReferences: const [
            DwOfflineManifestAssetReference(
              assetId: 'unchanged',
              assetRevision: 'r1',
              isRequired: true,
            ),
            DwOfflineManifestAssetReference(
              assetId: 'added',
              assetRevision: 'r1',
              isRequired: true,
            ),
            DwOfflineManifestAssetReference(
              assetId: 'added',
              assetRevision: 'r1',
              isRequired: true,
            ),
          ],
        );

        expect(
          await StorageFixtures.assetRefCount(
            offlineDatabase,
            'scope-a',
            'removed',
            'r1',
          ),
          0,
        );
        expect(
          await StorageFixtures.assetRefCount(
            offlineDatabase,
            'scope-a',
            'unchanged',
            'r1',
          ),
          2,
        );
        expect(
          await StorageFixtures.assetRefCount(
            offlineDatabase,
            'scope-a',
            'added',
            'r1',
          ),
          1,
        );
        final packageOneEdges = await (offlineDatabase.select(
          offlineDatabase.dwOfflinePackageAssets,
        )..where((row) => row.packageId.equals('pkg-1'))).get();
        expect(packageOneEdges.map((row) => row.assetId).toSet(), {
          'unchanged',
          'added',
        });
      },
    );

    test(
      'activation rejects a stale staging revision without mutation',
      () async {
        await StorageFixtures.insertPackage(
          offlineDatabase,
          'scope-a',
          'pkg',
          activeRevision: 'manifest-1',
          stagingRevision: 'manifest-2',
        );
        await StorageFixtures.insertAsset(
          offlineDatabase,
          'scope-a',
          'asset',
          'r1',
          refCount: 1,
        );
        await offlineDatabase
            .into(offlineDatabase.dwOfflinePackageAssets)
            .insert(
              StorageFixtures.packageAsset('scope-a', 'pkg', 'asset', 'r1'),
            );

        await expectLater(
          offlineDatabase.activateManifest(
            userScopeId: 'scope-a',
            packageId: 'pkg',
            stagingManifestRevision: 'stale',
            assetReferences: const [],
          ),
          throwsStateError,
        );

        final packageRow = await offlineDatabase
            .select(offlineDatabase.dwOfflinePackages)
            .getSingle();
        expect(packageRow.activeManifestRevision, 'manifest-1');
        expect(packageRow.stagingManifestRevision, 'manifest-2');
        expect(
          await offlineDatabase
              .select(offlineDatabase.dwOfflinePackageAssets)
              .get(),
          hasLength(1),
        );
        expect(
          await StorageFixtures.assetRefCount(
            offlineDatabase,
            'scope-a',
            'asset',
            'r1',
          ),
          1,
        );
      },
    );

    test(
      'empty manifest atomically clears edges and ownership counts',
      () async {
        await StorageFixtures.insertPackage(
          offlineDatabase,
          'scope-a',
          'pkg',
          activeRevision: 'manifest-1',
          stagingRevision: 'manifest-empty',
        );
        await StorageFixtures.insertAsset(
          offlineDatabase,
          'scope-a',
          'asset',
          'r1',
          refCount: 1,
        );
        await offlineDatabase
            .into(offlineDatabase.dwOfflinePackageAssets)
            .insert(
              StorageFixtures.packageAsset('scope-a', 'pkg', 'asset', 'r1'),
            );

        await offlineDatabase.activateManifest(
          userScopeId: 'scope-a',
          packageId: 'pkg',
          stagingManifestRevision: 'manifest-empty',
          assetReferences: const [],
        );

        expect(
          await offlineDatabase
              .select(offlineDatabase.dwOfflinePackageAssets)
              .get(),
          isEmpty,
        );
        expect(
          await StorageFixtures.assetRefCount(
            offlineDatabase,
            'scope-a',
            'asset',
            'r1',
          ),
          0,
        );
      },
    );

    test(
      'activation changes only the requested scope ownership graph',
      () async {
        for (final userScopeId in ['scope-a', 'scope-b']) {
          await StorageFixtures.insertPackage(
            offlineDatabase,
            userScopeId,
            'pkg',
            activeRevision: 'manifest-1',
            stagingRevision: 'manifest-2',
          );
          await StorageFixtures.insertAsset(
            offlineDatabase,
            userScopeId,
            'old',
            'r1',
            refCount: 1,
          );
          await StorageFixtures.insertAsset(
            offlineDatabase,
            userScopeId,
            'new',
            'r1',
          );
          await offlineDatabase
              .into(offlineDatabase.dwOfflinePackageAssets)
              .insert(
                StorageFixtures.packageAsset(userScopeId, 'pkg', 'old', 'r1'),
              );
        }

        await offlineDatabase.activateManifest(
          userScopeId: 'scope-a',
          packageId: 'pkg',
          stagingManifestRevision: 'manifest-2',
          assetReferences: const [
            DwOfflineManifestAssetReference(
              assetId: 'new',
              assetRevision: 'r1',
              isRequired: true,
            ),
          ],
        );

        expect(
          await StorageFixtures.assetRefCount(
            offlineDatabase,
            'scope-a',
            'old',
            'r1',
          ),
          0,
        );
        expect(
          await StorageFixtures.assetRefCount(
            offlineDatabase,
            'scope-a',
            'new',
            'r1',
          ),
          1,
        );
        expect(
          await StorageFixtures.assetRefCount(
            offlineDatabase,
            'scope-b',
            'old',
            'r1',
          ),
          1,
        );
        expect(
          await StorageFixtures.assetRefCount(
            offlineDatabase,
            'scope-b',
            'new',
            'r1',
          ),
          0,
        );
      },
    );

    test(
      'failed activation rolls back edge replacement and package state',
      () async {
        await StorageFixtures.insertPackage(
          offlineDatabase,
          'scope-a',
          'pkg',
          activeRevision: 'manifest-1',
          stagingRevision: 'manifest-2',
        );
        await StorageFixtures.insertAsset(
          offlineDatabase,
          'scope-a',
          'old',
          'r1',
          refCount: 1,
        );
        await StorageFixtures.insertAsset(
          offlineDatabase,
          'scope-a',
          'new',
          'r2',
        );
        await offlineDatabase
            .into(offlineDatabase.dwOfflinePackageAssets)
            .insert(
              StorageFixtures.packageAsset('scope-a', 'pkg', 'old', 'r1'),
            );

        await expectLater(
          offlineDatabase.activateManifest(
            userScopeId: 'scope-a',
            packageId: 'pkg',
            stagingManifestRevision: 'manifest-2',
            assetReferences: const [
              DwOfflineManifestAssetReference(
                assetId: 'new',
                assetRevision: 'r2',
                isRequired: true,
              ),
              DwOfflineManifestAssetReference(
                assetId: 'missing',
                assetRevision: 'r1',
                isRequired: false,
              ),
            ],
          ),
          throwsStateError,
        );

        final packageRow =
            await (offlineDatabase.select(offlineDatabase.dwOfflinePackages)
                  ..where(
                    (row) =>
                        row.userScopeId.equals('scope-a') &
                        row.packageId.equals('pkg'),
                  ))
                .getSingle();
        final edgeRows = await offlineDatabase
            .select(offlineDatabase.dwOfflinePackageAssets)
            .get();
        expect(packageRow.activeManifestRevision, 'manifest-1');
        expect(packageRow.stagingManifestRevision, 'manifest-2');
        expect(edgeRows.single.assetId, 'old');
        expect(
          await StorageFixtures.assetRefCount(
            offlineDatabase,
            'scope-a',
            'old',
            'r1',
          ),
          1,
        );
        expect(
          await StorageFixtures.assetRefCount(
            offlineDatabase,
            'scope-a',
            'new',
            'r2',
          ),
          0,
        );
      },
    );

    test(
      'late activation failure rolls back package edges and refcount deltas',
      () async {
        await StorageFixtures.insertPackage(
          offlineDatabase,
          'scope-a',
          'pkg',
          activeRevision: 'manifest-1',
          stagingRevision: 'manifest-2',
        );
        await StorageFixtures.insertAsset(
          offlineDatabase,
          'scope-a',
          'old',
          'r1',
          refCount: 1,
        );
        await StorageFixtures.insertAsset(
          offlineDatabase,
          'scope-a',
          'new',
          'r1',
        );
        await offlineDatabase
            .into(offlineDatabase.dwOfflinePackageAssets)
            .insert(
              StorageFixtures.packageAsset('scope-a', 'pkg', 'old', 'r1'),
            );
        await offlineDatabase.customStatement('''
          CREATE TEMP TRIGGER abort_late_manifest_activation
          BEFORE INSERT ON dw_offline_package_assets
          WHEN NEW.user_scope_id = 'scope-a'
            AND NEW.package_id = 'pkg'
            AND NEW.asset_id = 'new'
          BEGIN
            SELECT RAISE(ABORT, 'forced late activation failure');
          END
        ''');

        try {
          await expectLater(
            offlineDatabase.activateManifest(
              userScopeId: 'scope-a',
              packageId: 'pkg',
              stagingManifestRevision: 'manifest-2',
              assetReferences: const [
                DwOfflineManifestAssetReference(
                  assetId: 'new',
                  assetRevision: 'r1',
                  isRequired: true,
                ),
              ],
            ),
            throwsA(isA<Exception>()),
          );

          final packageRow = await offlineDatabase
              .select(offlineDatabase.dwOfflinePackages)
              .getSingle();
          final edgeRows = await offlineDatabase
              .select(offlineDatabase.dwOfflinePackageAssets)
              .get();
          expect(packageRow.activeManifestRevision, 'manifest-1');
          expect(packageRow.stagingManifestRevision, 'manifest-2');
          expect(edgeRows, hasLength(1));
          expect(edgeRows.single.assetId, 'old');
          expect(
            await StorageFixtures.assetRefCount(
              offlineDatabase,
              'scope-a',
              'old',
              'r1',
            ),
            1,
          );
          expect(
            await StorageFixtures.assetRefCount(
              offlineDatabase,
              'scope-a',
              'new',
              'r1',
            ),
            0,
          );
        } finally {
          await offlineDatabase.customStatement(
            'DROP TRIGGER IF EXISTS abort_late_manifest_activation',
          );
        }
      },
    );

    test(
      'refcount increments, decrements, and never becomes negative',
      () async {
        await StorageFixtures.insertAsset(
          offlineDatabase,
          'scope-a',
          'asset',
          'r1',
        );

        expect(
          await offlineDatabase.incrementAssetRefCount(
            userScopeId: 'scope-a',
            assetId: 'asset',
            assetRevision: 'r1',
          ),
          1,
        );
        expect(
          await offlineDatabase.decrementAssetRefCount(
            userScopeId: 'scope-a',
            assetId: 'asset',
            assetRevision: 'r1',
          ),
          0,
        );
        await expectLater(
          offlineDatabase.decrementAssetRefCount(
            userScopeId: 'scope-a',
            assetId: 'asset',
            assetRevision: 'r1',
          ),
          throwsStateError,
        );

        final assetRow = await offlineDatabase
            .select(offlineDatabase.dwOfflineAssets)
            .getSingle();
        expect(assetRow.refCount, 0);
      },
    );

    test(
      'outbox coalescing keeps queue position and latest intent envelope',
      () async {
        await offlineDatabase.coalesceOutboxIntent(
          StorageFixtures.outbox(
            'scope-a',
            'mutation-1',
            'entity',
            mutationType: 'save',
            envelope: '{"version":1}',
            createdAtEpochMs: 100,
            updatedAtEpochMs: 100,
          ),
        );
        await offlineDatabase.coalesceOutboxIntent(
          StorageFixtures.outbox(
            'scope-a',
            'mutation-2',
            'entity',
            mutationType: 'delete',
            envelope: '{"version":2}',
            createdAtEpochMs: 200,
            updatedAtEpochMs: 200,
          ),
        );

        final outboxRows = await offlineDatabase
            .select(offlineDatabase.dwOfflineOutbox)
            .get();
        expect(outboxRows, hasLength(1));
        expect(outboxRows.single.mutationId, 'mutation-2');
        expect(outboxRows.single.mutationType, 'delete');
        expect(outboxRows.single.idempotencyKey, 'idem-mutation-2');
        expect(outboxRows.single.envelopeJson, '{"version":2}');
        expect(outboxRows.single.createdAtEpochMs, 100);
        expect(outboxRows.single.updatedAtEpochMs, 200);
      },
    );

    test('failed outbox replacement restores the original intent', () async {
      await offlineDatabase.coalesceOutboxIntent(
        StorageFixtures.outbox(
          'scope-a',
          'mutation-1',
          'entity-1',
          envelope: '{"original":true}',
          createdAtEpochMs: 100,
          updatedAtEpochMs: 100,
        ),
      );
      await offlineDatabase.coalesceOutboxIntent(
        StorageFixtures.outbox(
          'scope-a',
          'mutation-2',
          'entity-2',
          createdAtEpochMs: 150,
          updatedAtEpochMs: 150,
        ),
      );

      await expectLater(
        offlineDatabase.coalesceOutboxIntent(
          StorageFixtures.outbox(
            'scope-a',
            'mutation-2',
            'entity-1',
            envelope: '{"replacement":true}',
            createdAtEpochMs: 200,
            updatedAtEpochMs: 200,
          ),
        ),
        throwsA(isA<Exception>()),
      );

      final outboxRows = await (offlineDatabase.select(
        offlineDatabase.dwOfflineOutbox,
      )..orderBy([(row) => OrderingTerm.asc(row.entityId)])).get();
      expect(outboxRows, hasLength(2));
      expect(outboxRows.first.mutationId, 'mutation-1');
      expect(outboxRows.first.envelopeJson, '{"original":true}');
      expect(outboxRows.first.createdAtEpochMs, 100);
      expect(outboxRows.last.mutationId, 'mutation-2');
      expect(outboxRows.last.entityId, 'entity-2');
    });

    test('outbox coalescing key is unique per scope and entity type', () async {
      await offlineDatabase
          .into(offlineDatabase.dwOfflineOutbox)
          .insert(StorageFixtures.outbox('scope-a', 'mutation-1', 'entity'));
      await offlineDatabase
          .into(offlineDatabase.dwOfflineOutbox)
          .insert(
            StorageFixtures.outbox(
              'scope-a',
              'mutation-2',
              'entity',
              entityType: 'other',
            ),
          );
      await offlineDatabase
          .into(offlineDatabase.dwOfflineOutbox)
          .insert(StorageFixtures.outbox('scope-b', 'mutation-3', 'entity'));

      await expectLater(
        offlineDatabase
            .into(offlineDatabase.dwOfflineOutbox)
            .insert(StorageFixtures.outbox('scope-a', 'mutation-4', 'entity')),
        throwsA(isA<Exception>()),
      );
    });

    test('full scope purge leaves another scope untouched', () async {
      for (final userScopeId in ['scope-a', 'scope-b']) {
        await StorageFixtures.insertPackage(
          offlineDatabase,
          userScopeId,
          'pkg',
        );
        await StorageFixtures.insertAsset(
          offlineDatabase,
          userScopeId,
          'asset',
          'r1',
        );
        await offlineDatabase
            .into(offlineDatabase.dwOfflinePackageAssets)
            .insert(
              StorageFixtures.packageAsset(userScopeId, 'pkg', 'asset', 'r1'),
            );
        await offlineDatabase
            .into(offlineDatabase.dwOfflineJobs)
            .insert(StorageFixtures.job(userScopeId, 'job', packageId: 'pkg'));
        await offlineDatabase
            .into(offlineDatabase.dwOfflineSnapshots)
            .insert(StorageFixtures.snapshot(userScopeId, 'query'));
        await offlineDatabase
            .into(offlineDatabase.dwOfflineOutbox)
            .insert(StorageFixtures.outbox(userScopeId, 'mutation', 'entity'));
        await offlineDatabase
            .into(offlineDatabase.dwOfflineLeases)
            .insert(StorageFixtures.lease(userScopeId, 'lease'));
        await offlineDatabase
            .into(offlineDatabase.dwOfflineReaderPins)
            .insert(
              StorageFixtures.readerPin(userScopeId, 'reader', 'asset', 'r1'),
            );
      }

      await offlineDatabase.purgeUserScope('scope-a');

      final packageRows = await offlineDatabase
          .select(offlineDatabase.dwOfflinePackages)
          .get();
      final assetRows = await offlineDatabase
          .select(offlineDatabase.dwOfflineAssets)
          .get();
      final edgeRows = await offlineDatabase
          .select(offlineDatabase.dwOfflinePackageAssets)
          .get();
      final jobRows = await offlineDatabase
          .select(offlineDatabase.dwOfflineJobs)
          .get();
      final snapshotRows = await offlineDatabase
          .select(offlineDatabase.dwOfflineSnapshots)
          .get();
      final outboxRows = await offlineDatabase
          .select(offlineDatabase.dwOfflineOutbox)
          .get();
      final leaseRows = await offlineDatabase
          .select(offlineDatabase.dwOfflineLeases)
          .get();
      final pinRows = await offlineDatabase
          .select(offlineDatabase.dwOfflineReaderPins)
          .get();
      expect(packageRows.single.userScopeId, 'scope-b');
      expect(assetRows.single.userScopeId, 'scope-b');
      expect(edgeRows.single.userScopeId, 'scope-b');
      expect(jobRows.single.userScopeId, 'scope-b');
      expect(snapshotRows.single.userScopeId, 'scope-b');
      expect(outboxRows.single.userScopeId, 'scope-b');
      expect(leaseRows.single.userScopeId, 'scope-b');
      expect(pinRows.single.userScopeId, 'scope-b');
    });

    test('failed scope purge rolls back every affected table', () async {
      for (final userScopeId in ['scope-a', 'scope-b']) {
        await StorageFixtures.insertPackage(
          offlineDatabase,
          userScopeId,
          'pkg',
        );
        await StorageFixtures.insertAsset(
          offlineDatabase,
          userScopeId,
          'asset',
          'r1',
          refCount: 1,
        );
        await offlineDatabase
            .into(offlineDatabase.dwOfflinePackageAssets)
            .insert(
              StorageFixtures.packageAsset(userScopeId, 'pkg', 'asset', 'r1'),
            );
        await offlineDatabase
            .into(offlineDatabase.dwOfflineJobs)
            .insert(StorageFixtures.job(userScopeId, 'job', packageId: 'pkg'));
        await offlineDatabase
            .into(offlineDatabase.dwOfflineSnapshots)
            .insert(StorageFixtures.snapshot(userScopeId, 'query'));
        await offlineDatabase
            .into(offlineDatabase.dwOfflineOutbox)
            .insert(StorageFixtures.outbox(userScopeId, 'mutation', 'entity'));
        await offlineDatabase
            .into(offlineDatabase.dwOfflineLeases)
            .insert(StorageFixtures.lease(userScopeId, 'lease'));
        await offlineDatabase
            .into(offlineDatabase.dwOfflineReaderPins)
            .insert(
              StorageFixtures.readerPin(userScopeId, 'reader', 'asset', 'r1'),
            );
      }
      await offlineDatabase.customStatement('''
        CREATE TEMP TRIGGER abort_scope_purge
        BEFORE DELETE ON dw_offline_packages
        WHEN OLD.user_scope_id = 'scope-a'
        BEGIN
          SELECT RAISE(ABORT, 'forced purge failure');
        END
      ''');

      await expectLater(
        offlineDatabase.purgeUserScope('scope-a'),
        throwsA(isA<Exception>()),
      );

      expect(
        (await offlineDatabase.select(offlineDatabase.dwOfflinePackages).get())
            .map((row) => row.userScopeId)
            .toSet(),
        {'scope-a', 'scope-b'},
      );
      expect(
        (await offlineDatabase.select(offlineDatabase.dwOfflineAssets).get())
            .map((row) => row.userScopeId)
            .toSet(),
        {'scope-a', 'scope-b'},
      );
      expect(
        (await offlineDatabase
                .select(offlineDatabase.dwOfflinePackageAssets)
                .get())
            .map((row) => row.userScopeId)
            .toSet(),
        {'scope-a', 'scope-b'},
      );
      expect(
        (await offlineDatabase.select(offlineDatabase.dwOfflineJobs).get())
            .map((row) => row.userScopeId)
            .toSet(),
        {'scope-a', 'scope-b'},
      );
      expect(
        (await offlineDatabase.select(offlineDatabase.dwOfflineSnapshots).get())
            .map((row) => row.userScopeId)
            .toSet(),
        {'scope-a', 'scope-b'},
      );
      expect(
        (await offlineDatabase.select(offlineDatabase.dwOfflineOutbox).get())
            .map((row) => row.userScopeId)
            .toSet(),
        {'scope-a', 'scope-b'},
      );
      expect(
        (await offlineDatabase.select(offlineDatabase.dwOfflineLeases).get())
            .map((row) => row.userScopeId)
            .toSet(),
        {'scope-a', 'scope-b'},
      );
      expect(
        (await offlineDatabase
                .select(offlineDatabase.dwOfflineReaderPins)
                .get())
            .map((row) => row.userScopeId)
            .toSet(),
        {'scope-a', 'scope-b'},
      );
    });
  });

  group('DwOfflineDatabase persistence', () {
    test('reopens a temporary-file database with stored rows intact', () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'dw_offline_reopen_',
      );
      final databaseFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}offline.sqlite',
      );

      try {
        final initialDatabase = DwOfflineDatabase(NativeDatabase(databaseFile));
        await StorageFixtures.insertPackage(initialDatabase, 'scope-a', 'pkg');
        await initialDatabase.close();

        final reopenedDatabase = DwOfflineDatabase(
          NativeDatabase(databaseFile),
        );
        final packageRows = await reopenedDatabase
            .select(reopenedDatabase.dwOfflinePackages)
            .get();
        expect(packageRows.single.packageId, 'pkg');
        await reopenedDatabase.close();
      } finally {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('migrates a persisted v1 database without losing data', () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'dw_offline_v1_',
      );
      final databaseFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}offline.sqlite',
      );

      try {
        final versionOneExecutor = NativeDatabase(
          databaseFile,
          enableMigrations: false,
          setup: (fixtureDatabase) {
            for (final ddlStatement in FrozenVersionOneFixture.versionOneDdl) {
              fixtureDatabase.execute(ddlStatement);
            }
            fixtureDatabase.execute('PRAGMA foreign_keys = ON');
            for (final seedStatement
                in FrozenVersionOneFixture.versionOneSeedSql) {
              fixtureDatabase.execute(seedStatement);
            }
            fixtureDatabase.execute('PRAGMA user_version = 1');
          },
        );
        try {
          await versionOneExecutor.ensureOpen(FrozenVersionOneFixture());
          final versionRows = await versionOneExecutor.runSelect(
            'PRAGMA user_version',
            const [],
          );
          final tableRows = await versionOneExecutor.runSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name LIKE 'dw_offline_%' ORDER BY name",
            const [],
          );
          final packageSeedRows = await versionOneExecutor.runSelect(
            'SELECT package_id FROM dw_offline_packages',
            const [],
          );
          final assetSeedRows = await versionOneExecutor.runSelect(
            'SELECT asset_id FROM dw_offline_assets',
            const [],
          );
          final edgeSeedRows = await versionOneExecutor.runSelect(
            'SELECT package_id FROM dw_offline_package_assets',
            const [],
          );
          final jobSeedRows = await versionOneExecutor.runSelect(
            'SELECT job_id FROM dw_offline_jobs',
            const [],
          );
          final snapshotSeedRows = await versionOneExecutor.runSelect(
            'SELECT query_key FROM dw_offline_snapshots',
            const [],
          );
          final outboxSeedRows = await versionOneExecutor.runSelect(
            'SELECT mutation_id FROM dw_offline_outbox',
            const [],
          );
          final leaseSeedRows = await versionOneExecutor.runSelect(
            'SELECT lease_id FROM dw_offline_leases',
            const [],
          );
          expect(versionRows.single['user_version'], 1);
          expect(tableRows.map((row) => row['name']).toSet(), {
            'dw_offline_assets',
            'dw_offline_jobs',
            'dw_offline_leases',
            'dw_offline_outbox',
            'dw_offline_package_assets',
            'dw_offline_packages',
            'dw_offline_snapshots',
          });
          expect(packageSeedRows.single['package_id'], 'pkg');
          expect(assetSeedRows.single['asset_id'], 'asset');
          expect(edgeSeedRows.single['package_id'], 'pkg');
          expect(jobSeedRows.single['job_id'], 'job');
          expect(snapshotSeedRows.single['query_key'], 'query');
          expect(outboxSeedRows.single['mutation_id'], 'mutation');
          expect(leaseSeedRows.single['lease_id'], 'lease');
        } finally {
          await versionOneExecutor.close();
        }

        final migratedDatabase = DwOfflineDatabase(
          NativeDatabase(databaseFile),
        );
        final migratedVersion = await migratedDatabase
            .customSelect('PRAGMA user_version')
            .getSingle();
        final packageRows = await migratedDatabase
            .select(migratedDatabase.dwOfflinePackages)
            .get();
        final assetRows = await migratedDatabase
            .select(migratedDatabase.dwOfflineAssets)
            .get();
        final edgeRows = await migratedDatabase
            .select(migratedDatabase.dwOfflinePackageAssets)
            .get();
        final jobRows = await migratedDatabase
            .select(migratedDatabase.dwOfflineJobs)
            .get();
        final snapshotRows = await migratedDatabase
            .select(migratedDatabase.dwOfflineSnapshots)
            .get();
        final outboxRows = await migratedDatabase
            .select(migratedDatabase.dwOfflineOutbox)
            .get();
        final leaseRows = await migratedDatabase
            .select(migratedDatabase.dwOfflineLeases)
            .get();
        expect(
          migratedVersion.read<int>('user_version'),
          DwOfflineDatabase.currentSchemaVersion,
        );
        expect(packageRows.single.packageId, 'pkg');
        expect(assetRows.single.assetId, 'asset');
        expect(edgeRows.single.packageId, 'pkg');
        expect(jobRows.single.jobId, 'job');
        expect(jobRows.single.priority, 0);
        expect(jobRows.single.manifestRevision, isNull);
        expect(
          await migratedDatabase
              .select(migratedDatabase.dwOfflineDownloadTasks)
              .get(),
          isEmpty,
        );
        expect(snapshotRows.single.queryKey, 'query');
        expect(outboxRows.single.mutationId, 'mutation');
        expect(leaseRows.single.leaseId, 'lease');

        await migratedDatabase
            .into(migratedDatabase.dwOfflineReaderPins)
            .insert(
              StorageFixtures.readerPin('scope-a', 'reader', 'asset', 'r1'),
            );
        expect(
          await migratedDatabase
              .select(migratedDatabase.dwOfflineReaderPins)
              .get(),
          hasLength(1),
        );
        await migratedDatabase.close();
      } finally {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test(
      'migrates a persisted v2 database and rebuilds reader restriction',
      () async {
        final temporaryDirectory = await Directory.systemTemp.createTemp(
          'dw_offline_v2_',
        );
        final databaseFile = File(
          '${temporaryDirectory.path}${Platform.pathSeparator}offline.sqlite',
        );
        try {
          final versionTwoExecutor = NativeDatabase(
            databaseFile,
            enableMigrations: false,
            setup: (fixtureDatabase) {
              for (final ddlStatement
                  in FrozenVersionTwoFixture.versionTwoDdl) {
                fixtureDatabase.execute(ddlStatement);
              }
              fixtureDatabase.execute('PRAGMA foreign_keys = ON');
              for (final seedStatement
                  in FrozenVersionTwoFixture.versionTwoSeedSql) {
                fixtureDatabase.execute(seedStatement);
              }
              fixtureDatabase.execute('PRAGMA user_version = 2');
            },
          );
          await versionTwoExecutor.ensureOpen(FrozenVersionTwoFixture());
          await versionTwoExecutor.close();

          final migratedDatabase = DwOfflineDatabase(
            NativeDatabase(databaseFile),
          );
          expect(
            (await migratedDatabase
                    .customSelect('PRAGMA user_version')
                    .getSingle())
                .read<int>('user_version'),
            DwOfflineDatabase.currentSchemaVersion,
          );
          expect(
            await migratedDatabase
                .select(migratedDatabase.dwOfflineReaderPins)
                .get(),
            hasLength(1),
          );
          await expectLater(
            (migratedDatabase.delete(migratedDatabase.dwOfflineAssets)..where(
                  (row) =>
                      row.userScopeId.equals('scope-a') &
                      row.assetId.equals('asset') &
                      row.assetRevision.equals('r1'),
                ))
                .go(),
            throwsA(isA<Exception>()),
          );
          expect(
            await migratedDatabase
                .select(migratedDatabase.dwOfflineManifests)
                .get(),
            isEmpty,
          );
          await migratedDatabase.close();
        } finally {
          await temporaryDirectory.delete(recursive: true);
        }
      },
    );
  });
}

class FrozenVersionTwoFixture extends QueryExecutorUser {
  @override
  int get schemaVersion => 2;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails openingDetails,
  ) => Future<void>.value();

  static final List<String> versionTwoDdl = [
    ...FrozenVersionOneFixture.versionOneDdl,
    '''
      CREATE TABLE dw_offline_reader_pins (
        user_scope_id TEXT NOT NULL CHECK (length(trim(user_scope_id)) > 0),
        reader_id TEXT NOT NULL,
        asset_id TEXT NOT NULL,
        asset_revision TEXT NOT NULL,
        pinned_at_epoch_ms INTEGER NOT NULL,
        PRIMARY KEY (user_scope_id, reader_id, asset_id, asset_revision),
        FOREIGN KEY (user_scope_id, asset_id, asset_revision)
          REFERENCES dw_offline_assets (user_scope_id, asset_id, asset_revision)
          ON DELETE CASCADE
      )
    ''',
  ];

  static final List<String> versionTwoSeedSql = [
    ...FrozenVersionOneFixture.versionOneSeedSql,
    '''
      INSERT INTO dw_offline_reader_pins VALUES (
        'scope-a', 'reader', 'asset', 'r1', 1700000000000
      )
    ''',
  ];
}

class FrozenVersionOneFixture extends QueryExecutorUser {
  FrozenVersionOneFixture();

  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails openingDetails,
  ) => Future<void>.value();

  static const List<String> versionOneDdl = [
    '''
      CREATE TABLE dw_offline_packages (
        user_scope_id TEXT NOT NULL CHECK (length(trim(user_scope_id)) > 0),
        package_id TEXT NOT NULL,
        content_identity TEXT NOT NULL,
        active_manifest_revision TEXT,
        staging_manifest_revision TEXT,
        aggregate_status TEXT NOT NULL,
        completed_asset_count INTEGER NOT NULL CHECK (completed_asset_count >= 0),
        total_asset_count INTEGER NOT NULL CHECK (total_asset_count >= completed_asset_count),
        created_at_epoch_ms INTEGER NOT NULL,
        updated_at_epoch_ms INTEGER NOT NULL,
        PRIMARY KEY (user_scope_id, package_id)
      )
    ''',
    '''
      CREATE TABLE dw_offline_assets (
        user_scope_id TEXT NOT NULL CHECK (length(trim(user_scope_id)) > 0),
        asset_id TEXT NOT NULL,
        asset_revision TEXT NOT NULL,
        expected_size_bytes INTEGER NOT NULL CHECK (expected_size_bytes >= 0),
        checksum TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        relative_path TEXT NOT NULL,
        asset_state TEXT NOT NULL,
        ref_count INTEGER NOT NULL DEFAULT 0 CHECK (ref_count >= 0),
        is_tombstoned INTEGER NOT NULL DEFAULT 0 CHECK (is_tombstoned IN (0, 1)),
        created_at_epoch_ms INTEGER NOT NULL,
        updated_at_epoch_ms INTEGER NOT NULL,
        PRIMARY KEY (user_scope_id, asset_id, asset_revision)
      )
    ''',
    '''
      CREATE TABLE dw_offline_package_assets (
        user_scope_id TEXT NOT NULL CHECK (length(trim(user_scope_id)) > 0),
        package_id TEXT NOT NULL,
        asset_id TEXT NOT NULL,
        asset_revision TEXT NOT NULL,
        is_required INTEGER NOT NULL CHECK (is_required IN (0, 1)),
        created_at_epoch_ms INTEGER NOT NULL,
        PRIMARY KEY (user_scope_id, package_id, asset_id, asset_revision),
        FOREIGN KEY (user_scope_id, package_id)
          REFERENCES dw_offline_packages (user_scope_id, package_id)
          ON DELETE CASCADE,
        FOREIGN KEY (user_scope_id, asset_id, asset_revision)
          REFERENCES dw_offline_assets (user_scope_id, asset_id, asset_revision)
          ON DELETE CASCADE
      )
    ''',
    '''
      CREATE TABLE dw_offline_jobs (
        user_scope_id TEXT NOT NULL CHECK (length(trim(user_scope_id)) > 0),
        job_id TEXT NOT NULL,
        package_id TEXT,
        job_type TEXT NOT NULL,
        job_state TEXT NOT NULL,
        attempt_count INTEGER NOT NULL CHECK (attempt_count >= 0),
        payload_json TEXT NOT NULL,
        last_error_json TEXT,
        created_at_epoch_ms INTEGER NOT NULL,
        updated_at_epoch_ms INTEGER NOT NULL,
        PRIMARY KEY (user_scope_id, job_id),
        FOREIGN KEY (user_scope_id, package_id)
          REFERENCES dw_offline_packages (user_scope_id, package_id)
          ON DELETE CASCADE
      )
    ''',
    '''
      CREATE TABLE dw_offline_snapshots (
        user_scope_id TEXT NOT NULL CHECK (length(trim(user_scope_id)) > 0),
        query_key TEXT NOT NULL,
        envelope_json TEXT NOT NULL,
        captured_at_epoch_ms INTEGER NOT NULL,
        expires_at_epoch_ms INTEGER,
        PRIMARY KEY (user_scope_id, query_key)
      )
    ''',
    '''
      CREATE TABLE dw_offline_outbox (
        user_scope_id TEXT NOT NULL CHECK (length(trim(user_scope_id)) > 0),
        mutation_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        mutation_type TEXT NOT NULL,
        idempotency_key TEXT NOT NULL,
        envelope_json TEXT NOT NULL,
        created_at_epoch_ms INTEGER NOT NULL,
        updated_at_epoch_ms INTEGER NOT NULL,
        PRIMARY KEY (user_scope_id, mutation_id),
        UNIQUE (user_scope_id, entity_type, entity_id)
      )
    ''',
    '''
      CREATE TABLE dw_offline_leases (
        user_scope_id TEXT NOT NULL CHECK (length(trim(user_scope_id)) > 0),
        lease_id TEXT NOT NULL,
        lease_envelope_json TEXT NOT NULL,
        trusted_at_epoch_ms INTEGER NOT NULL,
        expires_at_epoch_ms INTEGER NOT NULL,
        PRIMARY KEY (user_scope_id, lease_id)
      )
    ''',
  ];

  static const List<String> versionOneSeedSql = [
    '''
      INSERT INTO dw_offline_packages VALUES (
        'scope-a', 'pkg', 'content-pkg', 'manifest-1', NULL, 'ready',
        1, 1, 1700000000000, 1700000000000
      )
    ''',
    '''
      INSERT INTO dw_offline_assets VALUES (
        'scope-a', 'asset', 'r1', 128, 'sha256-asset-r1',
        'application/octet-stream', 'asset/r1', 'ready', 1, 0,
        1700000000000, 1700000000000
      )
    ''',
    '''
      INSERT INTO dw_offline_package_assets VALUES (
        'scope-a', 'pkg', 'asset', 'r1', 1, 1700000000000
      )
    ''',
    '''
      INSERT INTO dw_offline_jobs VALUES (
        'scope-a', 'job', 'pkg', 'download', 'queued', 0, '{}', NULL,
        1700000000000, 1700000000000
      )
    ''',
    '''
      INSERT INTO dw_offline_snapshots VALUES (
        'scope-a', 'query', '{}', 1700000000000, NULL
      )
    ''',
    '''
      INSERT INTO dw_offline_outbox VALUES (
        'scope-a', 'mutation', 'record', 'entity', 'save',
        'idem-mutation', '{}', 1700000000000, 1700000000000
      )
    ''',
    '''
      INSERT INTO dw_offline_leases VALUES (
        'scope-a', 'lease', '{}', 1700000000000, 1700000060000
      )
    ''',
  ];
}

class StorageFixtures {
  static const int timestampEpochMs = 1700000000000;

  static Future<int> insertPackage(
    DwOfflineDatabase offlineDatabase,
    String userScopeId,
    String packageId, {
    String? activeRevision,
    String? stagingRevision,
  }) {
    return offlineDatabase
        .into(offlineDatabase.dwOfflinePackages)
        .insert(
          DwOfflinePackagesCompanion.insert(
            userScopeId: userScopeId,
            packageId: packageId,
            contentIdentity: 'content-$packageId',
            activeManifestRevision: Value(activeRevision),
            stagingManifestRevision: Value(stagingRevision),
            aggregateStatus: 'queued',
            completedAssetCount: 0,
            totalAssetCount: 1,
            createdAtEpochMs: timestampEpochMs,
            updatedAtEpochMs: timestampEpochMs,
          ),
        );
  }

  static Future<int> insertAsset(
    DwOfflineDatabase offlineDatabase,
    String userScopeId,
    String assetId,
    String assetRevision, {
    int refCount = 0,
  }) {
    return offlineDatabase
        .into(offlineDatabase.dwOfflineAssets)
        .insert(
          DwOfflineAssetsCompanion.insert(
            userScopeId: userScopeId,
            assetId: assetId,
            assetRevision: assetRevision,
            expectedSizeBytes: 128,
            checksum: 'sha256-$assetId-$assetRevision',
            mimeType: 'application/octet-stream',
            relativePath: '$assetId/$assetRevision',
            assetState: 'ready',
            refCount: Value(refCount),
            createdAtEpochMs: timestampEpochMs,
            updatedAtEpochMs: timestampEpochMs,
          ),
        );
  }

  static Future<int> assetRefCount(
    DwOfflineDatabase offlineDatabase,
    String userScopeId,
    String assetId,
    String assetRevision,
  ) async {
    final assetRow =
        await (offlineDatabase.select(offlineDatabase.dwOfflineAssets)..where(
              (row) =>
                  row.userScopeId.equals(userScopeId) &
                  row.assetId.equals(assetId) &
                  row.assetRevision.equals(assetRevision),
            ))
            .getSingle();
    return assetRow.refCount;
  }

  static DwOfflinePackageAssetsCompanion packageAsset(
    String userScopeId,
    String packageId,
    String assetId,
    String assetRevision,
  ) {
    return DwOfflinePackageAssetsCompanion.insert(
      userScopeId: userScopeId,
      packageId: packageId,
      assetId: assetId,
      assetRevision: assetRevision,
      isRequired: true,
      createdAtEpochMs: timestampEpochMs,
    );
  }

  static DwOfflineJobsCompanion job(
    String userScopeId,
    String jobId, {
    String? packageId,
    String? manifestRevision,
    String? manifestDigest,
    int priority = 0,
    int? packageTotalBytes,
    String? consentedManifestDigest,
    int? nextEligibleAtEpochMs,
    String? pauseReason,
  }) {
    return DwOfflineJobsCompanion.insert(
      userScopeId: userScopeId,
      jobId: jobId,
      packageId: Value(packageId),
      jobType: 'download',
      jobState: 'queued',
      attemptCount: 0,
      payloadJson: '{}',
      manifestRevision: Value(manifestRevision),
      manifestDigest: Value(manifestDigest),
      priority: Value(priority),
      packageTotalBytes: Value(packageTotalBytes),
      consentedManifestDigest: Value(consentedManifestDigest),
      nextEligibleAtEpochMs: Value(nextEligibleAtEpochMs),
      pauseReason: Value(pauseReason),
      createdAtEpochMs: timestampEpochMs,
      updatedAtEpochMs: timestampEpochMs,
    );
  }

  static DwOfflineDownloadTasksCompanion downloadTask(
    String userScopeId,
    String jobId,
    String assetId,
    String assetRevision, {
    String? nativeTaskId,
    String? temporaryFilePath,
    int transferredBytes = 0,
    int attemptCount = 0,
    int? nextEligibleAtEpochMs,
  }) {
    return DwOfflineDownloadTasksCompanion.insert(
      userScopeId: userScopeId,
      jobId: jobId,
      assetId: assetId,
      assetRevision: assetRevision,
      taskState: 'queued',
      nativeTaskId: Value(nativeTaskId),
      temporaryFilePath: Value(temporaryFilePath),
      transferredBytes: Value(transferredBytes),
      attemptCount: attemptCount,
      nextEligibleAtEpochMs: Value(nextEligibleAtEpochMs),
      createdAtEpochMs: timestampEpochMs,
      updatedAtEpochMs: timestampEpochMs,
    );
  }

  static DwOfflineSnapshotsCompanion snapshot(
    String userScopeId,
    String queryKey,
  ) {
    return DwOfflineSnapshotsCompanion.insert(
      userScopeId: userScopeId,
      queryKey: queryKey,
      envelopeJson: '{}',
      capturedAtEpochMs: timestampEpochMs,
    );
  }

  static DwOfflineOutboxCompanion outbox(
    String userScopeId,
    String mutationId,
    String entityId, {
    String entityType = 'record',
    String mutationType = 'save',
    String envelope = '{}',
    int createdAtEpochMs = timestampEpochMs,
    int updatedAtEpochMs = timestampEpochMs,
  }) {
    return DwOfflineOutboxCompanion.insert(
      userScopeId: userScopeId,
      mutationId: mutationId,
      entityType: entityType,
      entityId: entityId,
      mutationType: mutationType,
      idempotencyKey: 'idem-$mutationId',
      envelopeJson: envelope,
      createdAtEpochMs: createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs,
    );
  }

  static DwOfflineLeasesCompanion lease(String userScopeId, String leaseId) {
    return DwOfflineLeasesCompanion.insert(
      userScopeId: userScopeId,
      leaseId: leaseId,
      leaseEnvelopeJson: '{}',
      trustedAtEpochMs: timestampEpochMs,
      expiresAtEpochMs: timestampEpochMs + 60000,
    );
  }

  static DwOfflineReaderPinsCompanion readerPin(
    String userScopeId,
    String readerId,
    String assetId,
    String assetRevision,
  ) {
    return DwOfflineReaderPinsCompanion.insert(
      userScopeId: userScopeId,
      readerId: readerId,
      assetId: assetId,
      assetRevision: assetRevision,
      pinnedAtEpochMs: timestampEpochMs,
    );
  }
}
