import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:dartway_offline_flutter/src/access/dw_offline_lease_policy.dart';
import 'package:dartway_offline_flutter/src/download/dw_download_asset_publisher.dart';
import 'package:dartway_offline_flutter/src/download/dw_background_download_transport.dart';
import 'package:dartway_offline_flutter/src/download/dw_download_job_store.dart';
import 'package:dartway_offline_flutter/src/download/dw_download_plan.dart';
import 'package:dartway_offline_flutter/src/download/dw_download_scheduler.dart';
import 'package:dartway_offline_flutter/src/download/dw_download_state.dart';
import 'package:dartway_offline_flutter/src/network/dw_network_class.dart';
import 'package:dartway_offline_flutter/src/storage/disk_space_plus_source.dart';
import 'package:dartway_offline_flutter/src/storage/dw_offline_asset_store.dart';
import 'package:dartway_offline_flutter/src/storage/dw_offline_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DwDownloadScheduler', () {
    late DwOfflineDatabase database;
    late DwDownloadJobStore jobStore;
    late FakeBackgroundTransport transport;
    late FakeNetworkSource networkSource;
    late FakeDiskSpaceSource diskSpaceSource;
    late FakeAssetPublisher assetPublisher;
    late FakeWakeupScheduler wakeupScheduler;
    late DwDownloadScheduler scheduler;
    late int nowEpochMs;

    setUp(() {
      database = DwOfflineDatabase(NativeDatabase.memory());
      jobStore = DwDownloadJobStore(database);
      transport = FakeBackgroundTransport();
      networkSource = FakeNetworkSource(DwNetworkClass.unmetered);
      diskSpaceSource = FakeDiskSpaceSource(
        freeBytes: BigInt.from(1000000),
        totalBytes: BigInt.from(1000000),
      );
      assetPublisher = FakeAssetPublisher();
      wakeupScheduler = FakeWakeupScheduler();
      nowEpochMs = 1000;
      scheduler = DwDownloadScheduler(
        jobStore: jobStore,
        transport: transport,
        networkSource: networkSource,
        diskSpaceSource: diskSpaceSource,
        assetPublisher: assetPublisher,
        nowEpochMs: () => nowEpochMs,
        scheduleWakeup: wakeupScheduler.schedule,
      );
    });

    tearDown(() async {
      await networkSource.dispose();
      await transport.dispose();
      await database.close();
    });

    test('unmetered network starts two files from one package', () async {
      await seedPlan(database, assetIds: const ['asset-a', 'asset-b']);
      await jobStore.createJob(
        downloadPlan(assetIds: const ['asset-a', 'asset-b']),
        nowEpochMs: 1,
      );

      await scheduler.runOnce('scope-a');

      expect(transport.enqueuedRequests, hasLength(2));
      expect(
        (await jobStore.loadTasks('scope-a')).map((task) => task.taskState),
        everyElement(DwDownloadTaskState.enqueued),
      );
    });

    test('package without assets activates immediately', () async {
      await seedPlan(database, assetIds: const []);
      await jobStore.createJob(downloadPlan(assetIds: const []));

      await scheduler.runOnce('scope-a');

      expect(assetPublisher.activatedPackages, ['package-a']);
      expect(
        (await database.select(database.dwOfflineJobs).getSingle()).jobState,
        DwDownloadJobState.completed.name,
      );
    });

    test(
      'restart finishes a package whose files were already persisted',
      () async {
        await seedPlan(database, assetIds: const ['asset-a']);
        await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
        final task = (await jobStore.loadTasks('scope-a')).single;
        await jobStore.markTaskState(
          identity: task.identity,
          taskState: DwDownloadTaskState.completed,
        );
        await jobStore.markJobState(
          userScopeId: 'scope-a',
          jobId: task.identity.jobId,
          jobState: DwDownloadJobState.running,
        );

        await scheduler.runOnce('scope-a');

        expect(assetPublisher.activatedPackages, ['package-a']);
        expect(
          (await database.select(database.dwOfflineJobs).getSingle()).jobState,
          DwDownloadJobState.completed.name,
        );
        expect(transport.enqueuedRequests, isEmpty);
      },
    );

    test('metered large package waits for manifest-bound consent', () async {
      networkSource.current = DwNetworkClass.metered;
      await seedPlan(
        database,
        assetIds: const ['asset-a'],
        expectedSizeBytes: 101000000,
      );
      await jobStore.createJob(
        downloadPlan(assetIds: const ['asset-a'], expectedSizeBytes: 101000000),
      );

      await scheduler.runOnce('scope-a');

      expect(transport.enqueuedRequests, isEmpty);
      expect(
        (await database.select(database.dwOfflineJobs).getSingle()).jobState,
        DwDownloadJobState.waitingConsent.name,
      );
    });

    test(
      'offline and insufficient disk persist their waiting reasons',
      () async {
        await seedPlan(database, assetIds: const ['asset-a']);
        await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));

        networkSource.current = DwNetworkClass.offline;
        await scheduler.runOnce('scope-a');
        expect(
          (await jobStore.loadTasks('scope-a')).single.taskState,
          DwDownloadTaskState.waitingNetwork,
        );

        networkSource.current = DwNetworkClass.unmetered;
        diskSpaceSource.freeBytes = BigInt.from(5);
        diskSpaceSource.totalBytes = BigInt.from(100);
        await scheduler.runOnce('scope-a');
        expect(
          (await jobStore.loadTasks('scope-a')).single.taskState,
          DwDownloadTaskState.waitingDisk,
        );
        expect(transport.enqueuedRequests, isEmpty);
      },
    );

    test(
      'completed native file is published and activates the package',
      () async {
        await seedPlan(database, assetIds: const ['asset-a']);
        await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
        await scheduler.activateUserScope('scope-a');
        final nativeTaskId = transport.enqueuedRequests.single.taskId;

        await scheduler.handleTransportUpdate(
          DwBackgroundDownloadUpdate(
            taskId: nativeTaskId,
            status: DwNativeDownloadStatus.complete,
            completedFilePath: 'temporary/asset-a.download',
          ),
        );

        expect(assetPublisher.publishedPaths, ['temporary/asset-a.download']);
        expect(assetPublisher.activatedPackages, ['package-a']);
        expect(
          (await jobStore.loadTasks('scope-a')).single.taskState,
          DwDownloadTaskState.completed,
        );
        expect(
          (await database.select(database.dwOfflineJobs).getSingle()).jobState,
          DwDownloadJobState.completed.name,
        );
      },
    );

    test('integrity failure discards the completed native temp file', () async {
      await seedPlan(database, assetIds: const ['asset-a']);
      await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
      assetPublisher.publishIntegrityFailure = true;
      await scheduler.activateUserScope('scope-a');
      final nativeTaskId = transport.enqueuedRequests.single.taskId;

      await scheduler.handleTransportUpdate(
        DwBackgroundDownloadUpdate(
          taskId: nativeTaskId,
          status: DwNativeDownloadStatus.complete,
          completedFilePath: 'temporary/corrupt.download',
        ),
      );

      expect(assetPublisher.discardedPaths, ['temporary/corrupt.download']);
      expect(
        (await jobStore.loadTasks('scope-a')).single.taskState,
        DwDownloadTaskState.failed,
      );
    });

    test(
      'completed file waits for disk and publishes later without redownload',
      () async {
        await seedPlan(database, assetIds: const ['asset-a']);
        await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
        await scheduler.activateUserScope('scope-a');
        final nativeTaskId = transport.enqueuedRequests.single.taskId;

        diskSpaceSource.freeBytes = BigInt.from(5);
        diskSpaceSource.totalBytes = BigInt.from(100);
        await scheduler.handleTransportUpdate(
          DwBackgroundDownloadUpdate(
            taskId: nativeTaskId,
            status: DwNativeDownloadStatus.complete,
            completedFilePath: 'temporary/asset-a.download',
          ),
        );

        var task = (await jobStore.loadTasks('scope-a')).single;
        expect(task.taskState, DwDownloadTaskState.waitingDisk);
        expect(task.temporaryFilePath, 'temporary/asset-a.download');
        expect(assetPublisher.publishedPaths, isEmpty);

        networkSource.current = DwNetworkClass.offline;
        diskSpaceSource.freeBytes = BigInt.from(100);
        await scheduler.runOnce('scope-a');

        task = (await jobStore.loadTasks('scope-a')).single;
        expect(task.taskState, DwDownloadTaskState.completed);
        expect(assetPublisher.publishedPaths, ['temporary/asset-a.download']);
        expect(assetPublisher.activatedPackages, ['package-a']);
        expect(transport.enqueuedRequests, hasLength(1));
        expect(transport.resumedTaskIds, isEmpty);
      },
    );

    test(
      'connection failure uses scheduler retry and 403 is terminal',
      () async {
        await seedPlan(database, assetIds: const ['asset-a']);
        await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
        await scheduler.activateUserScope('scope-a');
        var nativeTaskId = transport.enqueuedRequests.single.taskId;

        await scheduler.handleTransportUpdate(
          DwBackgroundDownloadUpdate(
            taskId: nativeTaskId,
            status: DwNativeDownloadStatus.failed,
            failureKind: DwNativeDownloadFailureKind.connection,
            errorDescription: 'offline',
          ),
        );
        var task = (await jobStore.loadTasks('scope-a')).single;
        expect(task.taskState, DwDownloadTaskState.waitingRetry);
        expect(task.attemptCount, 1);
        expect(task.nextEligibleAtEpochMs, 6000);

        nowEpochMs = 6000;
        await scheduler.runOnce('scope-a');
        nativeTaskId = transport.enqueuedRequests.last.taskId;
        await scheduler.handleTransportUpdate(
          DwBackgroundDownloadUpdate(
            taskId: nativeTaskId,
            status: DwNativeDownloadStatus.failed,
            failureKind: DwNativeDownloadFailureKind.forbidden,
            responseStatusCode: 403,
            errorDescription: 'forbidden',
          ),
        );
        task = (await jobStore.loadTasks('scope-a')).single;
        expect(task.taskState, DwDownloadTaskState.failed);
        expect(
          (await database.select(database.dwOfflineJobs).getSingle()).jobState,
          DwDownloadJobState.failed.name,
        );
      },
    );

    test(
      'final enqueue failure becomes terminal instead of phantom work',
      () async {
        await seedPlan(database, assetIds: const ['asset-a']);
        await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
        await database
            .update(database.dwOfflineDownloadTasks)
            .write(
              const DwOfflineDownloadTasksCompanion(attemptCount: Value(6)),
            );
        transport.enqueueError = StateError('native enqueue rejected');

        await scheduler.runOnce('scope-a');

        final task = (await jobStore.loadTasks('scope-a')).single;
        expect(task.taskState, DwDownloadTaskState.failed);
        expect(task.nativeTaskId, null);
        expect(
          (await database.select(database.dwOfflineJobs).getSingle()).jobState,
          DwDownloadJobState.failed.name,
        );
      },
    );

    test('optional asset failure does not fail the package', () async {
      const assetIds = ['required-video', 'optional-material'];
      const optionalAssetIds = {'optional-material'};
      await seedPlan(
        database,
        assetIds: assetIds,
        optionalAssetIds: optionalAssetIds,
      );
      await jobStore.createJob(
        downloadPlan(assetIds: assetIds, optionalAssetIds: optionalAssetIds),
      );
      await scheduler.activateUserScope('scope-a');
      final tasks = await jobStore.loadTasks('scope-a');
      final requiredTask = tasks.singleWhere(
        (task) => task.identity.assetId == 'required-video',
      );
      final optionalTask = tasks.singleWhere(
        (task) => task.identity.assetId == 'optional-material',
      );

      await scheduler.handleTransportUpdate(
        DwBackgroundDownloadUpdate(
          taskId: requiredTask.nativeTaskId!,
          status: DwNativeDownloadStatus.complete,
          completedFilePath: 'temporary/required-video.download',
        ),
      );
      await scheduler.handleTransportUpdate(
        DwBackgroundDownloadUpdate(
          taskId: optionalTask.nativeTaskId!,
          status: DwNativeDownloadStatus.failed,
          failureKind: DwNativeDownloadFailureKind.notFound,
          responseStatusCode: 404,
        ),
      );

      expect(assetPublisher.activatedPackages, ['package-a']);
      expect(
        (await database.select(database.dwOfflineJobs).getSingle()).jobState,
        DwDownloadJobState.completed.name,
      );
    });

    test('manual retry enqueues only failed assets', () async {
      const assetIds = ['completed-video', 'failed-material'];
      await seedPlan(database, assetIds: assetIds);
      final jobId = await jobStore.createJob(downloadPlan(assetIds: assetIds));
      await scheduler.activateUserScope('scope-a');
      final tasks = await jobStore.loadTasks('scope-a');
      final completedTask = tasks.singleWhere(
        (task) => task.identity.assetId == 'completed-video',
      );
      final failedTask = tasks.singleWhere(
        (task) => task.identity.assetId == 'failed-material',
      );

      await scheduler.handleTransportUpdate(
        DwBackgroundDownloadUpdate(
          taskId: completedTask.nativeTaskId!,
          status: DwNativeDownloadStatus.complete,
          completedFilePath: 'temporary/completed-video.download',
        ),
      );
      await scheduler.handleTransportUpdate(
        DwBackgroundDownloadUpdate(
          taskId: failedTask.nativeTaskId!,
          status: DwNativeDownloadStatus.failed,
          failureKind: DwNativeDownloadFailureKind.forbidden,
          responseStatusCode: 403,
        ),
      );

      await scheduler.retryFailedAssets(userScopeId: 'scope-a', jobId: jobId);

      expect(transport.enqueuedRequests, hasLength(3));
      expect(
        transport.enqueuedRequests.last.url,
        'https://cdn.example.test/failed-material.bin',
      );
      final retriedTasks = await jobStore.loadTasks('scope-a');
      expect(
        retriedTasks
            .singleWhere((task) => task.identity.assetId == 'completed-video')
            .taskState,
        DwDownloadTaskState.completed,
      );
    });

    test(
      'granting consent starts the previously blocked metered job',
      () async {
        networkSource.current = DwNetworkClass.metered;
        diskSpaceSource.freeBytes = BigInt.from(1000000000);
        diskSpaceSource.totalBytes = BigInt.from(1000000000);
        await seedPlan(
          database,
          assetIds: const ['asset-a'],
          expectedSizeBytes: 101000000,
        );
        final plan = downloadPlan(
          assetIds: const ['asset-a'],
          expectedSizeBytes: 101000000,
        );
        final jobId = await jobStore.createJob(plan);
        await scheduler.runOnce('scope-a');

        await scheduler.grantConsent(
          userScopeId: 'scope-a',
          jobId: jobId,
          manifestDigest: plan.manifestDigest,
        );

        expect(transport.enqueuedRequests, hasLength(1));
      },
    );

    test('pause and resume preserve a resumable native task', () async {
      await seedPlan(database, assetIds: const ['asset-a']);
      final jobId = await jobStore.createJob(
        downloadPlan(assetIds: const ['asset-a']),
      );
      await scheduler.activateUserScope('scope-a');
      final nativeTaskId = transport.enqueuedRequests.single.taskId;

      await scheduler.pauseJob(userScopeId: 'scope-a', jobId: jobId);
      expect(transport.pausedTaskIds, [nativeTaskId]);
      expect(
        (await jobStore.loadTasks('scope-a')).single.taskState,
        DwDownloadTaskState.paused,
      );

      await scheduler.resumeJob(userScopeId: 'scope-a', jobId: jobId);
      expect(transport.resumedTaskIds, [nativeTaskId]);
      expect(
        (await jobStore.loadTasks('scope-a')).single.taskState,
        DwDownloadTaskState.enqueued,
      );
    });

    test('scope switch preserves an explicit user pause', () async {
      await seedPlan(database, assetIds: const ['asset-a']);
      final jobId = await jobStore.createJob(
        downloadPlan(assetIds: const ['asset-a']),
      );
      await scheduler.activateUserScope('scope-a');
      final nativeTaskId = transport.enqueuedRequests.single.taskId;
      await scheduler.pauseJob(userScopeId: 'scope-a', jobId: jobId);

      await scheduler.deactivateUserScope('scope-a');
      await scheduler.activateUserScope('scope-a');

      final task = (await jobStore.loadTasks('scope-a')).single;
      expect(task.taskState, DwDownloadTaskState.paused);
      expect(task.nativeTaskId, null);
      expect(transport.cancelledTaskIds, contains(nativeTaskId));
      expect(transport.enqueuedRequests, hasLength(1));
      expect(
        (await database.select(database.dwOfflineJobs).getSingle()).jobState,
        DwDownloadJobState.paused.name,
      );
    });

    test(
      'scope activation reschedules a native task lost after restart',
      () async {
        await seedPlan(database, assetIds: const ['asset-a']);
        await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
        await scheduler.runOnce('scope-a');
        transport.enqueuedRequests.clear();
        transport.activeIds.clear();

        await scheduler.activateUserScope('scope-a');

        expect(transport.enqueuedRequests, hasLength(1));
      },
    );

    test('switching user scope cancels the previous account work', () async {
      await seedPlan(database, assetIds: const ['asset-a']);
      await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
      await scheduler.activateUserScope('scope-a');
      final previousNativeTaskId = transport.enqueuedRequests.single.taskId;

      await seedPlan(
        database,
        userScopeId: 'scope-b',
        packageId: 'package-b',
        assetIds: const ['asset-b'],
      );
      await jobStore.createJob(
        downloadPlan(
          userScopeId: 'scope-b',
          packageId: 'package-b',
          assetIds: const ['asset-b'],
        ),
      );
      await scheduler.activateUserScope('scope-b');

      final previousTask = (await jobStore.loadTasks('scope-a')).single;
      expect(transport.cancelledTaskIds, contains(previousNativeTaskId));
      expect(previousTask.nativeTaskId, null);
      expect(previousTask.taskState, DwDownloadTaskState.waitingNetwork);
      expect(
        (await jobStore.loadTasks('scope-b')).single.taskState,
        DwDownloadTaskState.enqueued,
      );

      await scheduler.handleTransportUpdate(
        DwBackgroundDownloadUpdate(
          taskId: previousNativeTaskId,
          status: DwNativeDownloadStatus.complete,
          completedFilePath: 'temporary/late-scope-a.download',
        ),
      );

      expect(assetPublisher.discardedPaths, [
        'temporary/late-scope-a.download',
      ]);
    });

    test('deactivating a scope cancels its native work', () async {
      await seedPlan(database, assetIds: const ['asset-a']);
      await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
      await scheduler.activateUserScope('scope-a');
      final nativeTaskId = transport.enqueuedRequests.single.taskId;

      await scheduler.deactivateUserScope('scope-a');

      final task = (await jobStore.loadTasks('scope-a')).single;
      expect(transport.cancelledTaskIds, [nativeTaskId]);
      expect(task.nativeTaskId, null);
      expect(task.taskState, DwDownloadTaskState.waitingNetwork);
    });

    test(
      'deactivating discards a completed transport temporary file',
      () async {
        await seedPlan(database, assetIds: const ['asset-a']);
        await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
        await scheduler.activateUserScope('scope-a');
        final nativeTaskId = transport.enqueuedRequests.single.taskId;
        diskSpaceSource.freeBytes = BigInt.from(1);
        diskSpaceSource.totalBytes = BigInt.from(100);
        await scheduler.handleTransportUpdate(
          DwBackgroundDownloadUpdate(
            taskId: nativeTaskId,
            status: DwNativeDownloadStatus.complete,
            completedFilePath: 'temporary/completed.download',
          ),
        );

        await scheduler.deactivateUserScope('scope-a');

        final task = (await jobStore.loadTasks('scope-a')).single;
        expect(assetPublisher.discardedPaths, ['temporary/completed.download']);
        expect(task.nativeTaskId, null);
        expect(task.temporaryFilePath, null);
        expect(task.taskState, DwDownloadTaskState.waitingNetwork);
      },
    );

    test(
      'enqueue exception becomes a durable retry instead of a phantom task',
      () async {
        await seedPlan(database, assetIds: const ['asset-a']);
        await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
        transport.enqueueError = StateError('platform enqueue failed');

        await scheduler.activateUserScope('scope-a');

        final task = (await jobStore.loadTasks('scope-a')).single;
        expect(task.nativeTaskId, null);
        expect(task.taskState, DwDownloadTaskState.waitingRetry);
        expect(task.lastErrorJson, contains('enqueue_exception'));
      },
    );

    test('disk probe failure after completion remains recoverable', () async {
      await seedPlan(database, assetIds: const ['asset-a']);
      await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
      await scheduler.activateUserScope('scope-a');
      final nativeTaskId = transport.enqueuedRequests.single.taskId;
      diskSpaceSource.error = StateError('disk plugin unavailable');

      await scheduler.handleTransportUpdate(
        DwBackgroundDownloadUpdate(
          taskId: nativeTaskId,
          status: DwNativeDownloadStatus.complete,
          completedFilePath: 'temporary/completed.download',
        ),
      );

      final task = (await jobStore.loadTasks('scope-a')).single;
      expect(task.taskState, DwDownloadTaskState.waitingDisk);
      expect(task.temporaryFilePath, 'temporary/completed.download');
    });

    test(
      'transport completion replayed during initialize is buffered for scope',
      () async {
        await seedPlan(database, assetIds: const ['asset-a']);
        await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
        final task = (await jobStore.loadTasks('scope-a')).single;
        await jobStore.markEnqueued(
          identity: task.identity,
          nativeTaskId: 'native-from-background',
        );
        transport.initializeUpdate = const DwBackgroundDownloadUpdate(
          taskId: 'native-from-background',
          status: DwNativeDownloadStatus.complete,
          completedFilePath: 'temporary/background.download',
        );

        await scheduler.initialize();
        await scheduler.activateUserScope('scope-a');

        expect(assetPublisher.publishedPaths, [
          'temporary/background.download',
        ]);
        expect(
          (await jobStore.loadTasks('scope-a')).single.taskState,
          DwDownloadTaskState.completed,
        );
      },
    );

    test('initialization is idempotent and owns transport lifecycle', () async {
      await scheduler.initialize();
      await scheduler.initialize();

      expect(transport.initializeCount, 1);
      await scheduler.dispose();
      expect(transport.disposeCount, 1);
    });

    test(
      'cancel stops native work and persists a terminal user state',
      () async {
        await seedPlan(database, assetIds: const ['asset-a']);
        final jobId = await jobStore.createJob(
          downloadPlan(assetIds: const ['asset-a']),
        );
        await scheduler.activateUserScope('scope-a');
        final nativeTaskId = transport.enqueuedRequests.single.taskId;

        await scheduler.cancelJob(userScopeId: 'scope-a', jobId: jobId);

        expect(transport.cancelledTaskIds, [nativeTaskId]);
        expect(
          (await jobStore.loadTasks('scope-a')).single.taskState,
          DwDownloadTaskState.cancelled,
        );
        expect(
          (await database.select(database.dwOfflineJobs).getSingle()).jobState,
          DwDownloadJobState.cancelled.name,
        );
      },
    );

    test(
      'concurrent wakeups cannot enqueue the same durable task twice',
      () async {
        await seedPlan(database, assetIds: const ['asset-a']);
        await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
        transport.enqueueGate = Completer<void>();

        final firstRun = scheduler.runOnce('scope-a');
        final secondRun = scheduler.runOnce('scope-a');
        await Future<void>.delayed(Duration.zero);
        transport.enqueueGate!.complete();
        await Future.wait([firstRun, secondRun]);

        expect(transport.enqueuedRequests, hasLength(1));
      },
    );

    test('retry persistence arms an exact automatic wakeup', () async {
      await scheduler.initialize();
      await seedPlan(database, assetIds: const ['asset-a']);
      await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
      await scheduler.activateUserScope('scope-a');
      final nativeTaskId = transport.enqueuedRequests.single.taskId;

      await scheduler.handleTransportUpdate(
        DwBackgroundDownloadUpdate(
          taskId: nativeTaskId,
          status: DwNativeDownloadStatus.failed,
          failureKind: DwNativeDownloadFailureKind.connection,
        ),
      );

      expect(wakeupScheduler.delays.last, const Duration(seconds: 5));
      await scheduler.dispose();
    });

    test('wifi to metered pauses a large package until consent', () async {
      diskSpaceSource.freeBytes = BigInt.from(1000000000);
      diskSpaceSource.totalBytes = BigInt.from(1000000000);
      await seedPlan(
        database,
        assetIds: const ['asset-a'],
        expectedSizeBytes: 101000000,
      );
      final plan = downloadPlan(
        assetIds: const ['asset-a'],
        expectedSizeBytes: 101000000,
      );
      final jobId = await jobStore.createJob(plan);
      await scheduler.activateUserScope('scope-a');
      final nativeTaskId = transport.enqueuedRequests.single.taskId;

      networkSource.current = DwNetworkClass.metered;
      await scheduler.runOnce('scope-a');
      expect(transport.pausedTaskIds, [nativeTaskId]);
      expect(
        (await database.select(database.dwOfflineJobs).getSingle()).jobState,
        DwDownloadJobState.waitingConsent.name,
      );

      await scheduler.grantConsent(
        userScopeId: 'scope-a',
        jobId: jobId,
        manifestDigest: plan.manifestDigest,
      );
      expect(transport.resumedTaskIds, [nativeTaskId]);
      expect(transport.enqueuedRequests, hasLength(1));
    });

    test('disk drop during progress pauses without consuming retry', () async {
      await seedPlan(database, assetIds: const ['asset-a']);
      await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
      await scheduler.activateUserScope('scope-a');
      final nativeTaskId = transport.enqueuedRequests.single.taskId;
      diskSpaceSource.freeBytes = BigInt.from(10);
      diskSpaceSource.totalBytes = BigInt.from(100);

      await scheduler.handleTransportUpdate(
        DwBackgroundDownloadUpdate(
          taskId: nativeTaskId,
          status: DwNativeDownloadStatus.running,
          progress: 0.5,
        ),
      );

      final task = (await jobStore.loadTasks('scope-a')).single;
      expect(transport.pausedTaskIds, [nativeTaskId]);
      expect(task.taskState, DwDownloadTaskState.waitingDisk);
      expect(task.attemptCount, 0);
    });

    test('native size mismatch is cancelled before publication', () async {
      await seedPlan(database, assetIds: const ['asset-a']);
      await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
      await scheduler.activateUserScope('scope-a');
      final nativeTaskId = transport.enqueuedRequests.single.taskId;

      await scheduler.handleTransportUpdate(
        DwBackgroundDownloadUpdate(
          taskId: nativeTaskId,
          status: DwNativeDownloadStatus.running,
          progress: 0.01,
          expectedFileSizeBytes: 6,
        ),
      );

      expect(transport.cancelledTaskIds, [nativeTaskId]);
      expect(
        (await jobStore.loadTasks('scope-a')).single.taskState,
        DwDownloadTaskState.failed,
      );
      expect(assetPublisher.publishedPaths, isEmpty);
    });

    test('completion size mismatch discards the native file', () async {
      await seedPlan(database, assetIds: const ['asset-a']);
      await jobStore.createJob(downloadPlan(assetIds: const ['asset-a']));
      await scheduler.activateUserScope('scope-a');
      final nativeTaskId = transport.enqueuedRequests.single.taskId;

      await scheduler.handleTransportUpdate(
        DwBackgroundDownloadUpdate(
          taskId: nativeTaskId,
          status: DwNativeDownloadStatus.complete,
          expectedFileSizeBytes: 6,
          completedFilePath: 'temporary/oversized.download',
        ),
      );

      expect(assetPublisher.discardedPaths, ['temporary/oversized.download']);
      expect(
        (await jobStore.loadTasks('scope-a')).single.taskState,
        DwDownloadTaskState.failed,
      );
      expect(assetPublisher.publishedPaths, isEmpty);
    });
  });
}

DwDownloadPackagePlan downloadPlan({
  String userScopeId = 'scope-a',
  String packageId = 'package-a',
  required List<String> assetIds,
  int expectedSizeBytes = 5,
  Set<String> optionalAssetIds = const {},
}) {
  return DwDownloadPackagePlan(
    userScopeId: userScopeId,
    packageId: packageId,
    manifestRevision: 'manifest-r1',
    manifestDigest: 'manifest-digest',
    priority: 5,
    assets: assetIds.map(
      (assetId) => DwDownloadAssetPlan(
        assetId: assetId,
        assetRevision: 'r1',
        expectedSizeBytes: expectedSizeBytes,
        isRequired: !optionalAssetIds.contains(assetId),
      ),
    ),
  );
}

Future<void> seedPlan(
  DwOfflineDatabase database, {
  String userScopeId = 'scope-a',
  String packageId = 'package-a',
  required List<String> assetIds,
  int expectedSizeBytes = 5,
  Set<String> optionalAssetIds = const {},
}) async {
  await database
      .into(database.dwOfflinePackages)
      .insert(
        DwOfflinePackagesCompanion.insert(
          userScopeId: userScopeId,
          packageId: packageId,
          contentIdentity: 'content-a',
          stagingManifestRevision: const Value('manifest-r1'),
          stagingManifestDigest: const Value('manifest-digest'),
          aggregateStatus: 'staging',
          completedAssetCount: 0,
          totalAssetCount: assetIds.length,
          createdAtEpochMs: 1,
          updatedAtEpochMs: 1,
        ),
      );
  await database
      .into(database.dwOfflineManifests)
      .insert(
        DwOfflineManifestsCompanion.insert(
          userScopeId: userScopeId,
          packageId: packageId,
          manifestRevision: 'manifest-r1',
          payloadDigest: 'manifest-digest',
          envelopeJson: '{}',
          payloadBytes: Uint8List(0),
          createdAtEpochMs: 1,
        ),
      );
  for (final assetId in assetIds) {
    await database
        .into(database.dwOfflineAssets)
        .insert(
          DwOfflineAssetsCompanion.insert(
            userScopeId: userScopeId,
            assetId: assetId,
            assetRevision: 'r1',
            expectedSizeBytes: expectedSizeBytes,
            checksum: 'checksum-$assetId',
            mimeType: 'application/octet-stream',
            relativePath: '$assetId.bin',
            downloadUrl: Value('https://cdn.example.test/$assetId.bin'),
            allowedRedirectHostsJson: const Value('["cdn.example.test"]'),
            assetState: 'missing',
            createdAtEpochMs: 1,
            updatedAtEpochMs: 1,
          ),
        );
    await database
        .into(database.dwOfflineStagingAssets)
        .insert(
          DwOfflineStagingAssetsCompanion.insert(
            userScopeId: userScopeId,
            packageId: packageId,
            manifestRevision: 'manifest-r1',
            assetId: assetId,
            assetRevision: 'r1',
            isRequired: !optionalAssetIds.contains(assetId),
            createdAtEpochMs: 1,
          ),
        );
  }
}

final class FakeBackgroundTransport implements DwBackgroundDownloadTransport {
  final StreamController<DwBackgroundDownloadUpdate> _updates =
      StreamController.broadcast();
  final List<DwBackgroundDownloadRequest> enqueuedRequests = [];
  final List<String> pausedTaskIds = [];
  final List<String> resumedTaskIds = [];
  final List<String> cancelledTaskIds = [];
  final Set<String> activeIds = {};
  int initializeCount = 0;
  int disposeCount = 0;
  bool _isDisposed = false;
  Completer<void>? enqueueGate;
  Object? enqueueError;
  DwBackgroundDownloadUpdate? initializeUpdate;

  @override
  Stream<DwBackgroundDownloadUpdate> get updates => _updates.stream;

  @override
  Future<Set<String>> activeTaskIds() async => Set.of(activeIds);

  @override
  Future<bool> cancel(String taskId) async {
    cancelledTaskIds.add(taskId);
    activeIds.remove(taskId);
    return true;
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    disposeCount++;
    await _updates.close();
  }

  @override
  Future<bool> enqueue(DwBackgroundDownloadRequest request) async {
    enqueuedRequests.add(request);
    await enqueueGate?.future;
    if (enqueueError case final error?) throw error;
    activeIds.add(request.taskId);
    return true;
  }

  @override
  Future<void> initialize() async {
    initializeCount++;
    final update = initializeUpdate;
    if (update != null) _updates.add(update);
  }

  @override
  Future<bool> pause(String taskId) async {
    pausedTaskIds.add(taskId);
    activeIds.remove(taskId);
    return true;
  }

  @override
  Future<bool> resume(String taskId) async {
    resumedTaskIds.add(taskId);
    activeIds.add(taskId);
    return true;
  }
}

final class FakeNetworkSource implements DwNetworkClassSource {
  FakeNetworkSource(this.current);

  final StreamController<DwNetworkClass> _changes =
      StreamController.broadcast();
  DwNetworkClass current;

  @override
  Future<DwNetworkClass> currentNetworkClass() async => current;

  @override
  Stream<DwNetworkClass> get networkClassChanges => _changes.stream;

  Future<void> dispose() => _changes.close();
}

final class FakeDiskSpaceSource implements DwDiskSpaceSource {
  FakeDiskSpaceSource({required this.freeBytes, required this.totalBytes});

  BigInt freeBytes;
  BigInt totalBytes;
  Object? error;

  @override
  Future<DwDiskSpaceSnapshot> read() async {
    if (error case final readError?) throw readError;
    return DwDiskSpaceSnapshot(freeBytes: freeBytes, totalBytes: totalBytes);
  }
}

final class FakeAssetPublisher implements DwDownloadAssetPublisher {
  final List<String> reconciledScopes = [];
  final List<String> publishedPaths = [];
  final List<String> discardedPaths = [];
  final List<String> activatedPackages = [];
  bool publishIntegrityFailure = false;

  @override
  Future<void> discard(String temporaryFilePath) async {
    discardedPaths.add(temporaryFilePath);
  }

  @override
  Future<void> activate({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
    required String manifestDigest,
  }) async {
    activatedPackages.add(packageId);
  }

  @override
  Future<void> publish({
    required String userScopeId,
    required DwOfflineAssetDescriptor assetDescriptor,
    required String temporaryFilePath,
  }) async {
    publishedPaths.add(temporaryFilePath);
    if (publishIntegrityFailure) {
      throw DwOfflineAssetIntegrityException('corrupt test asset');
    }
  }

  @override
  Future<void> reconcileUserScope(String userScopeId) async {
    reconciledScopes.add(userScopeId);
  }
}

final class FakeWakeupScheduler {
  final List<Duration> delays = [];
  void Function()? callback;

  DwDownloadWakeupCancel schedule(Duration delay, void Function() onWakeup) {
    delays.add(delay);
    callback = onWakeup;
    return () => callback = null;
  }
}
