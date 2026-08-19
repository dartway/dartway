import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../network/dw_network_class.dart';
import '../storage/disk_space_plus_source.dart';
import '../storage/dw_disk_reserve_policy.dart';
import '../storage/dw_offline_asset_store.dart';
import 'dw_background_download_transport.dart';
import 'dw_download_asset_publisher.dart';
import 'dw_download_consent_policy.dart';
import 'dw_download_job_store.dart';
import 'dw_download_retry_policy.dart';
import 'dw_download_scheduler_policy.dart';
import 'dw_download_state.dart';

typedef DwDownloadWakeupCancel = void Function();
typedef DwDownloadWakeupScheduler =
    DwDownloadWakeupCancel Function(Duration delay, void Function() onWakeup);

abstract final class _DwDownloadWakeup {
  static DwDownloadWakeupCancel schedule(
    Duration delay,
    void Function() onWakeup,
  ) {
    final timer = Timer(delay, onWakeup);
    return timer.cancel;
  }
}

final class DwDownloadScheduler {
  DwDownloadScheduler({
    required DwDownloadJobStore jobStore,
    required DwBackgroundDownloadTransport transport,
    required DwNetworkClassSource networkSource,
    required DwDiskSpaceSource diskSpaceSource,
    required DwDownloadAssetPublisher assetPublisher,
    required int Function() nowEpochMs,
    DwDownloadWakeupScheduler scheduleWakeup = _DwDownloadWakeup.schedule,
  }) : _jobStore = jobStore,
       _transport = transport,
       _networkSource = networkSource,
       _diskSpaceSource = diskSpaceSource,
       _assetPublisher = assetPublisher,
       _nowEpochMs = nowEpochMs,
       _scheduleWakeup = scheduleWakeup;

  final DwDownloadJobStore _jobStore;
  final DwBackgroundDownloadTransport _transport;
  final DwNetworkClassSource _networkSource;
  final DwDiskSpaceSource _diskSpaceSource;
  final DwDownloadAssetPublisher _assetPublisher;
  final int Function() _nowEpochMs;
  final DwDownloadWakeupScheduler _scheduleWakeup;
  String? _activeUserScopeId;
  StreamSubscription<DwBackgroundDownloadUpdate>? _transportSubscription;
  StreamSubscription<DwNetworkClass>? _networkSubscription;
  bool _isInitialized = false;
  bool _isDisposed = false;
  Future<void> _operationTail = Future<void>.value();
  DwDownloadWakeupCancel? _cancelWakeup;
  final List<DwBackgroundDownloadUpdate> _pendingTransportUpdates = [];
  bool _scopeLifecycleStarted = false;

  Future<void> initialize() async {
    if (_isDisposed) throw StateError('Download scheduler is disposed.');
    if (_isInitialized) return;
    _transportSubscription = _transport.updates.listen((update) {
      if (_activeUserScopeId == null) {
        _pendingTransportUpdates.add(update);
      } else {
        unawaited(handleTransportUpdate(update));
      }
    });
    _networkSubscription = _networkSource.networkClassChanges.listen((_) {
      final userScopeId = _activeUserScopeId;
      if (userScopeId != null) unawaited(runOnce(userScopeId));
    });
    await _transport.initialize();
    _isInitialized = true;
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _cancelWakeup?.call();
    _cancelWakeup = null;
    await _networkSubscription?.cancel();
    await _transportSubscription?.cancel();
    await _transport.dispose();
  }

  Future<void> activateUserScope(String userScopeId) {
    return _serialize(() => _activateUserScope(userScopeId));
  }

  Future<void> deactivateUserScope(String userScopeId) {
    return _serialize(() async {
      if (_activeUserScopeId != userScopeId) return;
      await _deactivateUserScope(userScopeId);
      if (_activeUserScopeId == userScopeId) {
        _activeUserScopeId = null;
        _cancelWakeup?.call();
        _cancelWakeup = null;
      }
    });
  }

  Future<void> _activateUserScope(String userScopeId) async {
    if (userScopeId.trim().isEmpty) {
      throw ArgumentError.value(
        userScopeId,
        'userScopeId',
        'must not be empty',
      );
    }
    _scopeLifecycleStarted = true;
    final previousUserScopeId = _activeUserScopeId;
    if (previousUserScopeId != null && previousUserScopeId != userScopeId) {
      await _deactivateUserScope(previousUserScopeId);
    }
    _activeUserScopeId = userScopeId;
    await _assetPublisher.reconcileUserScope(userScopeId);
    final pendingUpdates = List<DwBackgroundDownloadUpdate>.of(
      _pendingTransportUpdates,
    );
    _pendingTransportUpdates.clear();
    for (final update in pendingUpdates) {
      await _handleTransportUpdate(update);
    }
    await _reconcileNativeTasks(userScopeId);
    await _runOnce(userScopeId);
  }

  Future<void> _deactivateUserScope(String userScopeId) async {
    final tasks = await _jobStore.loadTasks(userScopeId);
    for (final task in tasks) {
      final nativeTaskId = task.nativeTaskId;
      if (nativeTaskId == null) continue;
      await _transport.cancel(nativeTaskId);
      final temporaryFilePath = task.temporaryFilePath;
      if (temporaryFilePath != null) {
        await _assetPublisher.discard(temporaryFilePath);
      }
      if (task.taskState == DwDownloadTaskState.paused) {
        await _jobStore.resetNativeTask(
          nativeTaskId: nativeTaskId,
          taskState: DwDownloadTaskState.paused,
        );
        continue;
      }
      await _jobStore.resetNativeTask(
        nativeTaskId: nativeTaskId,
        taskState: DwDownloadTaskState.waitingNetwork,
        errorJson: '{"kind":"user_scope_inactive"}',
      );
      await _jobStore.markJobState(
        userScopeId: userScopeId,
        jobId: task.identity.jobId,
        jobState: DwDownloadJobState.waitingNetwork,
        pauseReason: 'user_scope_inactive',
      );
    }
  }

  Future<void> grantConsent({
    required String userScopeId,
    required String jobId,
    required String manifestDigest,
  }) {
    return _serialize(
      () => _grantConsent(
        userScopeId: userScopeId,
        jobId: jobId,
        manifestDigest: manifestDigest,
      ),
    );
  }

  Future<void> _grantConsent({
    required String userScopeId,
    required String jobId,
    required String manifestDigest,
  }) async {
    await _jobStore.grantConsent(
      userScopeId: userScopeId,
      jobId: jobId,
      manifestDigest: manifestDigest,
    );
    await _jobStore.markJobState(
      userScopeId: userScopeId,
      jobId: jobId,
      jobState: DwDownloadJobState.queued,
    );
    await _runOnce(userScopeId);
  }

  Future<void> retryFailedAssets({
    required String userScopeId,
    required String jobId,
  }) {
    return _serialize(
      () => _retryFailedAssets(userScopeId: userScopeId, jobId: jobId),
    );
  }

  Future<void> _retryFailedAssets({
    required String userScopeId,
    required String jobId,
  }) async {
    final resetCount = await _jobStore.resetFailedTasks(
      userScopeId: userScopeId,
      jobId: jobId,
    );
    if (resetCount == 0) return;
    await _jobStore.markJobState(
      userScopeId: userScopeId,
      jobId: jobId,
      jobState: DwDownloadJobState.queued,
    );
    await _runOnce(userScopeId);
  }

  Future<void> pauseJob({required String userScopeId, required String jobId}) {
    return _serialize(() => _pauseJob(userScopeId: userScopeId, jobId: jobId));
  }

  Future<void> _pauseJob({
    required String userScopeId,
    required String jobId,
  }) async {
    await _jobStore.markJobState(
      userScopeId: userScopeId,
      jobId: jobId,
      jobState: DwDownloadJobState.paused,
      pauseReason: 'user',
    );
    final tasks = (await _jobStore.loadTasks(
      userScopeId,
    )).where((task) => task.identity.jobId == jobId).toList(growable: false);
    for (final task in tasks) {
      final nativeTaskId = task.nativeTaskId;
      if (nativeTaskId == null || !_isActive(task)) continue;
      if (await _transport.pause(nativeTaskId)) {
        await _jobStore.markTaskState(
          identity: task.identity,
          taskState: DwDownloadTaskState.paused,
        );
      } else {
        await _transport.cancel(nativeTaskId);
        await _jobStore.resetNativeTask(
          nativeTaskId: nativeTaskId,
          taskState: DwDownloadTaskState.paused,
        );
      }
    }
  }

  Future<void> resumeJob({required String userScopeId, required String jobId}) {
    return _serialize(() => _resumeJob(userScopeId: userScopeId, jobId: jobId));
  }

  Future<void> _resumeJob({
    required String userScopeId,
    required String jobId,
  }) async {
    await _jobStore.markJobState(
      userScopeId: userScopeId,
      jobId: jobId,
      jobState: DwDownloadJobState.queued,
    );
    final tasks = (await _jobStore.loadTasks(userScopeId))
        .where(
          (task) =>
              task.identity.jobId == jobId &&
              task.taskState == DwDownloadTaskState.paused,
        )
        .toList(growable: false);
    for (final task in tasks) {
      final nativeTaskId = task.nativeTaskId;
      if (nativeTaskId != null && await _transport.resume(nativeTaskId)) {
        await _jobStore.markTaskState(
          identity: task.identity,
          taskState: DwDownloadTaskState.enqueued,
        );
      } else if (nativeTaskId != null) {
        await _jobStore.resetNativeTask(
          nativeTaskId: nativeTaskId,
          taskState: DwDownloadTaskState.queued,
        );
      } else {
        await _jobStore.markTaskState(
          identity: task.identity,
          taskState: DwDownloadTaskState.queued,
        );
      }
    }
    await _runOnce(userScopeId);
  }

  Future<void> cancelJob({required String userScopeId, required String jobId}) {
    return _serialize(() => _cancelJob(userScopeId: userScopeId, jobId: jobId));
  }

  Future<void> cancelReplacedPackageJobs({
    required String userScopeId,
    required String packageId,
    required String replacementJobId,
  }) {
    return _serialize(() async {
      final statuses = await _jobStore.watchPackageDownloads(userScopeId).first;
      final replacedJobIds = statuses
          .where(
            (status) =>
                status.packageId == packageId &&
                status.jobId != replacementJobId,
          )
          .map((status) => status.jobId)
          .toSet();
      for (final jobId in replacedJobIds) {
        await _cancelJob(userScopeId: userScopeId, jobId: jobId);
      }
    });
  }

  Future<void> cancelPackageJobs({
    required String userScopeId,
    required String packageId,
  }) {
    return _serialize(() async {
      final statuses = await _jobStore.watchPackageDownloads(userScopeId).first;
      final jobIds = statuses
          .where((status) => status.packageId == packageId)
          .map((status) => status.jobId)
          .toSet();
      for (final jobId in jobIds) {
        await _cancelJob(userScopeId: userScopeId, jobId: jobId);
      }
    });
  }

  Future<void> _cancelJob({
    required String userScopeId,
    required String jobId,
  }) async {
    await _jobStore.markJobState(
      userScopeId: userScopeId,
      jobId: jobId,
      jobState: DwDownloadJobState.cancelled,
      pauseReason: 'user_cancelled',
    );
    final tasks = (await _jobStore.loadTasks(
      userScopeId,
    )).where((task) => task.identity.jobId == jobId).toList(growable: false);
    for (final task in tasks) {
      if (task.taskState == DwDownloadTaskState.completed) continue;
      final nativeTaskId = task.nativeTaskId;
      if (nativeTaskId != null) await _transport.cancel(nativeTaskId);
      final temporaryFilePath = task.temporaryFilePath;
      if (temporaryFilePath != null) {
        await _assetPublisher.discard(temporaryFilePath);
      }
      await _jobStore.markCancelled(task.identity);
    }
  }

  Future<void> handleTransportUpdate(DwBackgroundDownloadUpdate update) {
    return _serialize(() => _handleTransportUpdate(update));
  }

  Future<void> _handleTransportUpdate(DwBackgroundDownloadUpdate update) async {
    final userScopeId = _activeUserScopeId;
    if (userScopeId == null) return;
    final matchingTasks = (await _jobStore.loadTasks(userScopeId))
        .where((task) => task.nativeTaskId == update.taskId)
        .toList(growable: false);
    if (matchingTasks.isEmpty) {
      final taskInAnotherScope = await _jobStore.loadTaskByNativeId(
        update.taskId,
      );
      if (taskInAnotherScope != null) {
        _pendingTransportUpdates.add(update);
        return;
      }
      final completedFilePath = update.completedFilePath;
      if (completedFilePath != null && completedFilePath.isNotEmpty) {
        await _assetPublisher.discard(completedFilePath);
      }
      return;
    }
    if (matchingTasks.length != 1) {
      throw StateError('Native task identity is not unique.');
    }
    final task = matchingTasks.single;
    if (update.status == DwNativeDownloadStatus.running ||
        update.status == DwNativeDownloadStatus.complete) {
      final expectedFileSizeBytes = update.expectedFileSizeBytes;
      if (expectedFileSizeBytes != null &&
          expectedFileSizeBytes != task.assetDescriptor.expectedSizeBytes) {
        await _transport.cancel(update.taskId);
        final completedFilePath = update.completedFilePath;
        if (completedFilePath != null && completedFilePath.isNotEmpty) {
          await _assetPublisher.discard(completedFilePath);
        }
        await _markTerminalFailure(
          task,
          update.taskId,
          jsonEncode({
            'kind': 'size_mismatch',
            'expectedSizeBytes': task.assetDescriptor.expectedSizeBytes,
            'reportedSizeBytes': expectedFileSizeBytes,
          }),
        );
        return;
      }
    }
    switch (update.status) {
      case DwNativeDownloadStatus.enqueued:
        return;
      case DwNativeDownloadStatus.running:
        final progress = update.progress;
        final transferredBytes = progress == null
            ? null
            : (task.assetDescriptor.expectedSizeBytes * progress.clamp(0, 1))
                  .round();
        await _jobStore.markTaskStateByNativeId(
          nativeTaskId: update.taskId,
          taskState: DwDownloadTaskState.running,
          transferredBytes: transferredBytes,
        );
        await _enforceDiskDuringDownload(
          task,
          transferredBytes ?? task.transferredBytes,
        );
        return;
      case DwNativeDownloadStatus.waitingToRetry:
        await _scheduleRetry(task, update);
        return;
      case DwNativeDownloadStatus.paused:
        await _jobStore.markTaskStateByNativeId(
          nativeTaskId: update.taskId,
          taskState: DwDownloadTaskState.paused,
        );
        return;
      case DwNativeDownloadStatus.complete:
        await _publishCompletedTask(task, update);
        return;
      case DwNativeDownloadStatus.notFound:
      case DwNativeDownloadStatus.failed:
        await _handleFailure(task, update);
        return;
      case DwNativeDownloadStatus.canceled:
        await _scheduleRetry(task, update);
        return;
    }
  }

  Future<void> _reconcileNativeTasks(String userScopeId) async {
    final activeNativeTaskIds = await _transport.activeTaskIds();
    final tasks = await _jobStore.loadTasks(userScopeId);
    final knownNativeTaskIds = tasks
        .map((task) => task.nativeTaskId)
        .whereType<String>()
        .toSet();
    for (final unknownTaskId in activeNativeTaskIds.difference(
      knownNativeTaskIds,
    )) {
      await _transport.cancel(unknownTaskId);
    }
    for (final task in tasks) {
      final nativeTaskId = task.nativeTaskId;
      if (nativeTaskId == null || activeNativeTaskIds.contains(nativeTaskId)) {
        continue;
      }
      if (task.taskState == DwDownloadTaskState.paused) continue;
      if ((task.taskState == DwDownloadTaskState.publishing ||
              task.taskState == DwDownloadTaskState.waitingDisk) &&
          task.temporaryFilePath != null) {
        await _publishCompletedTask(
          task,
          DwBackgroundDownloadUpdate(
            taskId: nativeTaskId,
            status: DwNativeDownloadStatus.complete,
            completedFilePath: task.temporaryFilePath,
          ),
        );
        continue;
      }
      await _jobStore.resetNativeTask(
        nativeTaskId: nativeTaskId,
        taskState: DwDownloadTaskState.queued,
        errorJson: '{"kind":"native_task_lost"}',
      );
    }
  }

  Future<void> _publishCompletedTask(
    DwStoredDownloadTask task,
    DwBackgroundDownloadUpdate update, {
    bool continueScheduling = true,
  }) async {
    final temporaryFilePath = update.completedFilePath;
    if (temporaryFilePath == null || temporaryFilePath.isEmpty) {
      await _scheduleRetry(task, update);
      return;
    }
    await _jobStore.markPublishingByNativeId(
      nativeTaskId: update.taskId,
      temporaryFilePath: temporaryFilePath,
    );
    final DwDiskSpaceSnapshot diskSnapshot;
    try {
      diskSnapshot = await _diskSpaceSource.read();
    } on Object {
      await _markWaiting(
        task,
        taskState: DwDownloadTaskState.waitingDisk,
        jobState: DwDownloadJobState.waitingDisk,
        reason: 'disk_unavailable',
      );
      return;
    }
    final publishDecision = DwDiskReservePolicy.evaluate(
      totalDiskBytes: diskSnapshot.totalBytes,
      freeDiskBytes: diskSnapshot.freeBytes,
      bytesStillToWrite: BigInt.from(task.assetDescriptor.expectedSizeBytes),
    );
    if (!publishDecision.isAllowed) {
      await _markWaiting(
        task,
        taskState: DwDownloadTaskState.waitingDisk,
        jobState: DwDownloadJobState.waitingDisk,
        reason: 'disk_publish',
      );
      return;
    }
    try {
      await _assetPublisher.publish(
        userScopeId: task.identity.userScopeId,
        assetDescriptor: task.assetDescriptor,
        temporaryFilePath: temporaryFilePath,
      );
    } on DwOfflineAssetIntegrityException catch (error) {
      await _assetPublisher.discard(temporaryFilePath);
      await _markTerminalFailure(task, update.taskId, error.toString());
      return;
    }
    await _jobStore.markCompletedByNativeId(
      nativeTaskId: update.taskId,
      transferredBytes: task.assetDescriptor.expectedSizeBytes,
    );
    if (await _activateIfReady(task)) return;
    if (continueScheduling) {
      await _runOnce(task.identity.userScopeId);
    }
  }

  Future<bool> _activateIfReady(DwStoredDownloadTask task) async {
    final jobTasks = (await _jobStore.loadTasks(task.identity.userScopeId))
        .where((storedTask) => storedTask.identity.jobId == task.identity.jobId)
        .toList(growable: false);
    final activationReady = jobTasks.every(
      (storedTask) =>
          storedTask.taskState == DwDownloadTaskState.completed ||
          (!storedTask.assetDescriptor.isRequired &&
              storedTask.taskState == DwDownloadTaskState.failed),
    );
    if (activationReady) {
      await _jobStore.markJobState(
        userScopeId: task.identity.userScopeId,
        jobId: task.identity.jobId,
        jobState: DwDownloadJobState.activating,
      );
      await _assetPublisher.activate(
        userScopeId: task.identity.userScopeId,
        packageId: task.packageId,
        manifestRevision: task.manifestRevision,
        manifestDigest: task.manifestDigest,
      );
      await _jobStore.markJobState(
        userScopeId: task.identity.userScopeId,
        jobId: task.identity.jobId,
        jobState: DwDownloadJobState.completed,
      );
      return true;
    }
    return false;
  }

  Future<void> _handleFailure(
    DwStoredDownloadTask task,
    DwBackgroundDownloadUpdate update,
  ) async {
    final failureKind = update.failureKind;
    if (failureKind == DwNativeDownloadFailureKind.fileSystem) {
      await _jobStore.resetNativeTask(
        nativeTaskId: update.taskId,
        taskState: DwDownloadTaskState.waitingDisk,
        errorJson: _errorJson(update),
      );
      await _jobStore.markJobState(
        userScopeId: task.identity.userScopeId,
        jobId: task.identity.jobId,
        jobState: DwDownloadJobState.waitingDisk,
        pauseReason: 'disk',
      );
      return;
    }
    final isTerminal = switch (failureKind) {
      DwNativeDownloadFailureKind.unauthorized ||
      DwNativeDownloadFailureKind.forbidden ||
      DwNativeDownloadFailureKind.notFound ||
      DwNativeDownloadFailureKind.invalidUrl => true,
      DwNativeDownloadFailureKind.http =>
        update.responseStatusCode != null && update.responseStatusCode! < 500,
      _ => false,
    };
    if (isTerminal) {
      await _markTerminalFailure(task, update.taskId, _errorJson(update));
      return;
    }
    await _scheduleRetry(task, update);
  }

  Future<void> _scheduleRetry(
    DwStoredDownloadTask task,
    DwBackgroundDownloadUpdate update,
  ) async {
    final retryDecision = DwDownloadRetryPolicy.evaluate(
      failureKind: DwDownloadFailureKind.connection,
      completedRetries: task.attemptCount,
    );
    final retryDelay = retryDecision.retryDelay;
    if (retryDelay == null) {
      await _markTerminalFailure(task, update.taskId, _errorJson(update));
      return;
    }
    await _jobStore.scheduleRetryByNativeId(
      nativeTaskId: update.taskId,
      nextEligibleAtEpochMs: _nowEpochMs() + retryDelay.inMilliseconds,
      errorJson: _errorJson(update),
    );
    _armWakeup(retryDelay);
    await _jobStore.markJobState(
      userScopeId: task.identity.userScopeId,
      jobId: task.identity.jobId,
      jobState: DwDownloadJobState.waitingRetry,
    );
  }

  Future<void> _markTerminalFailure(
    DwStoredDownloadTask task,
    String nativeTaskId,
    String errorJson,
  ) async {
    await _jobStore.markFailedByNativeId(
      nativeTaskId: nativeTaskId,
      errorJson: errorJson,
    );
    if (!task.assetDescriptor.isRequired) {
      if (!await _activateIfReady(task)) {
        await _runOnce(task.identity.userScopeId);
      }
      return;
    }
    await _jobStore.markJobState(
      userScopeId: task.identity.userScopeId,
      jobId: task.identity.jobId,
      jobState: DwDownloadJobState.failed,
    );
  }

  static String _errorJson(DwBackgroundDownloadUpdate update) {
    return jsonEncode({
      'kind': update.failureKind?.name ?? 'unknown',
      'statusCode': update.responseStatusCode,
      'description': update.errorDescription,
    });
  }

  Future<void> runOnce(String userScopeId) {
    return _serialize(() => _runOnce(userScopeId));
  }

  Future<void> _serialize(Future<void> Function() action) {
    if (_isDisposed) {
      return Future<void>.error(StateError('Download scheduler is disposed.'));
    }
    final operation = _operationTail.then((_) => action());
    _operationTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _runOnce(String userScopeId) async {
    if (userScopeId.trim().isEmpty) {
      throw ArgumentError.value(
        userScopeId,
        'userScopeId',
        'must not be empty',
      );
    }
    if (_scopeLifecycleStarted && _activeUserScopeId != userScopeId) {
      throw StateError('Download scheduler scope is not active.');
    }
    await _activateReadyJobs(userScopeId);
    final nowEpochMs = _nowEpochMs();
    final networkClass = await _networkSource.currentNetworkClass();
    var tasks = await _jobStore.loadTasks(userScopeId);
    await _publishStoredTemporaryFiles(tasks);
    tasks = await _jobStore.loadTasks(userScopeId);
    _armEarliestRetry(tasks, nowEpochMs);
    await _enforceActiveNetworkGates(tasks, networkClass);
    tasks = await _jobStore.loadTasks(userScopeId);
    final activeTasks = tasks.where(_isActive).toList(growable: false);
    final activeCandidates = activeTasks.map(_candidateFor).toList();
    final runnableTasks = <DwStoredDownloadTask>[];

    for (final task in tasks) {
      if (task.temporaryFilePath != null) continue;
      if (!_mayRun(task, nowEpochMs)) continue;
      final consentDecision = DwDownloadConsentPolicy.evaluate(
        networkClass: networkClass,
        packageTotalBytes: BigInt.from(task.packageTotalBytes),
        manifestDigest: task.manifestDigest,
        consentedManifestDigest: task.consentedManifestDigest,
      );
      switch (consentDecision) {
        case DwDownloadConsentDecision.waitingNetwork:
          await _markWaiting(
            task,
            taskState: DwDownloadTaskState.waitingNetwork,
            jobState: DwDownloadJobState.waitingNetwork,
            reason: 'network',
          );
          continue;
        case DwDownloadConsentDecision.waitingConsent:
          await _jobStore.markJobState(
            userScopeId: task.identity.userScopeId,
            jobId: task.identity.jobId,
            jobState: DwDownloadJobState.waitingConsent,
            pauseReason: 'consent',
          );
          continue;
        case DwDownloadConsentDecision.allowed:
          runnableTasks.add(task);
      }
    }
    if (runnableTasks.isEmpty) return;

    final selectedCandidates = DwDownloadSchedulerPolicy.select(
      networkClass: networkClass,
      activeDownloads: activeCandidates,
      candidates: runnableTasks.map(_candidateFor),
    );
    if (selectedCandidates.isEmpty) return;
    final tasksByCandidateId = {
      for (final task in runnableTasks) _candidateId(task): task,
    };
    final diskSnapshot = await _readDiskSpaceOrMarkWaiting(
      selectedCandidates,
      tasksByCandidateId,
    );
    if (diskSnapshot == null) return;
    var availableBytes = diskSnapshot.freeBytes;
    for (final selectedCandidate in selectedCandidates) {
      final task = tasksByCandidateId[selectedCandidate.candidateId]!;
      final diskDecision = DwDiskReservePolicy.evaluate(
        freeDiskBytes: availableBytes,
        totalDiskBytes: diskSnapshot.totalBytes,
        bytesStillToWrite: BigInt.from(task.assetDescriptor.expectedSizeBytes),
      );
      if (!diskDecision.isAllowed) {
        await _markWaiting(
          task,
          taskState: DwDownloadTaskState.waitingDisk,
          jobState: DwDownloadJobState.waitingDisk,
          reason: 'disk',
        );
        continue;
      }
      availableBytes -= BigInt.from(task.assetDescriptor.expectedSizeBytes);
      await _startTask(task, nowEpochMs);
    }
  }

  Future<void> _activateReadyJobs(String userScopeId) async {
    final activations = await _jobStore.loadReadyActivations(userScopeId);
    for (final activation in activations) {
      if (activation.userScopeId != userScopeId) {
        throw StateError('Download activation escaped its user scope.');
      }
      await _jobStore.markJobState(
        userScopeId: activation.userScopeId,
        jobId: activation.jobId,
        jobState: DwDownloadJobState.activating,
      );
      await _assetPublisher.activate(
        userScopeId: activation.userScopeId,
        packageId: activation.packageId,
        manifestRevision: activation.manifestRevision,
        manifestDigest: activation.manifestDigest,
      );
      await _jobStore.markJobState(
        userScopeId: activation.userScopeId,
        jobId: activation.jobId,
        jobState: DwDownloadJobState.completed,
      );
    }
  }

  Future<void> _publishStoredTemporaryFiles(
    Iterable<DwStoredDownloadTask> tasks,
  ) async {
    for (final task in tasks) {
      final nativeTaskId = task.nativeTaskId;
      final temporaryFilePath = task.temporaryFilePath;
      if (nativeTaskId == null || temporaryFilePath == null) continue;
      if (task.taskState != DwDownloadTaskState.publishing &&
          task.taskState != DwDownloadTaskState.waitingDisk) {
        continue;
      }
      await _publishCompletedTask(
        task,
        DwBackgroundDownloadUpdate(
          taskId: nativeTaskId,
          status: DwNativeDownloadStatus.complete,
          completedFilePath: temporaryFilePath,
        ),
        continueScheduling: false,
      );
    }
  }

  void _armEarliestRetry(Iterable<DwStoredDownloadTask> tasks, int nowEpochMs) {
    final futureRetryTimes = tasks
        .where(
          (task) =>
              task.taskState == DwDownloadTaskState.waitingRetry &&
              task.nextEligibleAtEpochMs != null &&
              task.nextEligibleAtEpochMs! > nowEpochMs,
        )
        .map((task) => task.nextEligibleAtEpochMs!)
        .toList();
    if (futureRetryTimes.isEmpty) return;
    futureRetryTimes.sort();
    _armWakeup(Duration(milliseconds: futureRetryTimes.first - nowEpochMs));
  }

  void _armWakeup(Duration delay) {
    if (!_isInitialized || _isDisposed) return;
    _cancelWakeup?.call();
    _cancelWakeup = _scheduleWakeup(delay, () {
      _cancelWakeup = null;
      final userScopeId = _activeUserScopeId;
      if (userScopeId != null && !_isDisposed) {
        unawaited(runOnce(userScopeId));
      }
    });
  }

  Future<DwDiskSpaceSnapshot?> _readDiskSpaceOrMarkWaiting(
    List<DwDownloadCandidate> selectedCandidates,
    Map<String, DwStoredDownloadTask> tasksByCandidateId,
  ) async {
    try {
      return await _diskSpaceSource.read();
    } on Object {
      for (final candidate in selectedCandidates) {
        await _markWaiting(
          tasksByCandidateId[candidate.candidateId]!,
          taskState: DwDownloadTaskState.waitingDisk,
          jobState: DwDownloadJobState.waitingDisk,
          reason: 'disk_unavailable',
        );
      }
      return null;
    }
  }

  Future<void> _startTask(DwStoredDownloadTask task, int nowEpochMs) async {
    final existingNativeTaskId = task.nativeTaskId;
    if (existingNativeTaskId != null) {
      if (await _transport.resume(existingNativeTaskId)) {
        await _jobStore.markTaskState(
          identity: task.identity,
          taskState: DwDownloadTaskState.enqueued,
        );
        await _jobStore.markJobState(
          userScopeId: task.identity.userScopeId,
          jobId: task.identity.jobId,
          jobState: DwDownloadJobState.running,
        );
        return;
      }
      await _transport.cancel(existingNativeTaskId);
      await _jobStore.resetNativeTask(
        nativeTaskId: existingNativeTaskId,
        taskState: DwDownloadTaskState.queued,
      );
    }
    final nativeTaskId = _nativeTaskId(task);
    await _jobStore.markEnqueued(
      identity: task.identity,
      nativeTaskId: nativeTaskId,
    );
    final bool enqueued;
    try {
      enqueued = await _transport.enqueue(
        DwBackgroundDownloadRequest(
          taskId: nativeTaskId,
          url: task.assetDescriptor.downloadUrl,
          priority: task.priority,
          allowedRedirectHosts: task.assetDescriptor.allowedRedirectHosts,
          expectedSizeBytes: task.assetDescriptor.expectedSizeBytes,
        ),
      );
    } on Object catch (error) {
      await _scheduleEnqueueRetry(
        task: task,
        nativeTaskId: nativeTaskId,
        nowEpochMs: nowEpochMs,
        errorJson: jsonEncode({
          'kind': 'enqueue_exception',
          'description': error.toString(),
        }),
      );
      return;
    }
    if (enqueued) {
      await _jobStore.markJobState(
        userScopeId: task.identity.userScopeId,
        jobId: task.identity.jobId,
        jobState: DwDownloadJobState.running,
      );
      return;
    }
    await _scheduleEnqueueRetry(
      task: task,
      nativeTaskId: nativeTaskId,
      nowEpochMs: nowEpochMs,
      errorJson: '{"kind":"enqueue_failed"}',
    );
  }

  Future<void> _scheduleEnqueueRetry({
    required DwStoredDownloadTask task,
    required String nativeTaskId,
    required int nowEpochMs,
    required String errorJson,
  }) async {
    final retryDecision = DwDownloadRetryPolicy.evaluate(
      failureKind: DwDownloadFailureKind.connection,
      completedRetries: task.attemptCount,
    );
    if (retryDecision.retryDelay case final retryDelay?) {
      await _jobStore.scheduleRetryByNativeId(
        nativeTaskId: nativeTaskId,
        nextEligibleAtEpochMs: nowEpochMs + retryDelay.inMilliseconds,
        errorJson: errorJson,
      );
      _armWakeup(retryDelay);
      await _jobStore.markJobState(
        userScopeId: task.identity.userScopeId,
        jobId: task.identity.jobId,
        jobState: DwDownloadJobState.waitingRetry,
      );
      return;
    }
    await _markTerminalFailure(task, nativeTaskId, errorJson);
  }

  Future<void> _markWaiting(
    DwStoredDownloadTask task, {
    required DwDownloadTaskState taskState,
    required DwDownloadJobState jobState,
    required String reason,
  }) async {
    await _jobStore.markTaskState(
      identity: task.identity,
      taskState: taskState,
    );
    await _jobStore.markJobState(
      userScopeId: task.identity.userScopeId,
      jobId: task.identity.jobId,
      jobState: jobState,
      pauseReason: reason,
    );
  }

  Future<void> _enforceActiveNetworkGates(
    Iterable<DwStoredDownloadTask> tasks,
    DwNetworkClass networkClass,
  ) async {
    for (final task in tasks.where(_isActive)) {
      final decision = DwDownloadConsentPolicy.evaluate(
        networkClass: networkClass,
        packageTotalBytes: BigInt.from(task.packageTotalBytes),
        manifestDigest: task.manifestDigest,
        consentedManifestDigest: task.consentedManifestDigest,
      );
      switch (decision) {
        case DwDownloadConsentDecision.allowed:
          continue;
        case DwDownloadConsentDecision.waitingNetwork:
          await _pauseForGate(
            task,
            taskState: DwDownloadTaskState.waitingNetwork,
            jobState: DwDownloadJobState.waitingNetwork,
            reason: 'network',
          );
          continue;
        case DwDownloadConsentDecision.waitingConsent:
          await _pauseForGate(
            task,
            taskState: DwDownloadTaskState.waitingNetwork,
            jobState: DwDownloadJobState.waitingConsent,
            reason: 'consent',
          );
          continue;
      }
    }
  }

  Future<void> _enforceDiskDuringDownload(
    DwStoredDownloadTask task,
    int transferredBytes,
  ) async {
    DwDiskSpaceSnapshot diskSnapshot;
    try {
      diskSnapshot = await _diskSpaceSource.read();
    } on Object {
      await _pauseForGate(
        task,
        taskState: DwDownloadTaskState.waitingDisk,
        jobState: DwDownloadJobState.waitingDisk,
        reason: 'disk_unavailable',
      );
      return;
    }
    final remainingBytes =
        task.assetDescriptor.expectedSizeBytes -
        transferredBytes.clamp(0, task.assetDescriptor.expectedSizeBytes);
    final decision = DwDiskReservePolicy.evaluate(
      totalDiskBytes: diskSnapshot.totalBytes,
      freeDiskBytes: diskSnapshot.freeBytes,
      bytesStillToWrite: BigInt.from(remainingBytes),
    );
    if (!decision.isAllowed) {
      await _pauseForGate(
        task,
        taskState: DwDownloadTaskState.waitingDisk,
        jobState: DwDownloadJobState.waitingDisk,
        reason: 'disk',
      );
    }
  }

  Future<void> _pauseForGate(
    DwStoredDownloadTask task, {
    required DwDownloadTaskState taskState,
    required DwDownloadJobState jobState,
    required String reason,
  }) async {
    final nativeTaskId = task.nativeTaskId;
    if (nativeTaskId == null) {
      await _markWaiting(
        task,
        taskState: taskState,
        jobState: jobState,
        reason: reason,
      );
      return;
    }
    if (await _transport.pause(nativeTaskId)) {
      await _jobStore.markTaskState(
        identity: task.identity,
        taskState: taskState,
      );
    } else {
      await _transport.cancel(nativeTaskId);
      await _jobStore.resetNativeTask(
        nativeTaskId: nativeTaskId,
        taskState: taskState,
      );
    }
    await _jobStore.markJobState(
      userScopeId: task.identity.userScopeId,
      jobId: task.identity.jobId,
      jobState: jobState,
      pauseReason: reason,
    );
  }

  static bool _isActive(DwStoredDownloadTask task) {
    return switch (task.taskState) {
      DwDownloadTaskState.enqueued ||
      DwDownloadTaskState.running ||
      DwDownloadTaskState.publishing => true,
      _ => false,
    };
  }

  static bool _mayRun(DwStoredDownloadTask task, int nowEpochMs) {
    if (switch (task.jobState) {
      DwDownloadJobState.paused ||
      DwDownloadJobState.completed ||
      DwDownloadJobState.failed ||
      DwDownloadJobState.cancelled => true,
      _ => false,
    }) {
      return false;
    }
    return switch (task.taskState) {
      DwDownloadTaskState.queued ||
      DwDownloadTaskState.waitingNetwork ||
      DwDownloadTaskState.waitingDisk => true,
      DwDownloadTaskState.waitingRetry =>
        task.nextEligibleAtEpochMs != null &&
            task.nextEligibleAtEpochMs! <= nowEpochMs,
      _ => false,
    };
  }

  static DwDownloadCandidate _candidateFor(DwStoredDownloadTask task) {
    return DwDownloadCandidate(
      candidateId: _candidateId(task),
      packageId: task.packageId,
      host: task.host,
      priority: task.priority,
      createdAtEpochMs: task.createdAtEpochMs,
    );
  }

  static String _candidateId(DwStoredDownloadTask task) {
    return jsonEncode([
      task.identity.jobId,
      task.identity.assetId,
      task.identity.assetRevision,
    ]);
  }

  static String _nativeTaskId(DwStoredDownloadTask task) {
    return 'dw_${sha256.convert(utf8.encode(_candidateId(task)))}';
  }
}
