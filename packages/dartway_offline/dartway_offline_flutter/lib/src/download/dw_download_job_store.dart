import 'dart:convert';

import 'package:drift/drift.dart';

import '../access/dw_offline_lease_policy.dart';
import '../storage/dw_offline_database.dart';
import 'dw_download_plan.dart';
import 'dw_download_state.dart';

final class DwDownloadJobStore {
  const DwDownloadJobStore(this._database);

  final DwOfflineDatabase _database;

  Future<String> createJob(DwDownloadPackagePlan plan, {int? nowEpochMs}) {
    return _database.transaction(() async {
      final packageRow =
          await (_database.select(_database.dwOfflinePackages)..where(
                (row) =>
                    row.userScopeId.equals(plan.userScopeId) &
                    row.packageId.equals(plan.packageId),
              ))
              .getSingleOrNull();
      if (packageRow == null ||
          packageRow.stagingManifestRevision != plan.manifestRevision ||
          packageRow.stagingManifestDigest != plan.manifestDigest) {
        throw StateError('Download plan does not match persisted staging.');
      }

      final existingJob =
          await (_database.select(_database.dwOfflineJobs)..where(
                (row) =>
                    row.userScopeId.equals(plan.userScopeId) &
                    row.jobId.equals(plan.jobId),
              ))
              .getSingleOrNull();
      if (existingJob != null) return plan.jobId;

      final assetRows = <DwOfflineAssetRow>[];
      for (final assetPlan in plan.assets) {
        final assetRow =
            await (_database.select(_database.dwOfflineAssets)..where(
                  (row) =>
                      row.userScopeId.equals(plan.userScopeId) &
                      row.assetId.equals(assetPlan.assetId) &
                      row.assetRevision.equals(assetPlan.assetRevision),
                ))
                .getSingleOrNull();
        if (assetRow == null ||
            assetRow.expectedSizeBytes != assetPlan.expectedSizeBytes) {
          throw StateError('Download asset does not match persisted staging.');
        }
        final stagingRow =
            await (_database.select(_database.dwOfflineStagingAssets)..where(
                  (row) =>
                      row.userScopeId.equals(plan.userScopeId) &
                      row.packageId.equals(plan.packageId) &
                      row.manifestRevision.equals(plan.manifestRevision) &
                      row.assetId.equals(assetPlan.assetId) &
                      row.assetRevision.equals(assetPlan.assetRevision),
                ))
                .getSingleOrNull();
        if (stagingRow == null) {
          throw StateError('Download asset is not in persisted staging.');
        }
        if (stagingRow.isRequired != assetPlan.isRequired) {
          throw StateError('Download asset requirement flag does not match.');
        }
        assetRows.add(assetRow);
      }

      await (_database.delete(_database.dwOfflineJobs)..where(
            (row) =>
                row.userScopeId.equals(plan.userScopeId) &
                row.packageId.equals(plan.packageId),
          ))
          .go();
      final timestamp =
          nowEpochMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
      final pendingAssetRows = assetRows
          .where(
            (asset) =>
                asset.assetState != 'ready' ||
                asset.isTombstoned ||
                asset.blobName == null,
          )
          .toList(growable: false);
      await _database
          .into(_database.dwOfflineJobs)
          .insert(
            DwOfflineJobsCompanion.insert(
              userScopeId: plan.userScopeId,
              jobId: plan.jobId,
              packageId: Value(plan.packageId),
              jobType: 'download',
              jobState: pendingAssetRows.isEmpty ? 'activating' : 'queued',
              manifestRevision: Value(plan.manifestRevision),
              manifestDigest: Value(plan.manifestDigest),
              priority: Value(plan.priority),
              packageTotalBytes: Value(plan.packageTotalBytes),
              attemptCount: 0,
              payloadJson: '{"schemaVersion":1}',
              createdAtEpochMs: timestamp,
              updatedAtEpochMs: timestamp,
            ),
          );
      for (final assetRow in pendingAssetRows) {
        await _database
            .into(_database.dwOfflineDownloadTasks)
            .insert(
              DwOfflineDownloadTasksCompanion.insert(
                userScopeId: plan.userScopeId,
                jobId: plan.jobId,
                assetId: assetRow.assetId,
                assetRevision: assetRow.assetRevision,
                isRequired: Value(
                  plan.assets
                      .singleWhere(
                        (asset) =>
                            asset.assetId == assetRow.assetId &&
                            asset.assetRevision == assetRow.assetRevision,
                      )
                      .isRequired,
                ),
                taskState: 'queued',
                attemptCount: 0,
                createdAtEpochMs: timestamp,
                updatedAtEpochMs: timestamp,
              ),
            );
      }
      return plan.jobId;
    });
  }

  Future<void> grantConsent({
    required String userScopeId,
    required String jobId,
    required String manifestDigest,
  }) async {
    if (manifestDigest.isEmpty) {
      throw ArgumentError.value(
        manifestDigest,
        'manifestDigest',
        'must not be empty',
      );
    }
    final changedRows =
        await (_database.update(_database.dwOfflineJobs)..where(
              (row) =>
                  row.userScopeId.equals(userScopeId) &
                  row.jobId.equals(jobId) &
                  row.manifestDigest.equals(manifestDigest),
            ))
            .write(
              DwOfflineJobsCompanion(
                consentedManifestDigest: Value(manifestDigest),
                updatedAtEpochMs: Value(
                  DateTime.now().toUtc().millisecondsSinceEpoch,
                ),
              ),
            );
    if (changedRows != 1) {
      throw StateError('Consent does not match the download manifest.');
    }
  }

  Future<List<DwStoredDownloadTask>> loadTasks(String userScopeId) async {
    final taskTable = _database.dwOfflineDownloadTasks;
    final jobTable = _database.dwOfflineJobs;
    final assetTable = _database.dwOfflineAssets;
    final rows = await (_database.select(taskTable).join([
      innerJoin(
        jobTable,
        jobTable.userScopeId.equalsExp(taskTable.userScopeId) &
            jobTable.jobId.equalsExp(taskTable.jobId),
      ),
      innerJoin(
        assetTable,
        assetTable.userScopeId.equalsExp(taskTable.userScopeId) &
            assetTable.assetId.equalsExp(taskTable.assetId) &
            assetTable.assetRevision.equalsExp(taskTable.assetRevision),
      ),
    ])..where(taskTable.userScopeId.equals(userScopeId))).get();

    final storedTasks = <DwStoredDownloadTask>[];
    for (final row in rows) {
      final task = row.readTable(taskTable);
      final job = row.readTable(jobTable);
      final asset = row.readTable(assetTable);
      final packageId = job.packageId;
      final manifestRevision = job.manifestRevision;
      final manifestDigest = job.manifestDigest;
      final packageTotalBytes = job.packageTotalBytes;
      if (packageId == null ||
          manifestRevision == null ||
          manifestDigest == null ||
          packageTotalBytes == null ||
          asset.downloadUrl == null ||
          asset.allowedRedirectHostsJson == null) {
        throw StateError('Persisted download task metadata is incomplete.');
      }
      final redirectHosts = _decodeRedirectHosts(
        asset.allowedRedirectHostsJson!,
      );
      storedTasks.add(
        DwStoredDownloadTask(
          identity: DwDownloadTaskIdentity(
            userScopeId: task.userScopeId,
            jobId: task.jobId,
            assetId: task.assetId,
            assetRevision: task.assetRevision,
          ),
          packageId: packageId,
          manifestRevision: manifestRevision,
          manifestDigest: manifestDigest,
          priority: job.priority,
          packageTotalBytes: packageTotalBytes,
          consentedManifestDigest: job.consentedManifestDigest,
          jobState: DwDownloadJobState.fromStorage(job.jobState),
          taskState: DwDownloadTaskState.fromStorage(task.taskState),
          assetDescriptor: DwOfflineAssetDescriptor.internalForStorage(
            assetId: asset.assetId,
            assetRevision: asset.assetRevision,
            downloadUrl: asset.downloadUrl!,
            allowedRedirectHosts: redirectHosts,
            expectedSizeBytes: asset.expectedSizeBytes,
            sha256Hex: asset.checksum,
            mimeType: asset.mimeType,
            logicalRelativePath: asset.relativePath,
            isRequired: task.isRequired,
          ),
          nativeTaskId: task.nativeTaskId,
          temporaryFilePath: task.temporaryFilePath,
          transferredBytes: task.transferredBytes,
          attemptCount: task.attemptCount,
          nextEligibleAtEpochMs: task.nextEligibleAtEpochMs,
          lastErrorJson: task.lastErrorJson,
          createdAtEpochMs: task.createdAtEpochMs,
        ),
      );
    }
    return List.unmodifiable(storedTasks);
  }

  Future<DwStoredDownloadTask?> loadTaskByNativeId(String nativeTaskId) async {
    if (nativeTaskId.trim().isEmpty || nativeTaskId != nativeTaskId.trim()) {
      throw ArgumentError.value(nativeTaskId, 'nativeTaskId');
    }
    final taskRow = await (_database.select(
      _database.dwOfflineDownloadTasks,
    )..where((row) => row.nativeTaskId.equals(nativeTaskId))).getSingleOrNull();
    if (taskRow == null) return null;
    for (final task in await loadTasks(taskRow.userScopeId)) {
      if (task.nativeTaskId == nativeTaskId) return task;
    }
    return null;
  }

  Stream<List<DwOfflinePackageDownloadStatus>> watchPackageDownloads(
    String userScopeId,
  ) {
    if (userScopeId.trim().isEmpty || userScopeId != userScopeId.trim()) {
      throw ArgumentError.value(userScopeId, 'userScopeId');
    }
    final jobTable = _database.dwOfflineJobs;
    final taskTable = _database.dwOfflineDownloadTasks;
    final assetTable = _database.dwOfflineAssets;
    final query = _database.select(jobTable).join([
      leftOuterJoin(
        taskTable,
        taskTable.userScopeId.equalsExp(jobTable.userScopeId) &
            taskTable.jobId.equalsExp(jobTable.jobId),
      ),
      leftOuterJoin(
        assetTable,
        assetTable.userScopeId.equalsExp(taskTable.userScopeId) &
            assetTable.assetId.equalsExp(taskTable.assetId) &
            assetTable.assetRevision.equalsExp(taskTable.assetRevision),
      ),
    ])..where(jobTable.userScopeId.equals(userScopeId));
    return query.watch().map((rows) {
      final aggregates = <String, _DownloadStatusAggregate>{};
      for (final row in rows) {
        final job = row.readTable(jobTable);
        final packageId = job.packageId;
        final manifestRevision = job.manifestRevision;
        final manifestDigest = job.manifestDigest;
        if (packageId == null ||
            manifestRevision == null ||
            manifestDigest == null) {
          throw StateError('Persisted download status metadata is incomplete.');
        }
        final aggregate = aggregates.putIfAbsent(
          job.jobId,
          () => _DownloadStatusAggregate(
            job,
            packageId,
            manifestRevision,
            manifestDigest,
          ),
        );
        final task = row.readTableOrNull(taskTable);
        if (task == null) continue;
        final asset = row.readTableOrNull(assetTable);
        if (asset == null) {
          throw StateError('Persisted download task asset is missing.');
        }
        aggregate
          ..fileCount += 1
          ..bytesToDownload += asset.expectedSizeBytes
          ..bytesDownloaded += task.transferredBytes;
        if (task.taskState == DwDownloadTaskState.completed.name) {
          aggregate.completedFileCount += 1;
        }
        if (task.lastErrorJson != null) {
          aggregate.lastErrorJson = task.lastErrorJson;
        }
      }
      final statuses =
          aggregates.values
              .map((aggregate) => aggregate.toStatus())
              .toList(growable: false)
            ..sort((left, right) => right.jobId.compareTo(left.jobId));
      return List<DwOfflinePackageDownloadStatus>.unmodifiable(statuses);
    });
  }

  Future<List<DwStoredDownloadActivation>> loadReadyActivations(
    String userScopeId,
  ) async {
    final jobs =
        await (_database.select(_database.dwOfflineJobs)..where(
              (row) =>
                  row.userScopeId.equals(userScopeId) &
                  row.jobState.isIn([
                    DwDownloadJobState.running.name,
                    DwDownloadJobState.activating.name,
                  ]),
            ))
            .get();
    if (jobs.isEmpty) return const [];

    final tasks = await (_database.select(
      _database.dwOfflineDownloadTasks,
    )..where((row) => row.userScopeId.equals(userScopeId))).get();
    final tasksByJobId = <String, List<DwOfflineDownloadTaskRow>>{};
    for (final task in tasks) {
      tasksByJobId.putIfAbsent(task.jobId, () => []).add(task);
    }

    final activations = <DwStoredDownloadActivation>[];
    for (final job in jobs) {
      final jobTasks = tasksByJobId[job.jobId] ?? const [];
      final isReady = jobTasks.every(
        (task) =>
            task.taskState == DwDownloadTaskState.completed.name ||
            (!task.isRequired &&
                task.taskState == DwDownloadTaskState.failed.name),
      );
      if (!isReady) continue;
      final packageId = job.packageId;
      final manifestRevision = job.manifestRevision;
      final manifestDigest = job.manifestDigest;
      if (packageId == null ||
          manifestRevision == null ||
          manifestDigest == null) {
        throw StateError(
          'Persisted download activation metadata is incomplete.',
        );
      }
      activations.add(
        DwStoredDownloadActivation(
          userScopeId: job.userScopeId,
          jobId: job.jobId,
          packageId: packageId,
          manifestRevision: manifestRevision,
          manifestDigest: manifestDigest,
        ),
      );
    }
    return List.unmodifiable(activations);
  }

  Future<void> markEnqueued({
    required DwDownloadTaskIdentity identity,
    required String nativeTaskId,
  }) async {
    if (nativeTaskId.isEmpty) {
      throw ArgumentError.value(
        nativeTaskId,
        'nativeTaskId',
        'must not be empty',
      );
    }
    final changedRows =
        await (_database.update(_database.dwOfflineDownloadTasks)..where(
              (row) =>
                  row.userScopeId.equals(identity.userScopeId) &
                  row.jobId.equals(identity.jobId) &
                  row.assetId.equals(identity.assetId) &
                  row.assetRevision.equals(identity.assetRevision),
            ))
            .write(
              DwOfflineDownloadTasksCompanion(
                taskState: Value(DwDownloadTaskState.enqueued.name),
                nativeTaskId: Value(nativeTaskId),
                nextEligibleAtEpochMs: const Value(null),
                lastErrorJson: const Value(null),
                updatedAtEpochMs: Value(
                  DateTime.now().toUtc().millisecondsSinceEpoch,
                ),
              ),
            );
    if (changedRows != 1) throw StateError('Download task was not found.');
  }

  Future<void> markTaskState({
    required DwDownloadTaskIdentity identity,
    required DwDownloadTaskState taskState,
  }) async {
    final changedRows =
        await (_database.update(_database.dwOfflineDownloadTasks)..where(
              (row) =>
                  row.userScopeId.equals(identity.userScopeId) &
                  row.jobId.equals(identity.jobId) &
                  row.assetId.equals(identity.assetId) &
                  row.assetRevision.equals(identity.assetRevision),
            ))
            .write(
              DwOfflineDownloadTasksCompanion(
                taskState: Value(taskState.name),
                updatedAtEpochMs: Value(
                  DateTime.now().toUtc().millisecondsSinceEpoch,
                ),
              ),
            );
    if (changedRows != 1) throw StateError('Download task was not found.');
  }

  Future<void> markJobState({
    required String userScopeId,
    required String jobId,
    required DwDownloadJobState jobState,
    String? pauseReason,
  }) async {
    final changedRows =
        await (_database.update(_database.dwOfflineJobs)..where(
              (row) =>
                  row.userScopeId.equals(userScopeId) & row.jobId.equals(jobId),
            ))
            .write(
              DwOfflineJobsCompanion(
                jobState: Value(jobState.name),
                pauseReason: Value(pauseReason),
                updatedAtEpochMs: Value(
                  DateTime.now().toUtc().millisecondsSinceEpoch,
                ),
              ),
            );
    if (changedRows != 1) throw StateError('Download job was not found.');
  }

  Future<void> markTaskStateByNativeId({
    required String nativeTaskId,
    required DwDownloadTaskState taskState,
    int? transferredBytes,
    String? temporaryFilePath,
  }) async {
    if (transferredBytes != null && transferredBytes < 0) {
      throw ArgumentError.value(
        transferredBytes,
        'transferredBytes',
        'must not be negative',
      );
    }
    final changedRows =
        await (_database.update(
          _database.dwOfflineDownloadTasks,
        )..where((row) => row.nativeTaskId.equals(nativeTaskId))).write(
          DwOfflineDownloadTasksCompanion(
            taskState: Value(taskState.name),
            transferredBytes: transferredBytes == null
                ? const Value.absent()
                : Value(transferredBytes),
            temporaryFilePath: temporaryFilePath == null
                ? const Value.absent()
                : Value(temporaryFilePath),
            updatedAtEpochMs: Value(
              DateTime.now().toUtc().millisecondsSinceEpoch,
            ),
          ),
        );
    if (changedRows != 1) {
      throw StateError('Native download task was not found.');
    }
  }

  Future<void> scheduleRetryByNativeId({
    required String nativeTaskId,
    required int nextEligibleAtEpochMs,
    required String errorJson,
  }) {
    return _database.transaction(() async {
      final task =
          await (_database.select(_database.dwOfflineDownloadTasks)
                ..where((row) => row.nativeTaskId.equals(nativeTaskId)))
              .getSingleOrNull();
      if (task == null) throw StateError('Native download task was not found.');
      await (_database.update(_database.dwOfflineDownloadTasks)..where(
            (row) =>
                row.userScopeId.equals(task.userScopeId) &
                row.jobId.equals(task.jobId) &
                row.assetId.equals(task.assetId) &
                row.assetRevision.equals(task.assetRevision),
          ))
          .write(
            DwOfflineDownloadTasksCompanion(
              taskState: Value(DwDownloadTaskState.waitingRetry.name),
              nativeTaskId: const Value(null),
              temporaryFilePath: const Value(null),
              attemptCount: Value(task.attemptCount + 1),
              nextEligibleAtEpochMs: Value(nextEligibleAtEpochMs),
              lastErrorJson: Value(errorJson),
              updatedAtEpochMs: Value(
                DateTime.now().toUtc().millisecondsSinceEpoch,
              ),
            ),
          );
    });
  }

  Future<void> markPublishingByNativeId({
    required String nativeTaskId,
    required String temporaryFilePath,
  }) async {
    if (temporaryFilePath.isEmpty) {
      throw ArgumentError.value(
        temporaryFilePath,
        'temporaryFilePath',
        'must not be empty',
      );
    }
    final changedRows =
        await (_database.update(
          _database.dwOfflineDownloadTasks,
        )..where((row) => row.nativeTaskId.equals(nativeTaskId))).write(
          DwOfflineDownloadTasksCompanion(
            taskState: Value(DwDownloadTaskState.publishing.name),
            temporaryFilePath: Value(temporaryFilePath),
            updatedAtEpochMs: Value(
              DateTime.now().toUtc().millisecondsSinceEpoch,
            ),
          ),
        );
    if (changedRows != 1) {
      throw StateError('Native download task was not found.');
    }
  }

  Future<void> markCompletedByNativeId({
    required String nativeTaskId,
    required int transferredBytes,
  }) async {
    final changedRows =
        await (_database.update(
          _database.dwOfflineDownloadTasks,
        )..where((row) => row.nativeTaskId.equals(nativeTaskId))).write(
          DwOfflineDownloadTasksCompanion(
            taskState: Value(DwDownloadTaskState.completed.name),
            nativeTaskId: const Value(null),
            temporaryFilePath: const Value(null),
            transferredBytes: Value(transferredBytes),
            nextEligibleAtEpochMs: const Value(null),
            lastErrorJson: const Value(null),
            updatedAtEpochMs: Value(
              DateTime.now().toUtc().millisecondsSinceEpoch,
            ),
          ),
        );
    if (changedRows != 1) {
      throw StateError('Native download task was not found.');
    }
  }

  Future<void> markFailedByNativeId({
    required String nativeTaskId,
    required String errorJson,
  }) async {
    final changedRows =
        await (_database.update(
          _database.dwOfflineDownloadTasks,
        )..where((row) => row.nativeTaskId.equals(nativeTaskId))).write(
          DwOfflineDownloadTasksCompanion(
            taskState: Value(DwDownloadTaskState.failed.name),
            nativeTaskId: const Value(null),
            temporaryFilePath: const Value(null),
            nextEligibleAtEpochMs: const Value(null),
            lastErrorJson: Value(errorJson),
            updatedAtEpochMs: Value(
              DateTime.now().toUtc().millisecondsSinceEpoch,
            ),
          ),
        );
    if (changedRows != 1) {
      throw StateError('Native download task was not found.');
    }
  }

  Future<int> resetFailedTasks({
    required String userScopeId,
    required String jobId,
  }) {
    return (_database.update(_database.dwOfflineDownloadTasks)..where(
          (row) =>
              row.userScopeId.equals(userScopeId) &
              row.jobId.equals(jobId) &
              row.taskState.equals(DwDownloadTaskState.failed.name),
        ))
        .write(
          DwOfflineDownloadTasksCompanion(
            taskState: Value(DwDownloadTaskState.queued.name),
            nativeTaskId: const Value(null),
            temporaryFilePath: const Value(null),
            transferredBytes: const Value(0),
            attemptCount: const Value(0),
            nextEligibleAtEpochMs: const Value(null),
            lastErrorJson: const Value(null),
            updatedAtEpochMs: Value(
              DateTime.now().toUtc().millisecondsSinceEpoch,
            ),
          ),
        );
  }

  Future<void> resetNativeTask({
    required String nativeTaskId,
    required DwDownloadTaskState taskState,
    String? errorJson,
  }) async {
    final changedRows =
        await (_database.update(
          _database.dwOfflineDownloadTasks,
        )..where((row) => row.nativeTaskId.equals(nativeTaskId))).write(
          DwOfflineDownloadTasksCompanion(
            taskState: Value(taskState.name),
            nativeTaskId: const Value(null),
            temporaryFilePath: const Value(null),
            nextEligibleAtEpochMs: const Value(null),
            lastErrorJson: Value(errorJson),
            updatedAtEpochMs: Value(
              DateTime.now().toUtc().millisecondsSinceEpoch,
            ),
          ),
        );
    if (changedRows != 1) {
      throw StateError('Native download task was not found.');
    }
  }

  Future<void> markCancelled(DwDownloadTaskIdentity identity) async {
    final changedRows =
        await (_database.update(_database.dwOfflineDownloadTasks)..where(
              (row) =>
                  row.userScopeId.equals(identity.userScopeId) &
                  row.jobId.equals(identity.jobId) &
                  row.assetId.equals(identity.assetId) &
                  row.assetRevision.equals(identity.assetRevision),
            ))
            .write(
              DwOfflineDownloadTasksCompanion(
                taskState: Value(DwDownloadTaskState.cancelled.name),
                nativeTaskId: const Value(null),
                temporaryFilePath: const Value(null),
                nextEligibleAtEpochMs: const Value(null),
                lastErrorJson: const Value('{"kind":"cancelled"}'),
                updatedAtEpochMs: Value(
                  DateTime.now().toUtc().millisecondsSinceEpoch,
                ),
              ),
            );
    if (changedRows != 1) throw StateError('Download task was not found.');
  }

  static List<String> _decodeRedirectHosts(String encodedHosts) {
    final decoded = jsonDecode(encodedHosts);
    if (decoded is! List || decoded.any((host) => host is! String)) {
      throw StateError('Persisted redirect host list is invalid.');
    }
    return List<String>.unmodifiable(decoded.cast<String>());
  }
}

final class _DownloadStatusAggregate {
  _DownloadStatusAggregate(
    this.job,
    this.packageId,
    this.manifestRevision,
    this.manifestDigest,
  ) : lastErrorJson = job.lastErrorJson;

  final DwOfflineJobRow job;
  final String packageId;
  final String manifestRevision;
  final String manifestDigest;
  int bytesDownloaded = 0;
  int bytesToDownload = 0;
  int completedFileCount = 0;
  int fileCount = 0;
  String? lastErrorJson;

  DwOfflinePackageDownloadStatus toStatus() {
    return DwOfflinePackageDownloadStatus(
      userScopeId: job.userScopeId,
      packageId: packageId,
      jobId: job.jobId,
      manifestRevision: manifestRevision,
      manifestDigest: manifestDigest,
      state: DwDownloadJobState.fromStorage(job.jobState),
      bytesDownloaded: bytesDownloaded,
      bytesToDownload: bytesToDownload,
      completedFileCount: completedFileCount,
      fileCount: fileCount,
      pauseReason: job.pauseReason,
      lastErrorJson: lastErrorJson,
    );
  }
}
