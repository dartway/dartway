import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:dartway_offline/src/download/dw_download_job_store.dart';
import 'package:dartway_offline/src/download/dw_download_plan.dart';
import 'package:dartway_offline/src/download/dw_download_state.dart';
import 'package:dartway_offline/src/storage/dw_offline_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DwDownloadJobStore', () {
    late DwOfflineDatabase database;
    late DwDownloadJobStore store;

    setUp(() {
      database = DwOfflineDatabase(NativeDatabase.memory());
      store = DwDownloadJobStore(database);
    });

    tearDown(() => database.close());

    test('creates one durable task only for each non-ready asset', () async {
      await insertStagingPackage(database);
      await insertAsset(database, assetId: 'missing');
      await insertAsset(database, assetId: 'ready', ready: true);

      final jobId = await store.createJob(
        packagePlan(assets: [assetPlan('missing'), assetPlan('ready')]),
      );

      final jobs = await database.select(database.dwOfflineJobs).get();
      final tasks = await database
          .select(database.dwOfflineDownloadTasks)
          .get();
      expect(jobs, hasLength(1));
      expect(jobs.single.jobId, jobId);
      expect(jobs.single.manifestRevision, 'manifest-r1');
      expect(jobs.single.manifestDigest, 'manifest-digest');
      expect(jobs.single.packageTotalBytes, 10);
      expect(jobs.single.priority, 4);
      expect(tasks.map((task) => task.assetId), ['missing']);
    });

    test('repeating the same enqueue is idempotent', () async {
      await insertStagingPackage(database);
      await insertAsset(database, assetId: 'asset');
      final plan = packagePlan(assets: [assetPlan('asset')]);

      final firstJobId = await store.createJob(plan, nowEpochMs: 10);
      final secondJobId = await store.createJob(plan, nowEpochMs: 20);

      expect(secondJobId, firstJobId);
      expect(await database.select(database.dwOfflineJobs).get(), hasLength(1));
      expect(
        await database.select(database.dwOfflineDownloadTasks).get(),
        hasLength(1),
      );
      expect(
        (await database.select(database.dwOfflineJobs).getSingle())
            .createdAtEpochMs,
        10,
      );
    });

    test('rejects a plan that is not bound to persisted staging', () async {
      await insertStagingPackage(database);
      await insertAsset(database, assetId: 'asset');

      await expectLater(
        store.createJob(
          packagePlan(
            manifestDigest: 'other-digest',
            assets: [assetPlan('asset')],
          ),
        ),
        throwsStateError,
      );
      expect(await database.select(database.dwOfflineJobs).get(), isEmpty);
    });

    test('consent can only be granted for the job manifest digest', () async {
      await insertStagingPackage(database);
      await insertAsset(database, assetId: 'asset');
      final jobId = await store.createJob(
        packagePlan(assets: [assetPlan('asset')]),
      );

      await expectLater(
        store.grantConsent(
          userScopeId: 'scope-a',
          jobId: jobId,
          manifestDigest: 'stale-digest',
        ),
        throwsStateError,
      );
      await store.grantConsent(
        userScopeId: 'scope-a',
        jobId: jobId,
        manifestDigest: 'manifest-digest',
      );

      expect(
        (await database.select(database.dwOfflineJobs).getSingle())
            .consentedManifestDigest,
        'manifest-digest',
      );
    });

    test(
      'loads signed asset metadata and persists native transitions',
      () async {
        await insertStagingPackage(database);
        await insertAsset(database, assetId: 'asset');
        await store.createJob(packagePlan(assets: [assetPlan('asset')]));

        var storedTask = (await store.loadTasks('scope-a')).single;
        expect(storedTask.assetDescriptor.downloadUrl, contains('asset.bin'));
        expect(storedTask.host, 'cdn.example.test');
        expect(storedTask.taskState, DwDownloadTaskState.queued);

        await store.markEnqueued(
          identity: storedTask.identity,
          nativeTaskId: 'native-task',
        );
        await store.markTaskStateByNativeId(
          nativeTaskId: 'native-task',
          taskState: DwDownloadTaskState.running,
          transferredBytes: 3,
        );
        storedTask = (await store.loadTasks('scope-a')).single;
        expect(storedTask.taskState, DwDownloadTaskState.running);
        expect(storedTask.nativeTaskId, 'native-task');
        expect(storedTask.transferredBytes, 3);

        await store.scheduleRetryByNativeId(
          nativeTaskId: 'native-task',
          nextEligibleAtEpochMs: 100,
          errorJson: '{"kind":"connection"}',
        );
        storedTask = (await store.loadTasks('scope-a')).single;
        expect(storedTask.taskState, DwDownloadTaskState.waitingRetry);
        expect(storedTask.nativeTaskId, isNull);
        expect(storedTask.attemptCount, 1);
        expect(storedTask.nextEligibleAtEpochMs, 100);
        expect(storedTask.lastErrorJson, '{"kind":"connection"}');
      },
    );

    test('watches package progress from durable job and task state', () async {
      await insertStagingPackage(database);
      await insertAsset(database, assetId: 'asset-a');
      await insertAsset(database, assetId: 'asset-b');
      await store.createJob(
        packagePlan(assets: [assetPlan('asset-a'), assetPlan('asset-b')]),
      );

      final initial =
          (await store.watchPackageDownloads('scope-a').first).single;
      expect(initial.packageId, 'package-a');
      expect(initial.manifestDigest, 'manifest-digest');
      expect(initial.state, DwDownloadJobState.queued);
      expect(initial.fileCount, 2);
      expect(initial.completedFileCount, 0);
      expect(initial.bytesToDownload, 10);
      expect(initial.bytesDownloaded, 0);
      expect(initial.progress, 0);

      final task = (await store.loadTasks('scope-a')).first;
      final updatedStatus = store
          .watchPackageDownloads('scope-a')
          .expand((statuses) => statuses)
          .firstWhere((status) => status.bytesDownloaded == 3);
      await store.markEnqueued(
        identity: task.identity,
        nativeTaskId: 'native-progress',
      );
      await store.markTaskStateByNativeId(
        nativeTaskId: 'native-progress',
        taskState: DwDownloadTaskState.running,
        transferredBytes: 3,
      );

      expect((await updatedStatus).progress, 0.3);
    });
  });
}

DwDownloadPackagePlan packagePlan({
  required List<DwDownloadAssetPlan> assets,
  String manifestDigest = 'manifest-digest',
}) {
  return DwDownloadPackagePlan(
    userScopeId: 'scope-a',
    packageId: 'package-a',
    manifestRevision: 'manifest-r1',
    manifestDigest: manifestDigest,
    priority: 4,
    assets: assets,
  );
}

DwDownloadAssetPlan assetPlan(String assetId) {
  return DwDownloadAssetPlan(
    assetId: assetId,
    assetRevision: 'r1',
    expectedSizeBytes: 5,
  );
}

Future<void> insertStagingPackage(DwOfflineDatabase database) async {
  await database
      .into(database.dwOfflinePackages)
      .insert(
        DwOfflinePackagesCompanion.insert(
          userScopeId: 'scope-a',
          packageId: 'package-a',
          contentIdentity: 'content-a',
          stagingManifestRevision: const Value('manifest-r1'),
          stagingManifestDigest: const Value('manifest-digest'),
          aggregateStatus: 'staging',
          completedAssetCount: 0,
          totalAssetCount: 2,
          createdAtEpochMs: 1,
          updatedAtEpochMs: 1,
        ),
      );
  await database
      .into(database.dwOfflineManifests)
      .insert(
        DwOfflineManifestsCompanion.insert(
          userScopeId: 'scope-a',
          packageId: 'package-a',
          manifestRevision: 'manifest-r1',
          payloadDigest: 'manifest-digest',
          envelopeJson: '{}',
          payloadBytes: Uint8List(0),
          createdAtEpochMs: 1,
        ),
      );
}

Future<void> insertAsset(
  DwOfflineDatabase database, {
  required String assetId,
  bool ready = false,
}) async {
  await database
      .into(database.dwOfflineAssets)
      .insert(
        DwOfflineAssetsCompanion.insert(
          userScopeId: 'scope-a',
          assetId: assetId,
          assetRevision: 'r1',
          expectedSizeBytes: 5,
          checksum: 'checksum-$assetId',
          mimeType: 'application/octet-stream',
          relativePath: '$assetId.bin',
          downloadUrl: Value('https://cdn.example.test/$assetId.bin'),
          allowedRedirectHostsJson: const Value('["cdn.example.test"]'),
          blobName: Value(ready ? '$assetId.blob' : null),
          assetState: ready ? 'ready' : 'missing',
          createdAtEpochMs: 1,
          updatedAtEpochMs: 1,
        ),
      );
  await database
      .into(database.dwOfflineStagingAssets)
      .insert(
        DwOfflineStagingAssetsCompanion.insert(
          userScopeId: 'scope-a',
          packageId: 'package-a',
          manifestRevision: 'manifest-r1',
          assetId: assetId,
          assetRevision: 'r1',
          isRequired: true,
          createdAtEpochMs: 1,
        ),
      );
}
