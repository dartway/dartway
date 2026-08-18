import 'dart:convert';

import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:drift/drift.dart';

import '../access/dw_offline_access_store.dart';
import '../access/dw_offline_lease_policy.dart';
import '../repository/dw_offline_read_delegate.dart';
import '../storage/dw_offline_asset_store.dart';
import '../storage/dw_offline_database.dart';
import 'dw_download_job_store.dart';
import 'dw_download_plan.dart';
import 'dw_download_scheduler.dart';

enum DwOfflinePackageDownloadStartStatus {
  started,
  accessRevoked,
  invalidManifest,
  bindingMismatch,
  replayRejected,
  contentMismatch,
}

final class DwOfflinePackageDownloadStartResult {
  const DwOfflinePackageDownloadStartResult._({
    required this.status,
    this.jobId,
  });

  final DwOfflinePackageDownloadStartStatus status;
  final String? jobId;
}

/// One exact repository response installed as part of an offline package.
final class DwOfflinePackageSnapshot {
  DwOfflinePackageSnapshot({
    required this.queryStorageKey,
    required Map<String, dynamic> responseJson,
  }) : responseJson = _copyJson(responseJson) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(queryStorageKey)) {
      throw ArgumentError.value(
        queryStorageKey,
        'queryStorageKey',
        'must be a lowercase SHA-256 key',
      );
    }
  }

  final String queryStorageKey;
  final Map<String, dynamic> responseJson;

  static Map<String, dynamic> _copyJson(Map<String, dynamic> responseJson) {
    final decoded = jsonDecode(jsonEncode(responseJson));
    return Map<String, dynamic>.unmodifiable(
      Map<String, dynamic>.from(decoded as Map),
    );
  }
}

/// Verifies and durably stages one generic offline package before scheduling.
final class DwOfflinePackageDownloadCoordinator {
  DwOfflinePackageDownloadCoordinator({
    required DwOfflineDatabase database,
    required DwOfflineManifestVerifier manifestVerifier,
    required String expectedAudience,
    required DwOfflineAccessStore accessStore,
    required DwOfflineAssetStore assetStore,
    required DwOfflineReadDelegate readDelegate,
    required DwDownloadJobStore jobStore,
    required DwDownloadScheduler scheduler,
  }) : _database = database,
       _manifestVerifier = manifestVerifier,
       _expectedAudience = expectedAudience,
       _accessStore = accessStore,
       _assetStore = assetStore,
       _readDelegate = readDelegate,
       _jobStore = jobStore,
       _scheduler = scheduler {
    if (expectedAudience.trim().isEmpty ||
        expectedAudience != expectedAudience.trim()) {
      throw ArgumentError.value(expectedAudience, 'expectedAudience');
    }
  }

  final DwOfflineDatabase _database;
  final DwOfflineManifestVerifier _manifestVerifier;
  final String _expectedAudience;
  final DwOfflineAccessStore _accessStore;
  final DwOfflineAssetStore _assetStore;
  final DwOfflineReadDelegate _readDelegate;
  final DwDownloadJobStore _jobStore;
  final DwDownloadScheduler _scheduler;

  Future<DwOfflinePackageDownloadStartResult> start({
    required String userScopeId,
    required String packageId,
    required String signedManifestEnvelopeJson,
    required String repositoryContentRevision,
    required Iterable<DwOfflinePackageSnapshot> snapshots,
    Future<Iterable<DwOfflinePackageSnapshot>> Function()? snapshotLoader,
    bool Function()? isScopeActive,
    int priority = 0,
  }) async {
    if (userScopeId.trim().isEmpty || userScopeId != userScopeId.trim()) {
      throw ArgumentError.value(userScopeId, 'userScopeId');
    }
    if (packageId.trim().isEmpty || packageId != packageId.trim()) {
      throw ArgumentError.value(packageId, 'packageId');
    }
    final preliminary = await _manifestVerifier.verify(
      envelopeJson: signedManifestEnvelopeJson,
      expectedAudience: _expectedAudience,
      expectedUserScopeId: userScopeId,
      expectedPackageId: packageId,
    );
    final preliminaryManifest = preliminary.verifiedManifest;
    if (preliminaryManifest == null) {
      return _rejected(preliminary.status);
    }
    final previousLeaseRecord = await _loadPreviousLeaseRecord(
      preliminaryManifest,
    );
    final verification = await _manifestVerifier.verify(
      envelopeJson: signedManifestEnvelopeJson,
      expectedAudience: _expectedAudience,
      expectedUserScopeId: userScopeId,
      expectedPackageId: packageId,
      previousLeaseRecord: previousLeaseRecord,
    );
    final verifiedManifest = verification.verifiedManifest;
    if (verifiedManifest == null) return _rejected(verification.status);
    if (repositoryContentRevision !=
        verifiedManifest.manifest.repositoryContentDigest) {
      return const DwOfflinePackageDownloadStartResult._(
        status: DwOfflinePackageDownloadStartStatus.contentMismatch,
      );
    }
    _requireScopeActive(isScopeActive);
    if (verifiedManifest.acceptedLeaseRecord.lease!.isRevoked) {
      await _accessStore.persistVerifiedManifestLease(verifiedManifest);
      await _scheduler.cancelPackageJobs(
        userScopeId: userScopeId,
        packageId: packageId,
      );
      await _assetStore.deletePackage(
        userScopeId: userScopeId,
        packageId: packageId,
      );
      return const DwOfflinePackageDownloadStartResult._(
        status: DwOfflinePackageDownloadStartStatus.accessRevoked,
      );
    }
    if (snapshotLoader != null && snapshots.isNotEmpty) {
      throw ArgumentError('Provide snapshots or snapshotLoader, not both.');
    }
    final snapshotList = List<DwOfflinePackageSnapshot>.unmodifiable(
      snapshotLoader == null ? snapshots : await snapshotLoader(),
    );
    _requireScopeActive(isScopeActive);
    if (snapshotList
            .map((snapshot) => snapshot.queryStorageKey)
            .toSet()
            .length !=
        snapshotList.length) {
      throw ArgumentError('Package contains a duplicate repository snapshot.');
    }
    if (!_snapshotsMatchSignedContent(
      snapshotList,
      verifiedManifest.manifest.repositoryContentDigest,
    )) {
      return const DwOfflinePackageDownloadStartResult._(
        status: DwOfflinePackageDownloadStartStatus.contentMismatch,
      );
    }
    final plan = DwDownloadPackagePlan.fromVerifiedManifest(
      verifiedManifest,
      priority: priority,
    );

    await _assetStore.beginStagingManifest(verifiedManifest);
    await _readDelegate.replacePackageSnapshotsStorageKeys(
      verifiedManifest: verifiedManifest,
      snapshotsByStorageKey: {
        for (final snapshot in snapshotList)
          snapshot.queryStorageKey: DwRepoReadSnapshot(
            schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
            scope: DwRepoScope(userScopeId),
            responseJson: snapshot.responseJson,
          ),
      },
    );
    await _accessStore.persistVerifiedManifestLease(verifiedManifest);
    await _scheduler.cancelReplacedPackageJobs(
      userScopeId: userScopeId,
      packageId: packageId,
      replacementJobId: plan.jobId,
    );
    final jobId = await _jobStore.createJob(plan);
    await _scheduler.runOnce(userScopeId);
    return DwOfflinePackageDownloadStartResult._(
      status: DwOfflinePackageDownloadStartStatus.started,
      jobId: jobId,
    );
  }

  static void _requireScopeActive(bool Function()? isScopeActive) {
    if (isScopeActive?.call() == false) {
      throw StateError('Offline user scope changed during package download.');
    }
  }

  static bool _snapshotsMatchSignedContent(
    List<DwOfflinePackageSnapshot> snapshots,
    String repositoryContentDigest,
  ) {
    try {
      final snapshotRevision =
          DwOfflineRepositoryContentRevision.computeFromRepositoryResponses(
            snapshots.map(
              (snapshot) => Map<String, Object?>.from(snapshot.responseJson),
            ),
          );
      return snapshotRevision == repositoryContentDigest;
    } on ArgumentError {
      return false;
    } on FormatException {
      return false;
    }
  }

  Future<DwOfflineLeaseRecord> _loadPreviousLeaseRecord(
    DwVerifiedOfflineManifest candidate,
  ) async {
    final candidateLease = candidate.acceptedLeaseRecord.lease!;
    var previous = await _accessStore.loadPreviousLeaseRecord(candidate);
    final manifestRows =
        await (_database.select(_database.dwOfflineManifests)..where(
              (row) =>
                  row.userScopeId.equals(candidate.manifest.userScopeId) &
                  row.packageId.equals(candidate.manifest.packageId),
            ))
            .get();
    for (final row in manifestRows) {
      final verification = await _manifestVerifier.verify(
        envelopeJson: row.envelopeJson,
        expectedAudience: _expectedAudience,
        expectedUserScopeId: row.userScopeId,
        expectedPackageId: row.packageId,
      );
      final storedManifest = verification.verifiedManifest;
      if (storedManifest == null ||
          storedManifest.manifest.manifestRevision != row.manifestRevision ||
          storedManifest.payloadDigest != row.payloadDigest) {
        continue;
      }
      final storedLease = storedManifest.acceptedLeaseRecord.lease!;
      if (storedLease.leaseId != candidateLease.leaseId) continue;
      final currentLease = previous.lease;
      if (currentLease == null ||
          storedLease.recordVersion > currentLease.recordVersion) {
        previous = storedManifest.acceptedLeaseRecord;
      } else if (storedLease.recordVersion == currentLease.recordVersion &&
          storedLease != currentLease) {
        throw StateError('Persisted lease history is inconsistent.');
      }
    }
    return previous;
  }

  static DwOfflinePackageDownloadStartResult _rejected(
    DwOfflineManifestVerificationStatus verificationStatus,
  ) {
    final status = switch (verificationStatus) {
      DwOfflineManifestVerificationStatus.bindingMismatch =>
        DwOfflinePackageDownloadStartStatus.bindingMismatch,
      DwOfflineManifestVerificationStatus.replayRejected =>
        DwOfflinePackageDownloadStartStatus.replayRejected,
      _ => DwOfflinePackageDownloadStartStatus.invalidManifest,
    };
    return DwOfflinePackageDownloadStartResult._(status: status);
  }
}
