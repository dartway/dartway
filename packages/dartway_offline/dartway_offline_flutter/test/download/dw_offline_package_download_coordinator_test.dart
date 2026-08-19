import 'dart:async';
import 'dart:io';

import 'package:dartway_offline_flutter/src/access/dw_offline_access_store.dart';
import 'package:dartway_offline_flutter/src/access/dw_offline_lease_policy.dart';
import 'package:dartway_offline_flutter/src/download/dw_background_download_transport.dart';
import 'package:dartway_offline_flutter/src/download/dw_download_asset_publisher.dart';
import 'package:dartway_offline_flutter/src/download/dw_download_job_store.dart';
import 'package:dartway_offline_flutter/src/download/dw_download_scheduler.dart';
import 'package:dartway_offline_flutter/src/download/dw_offline_package_download_coordinator.dart';
import 'package:dartway_offline_flutter/src/network/dw_network_class.dart';
import 'package:dartway_offline_flutter/src/repository/dw_offline_read_delegate.dart';
import 'package:dartway_offline_flutter/src/storage/disk_space_plus_source.dart';
import 'package:dartway_offline_flutter/src/storage/dw_offline_asset_store.dart';
import 'package:dartway_offline_flutter/src/storage/dw_offline_database.dart';
import 'package:dartway_offline_shared/dartway_offline_shared.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/signed_manifest_fixture.dart';

void main() {
  late DwOfflineDatabase database;
  late Directory supportDirectory;
  late TestSignedManifestFixture fixture;
  late DwOfflinePackageDownloadCoordinator coordinator;
  late _Transport transport;

  setUp(() async {
    database = DwOfflineDatabase(NativeDatabase.memory());
    supportDirectory = await Directory.systemTemp.createTemp(
      'dw_package_download_',
    );
    fixture = await TestSignedManifestFixture.create();
    final verifier = fixture.createVerifier();
    final timeSource = _TimeSource();
    final accessStore = DwOfflineAccessStore(
      database: database,
      manifestVerifier: verifier,
      expectedAudience: 'mobile',
      timeSource: timeSource,
    );
    final assetStore = DwOfflineAssetStore(
      applicationSupportDirectory: supportDirectory,
      database: database,
    );
    final readDelegate = DwOfflineReadDelegate(
      database: database,
      packageAccessPolicy: accessStore,
    );
    await readDelegate.activateUserScope('scope-a');
    final jobStore = DwDownloadJobStore(database);
    transport = _Transport();
    final scheduler = DwDownloadScheduler(
      jobStore: jobStore,
      transport: transport,
      networkSource: _NetworkSource(),
      diskSpaceSource: _DiskSpaceSource(),
      assetPublisher: DwOfflineAssetStorePublisher(assetStore),
      nowEpochMs: () => DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    coordinator = DwOfflinePackageDownloadCoordinator(
      database: database,
      manifestVerifier: verifier,
      expectedAudience: 'mobile',
      accessStore: accessStore,
      assetStore: assetStore,
      readDelegate: readDelegate,
      jobStore: jobStore,
      scheduler: scheduler,
    );
  });

  tearDown(() async {
    await database.close();
    await supportDirectory.delete(recursive: true);
  });

  test('installs exact snapshots and activates a text-only package', () async {
    final verifiedManifest = await fixture.verify(assets: const []);
    final queryKey = DwRepoQueryKey<Object>.getOne(
      modelClassName: 'ResourceRecord',
      apiGroup: 'resources',
      filters: const {'id': 42},
    ).toStorageKey();

    final result = await coordinator.start(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      signedManifestEnvelopeJson: verifiedManifest.canonicalEnvelopeJson,
      repositoryContentRevision:
          verifiedManifest.manifest.repositoryContentDigest,
      snapshots: [
        DwOfflinePackageSnapshot(
          queryStorageKey: queryKey,
          responseJson: const {
            'success': true,
            'data': {'id': 42, 'title': 'Offline resource'},
          },
        ),
      ],
    );

    expect(result.status, DwOfflinePackageDownloadStartStatus.started);
    expect(result.jobId, isNotEmpty);
    final package = await database
        .select(database.dwOfflinePackages)
        .getSingle();
    expect(package.activeManifestRevision, 'manifest-1');
    final snapshot = await database
        .select(database.dwOfflinePackageSnapshots)
        .getSingle();
    expect(snapshot.queryKey, queryKey);
    expect(snapshot.manifestRevision, 'manifest-1');
    expect(
      await database
          .select(database.dwOfflineJobs)
          .getSingle()
          .then((job) => job.jobState),
      'completed',
    );
  });

  test('renews a lease without changing repository content', () async {
    final repositoryContentDigest = DwOfflineRepositoryContentRevision.compute(
      const [],
    );
    final first = await fixture.verify(
      assets: const [],
      manifestRevision: 'manifest-1',
      repositoryContentDigest: repositoryContentDigest,
      leaseRecordVersion: 1,
    );
    final renewed = await fixture.verify(
      assets: const [],
      manifestRevision: 'manifest-2',
      repositoryContentDigest: repositoryContentDigest,
      leaseRecordVersion: 2,
      previousLeaseRecord: first.acceptedLeaseRecord,
    );

    final firstResult = await coordinator.start(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      signedManifestEnvelopeJson: first.canonicalEnvelopeJson,
      repositoryContentRevision: repositoryContentDigest,
      snapshots: const [],
    );
    final renewedResult = await coordinator.start(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      signedManifestEnvelopeJson: renewed.canonicalEnvelopeJson,
      repositoryContentRevision: repositoryContentDigest,
      snapshots: const [],
    );

    expect(firstResult.status, DwOfflinePackageDownloadStartStatus.started);
    expect(renewedResult.status, DwOfflinePackageDownloadStartStatus.started);
    expect(
      (await database.select(database.dwOfflinePackages).getSingle())
          .activeManifestRevision,
      'manifest-2',
    );
  });

  test('rejects repository content outside the signed revision', () async {
    final verifiedManifest = await fixture.verify(assets: const []);

    final result = await coordinator.start(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      signedManifestEnvelopeJson: verifiedManifest.canonicalEnvelopeJson,
      repositoryContentRevision: 'different-repository-content',
      snapshots: const [],
    );

    expect(result.status, DwOfflinePackageDownloadStartStatus.contentMismatch);
    expect(await database.select(database.dwOfflinePackages).get(), isEmpty);
    expect(await database.select(database.dwOfflineJobs).get(), isEmpty);
  });

  test('rejects snapshots outside a signed content digest', () async {
    final signedModel = <String, Object?>{
      'className': 'ResourceRecord',
      'data': <String, Object?>{'id': 42, 'title': 'Signed resource'},
      'isDeleted': false,
    };
    final contentRevision = DwOfflineRepositoryContentRevision.compute([
      signedModel,
    ]);
    final verifiedManifest = await fixture.verify(
      assets: const [],
      manifestRevision: contentRevision,
    );
    final queryKey = DwRepoQueryKey<Object>.getOne(
      modelClassName: 'ResourceRecord',
      apiGroup: 'resources',
      filters: const {'id': 42},
    ).toStorageKey();

    final result = await coordinator.start(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      signedManifestEnvelopeJson: verifiedManifest.canonicalEnvelopeJson,
      repositoryContentRevision: contentRevision,
      snapshots: [
        DwOfflinePackageSnapshot(
          queryStorageKey: queryKey,
          responseJson: const {
            'isOk': true,
            'value': {
              'className': 'ResourceRecord',
              'data': {'id': 42, 'title': 'Tampered resource'},
              'isDeleted': false,
            },
          },
        ),
      ],
    );

    expect(result.status, DwOfflinePackageDownloadStartStatus.contentMismatch);
    expect(await database.select(database.dwOfflinePackages).get(), isEmpty);
    expect(await database.select(database.dwOfflineJobs).get(), isEmpty);
  });

  test('restaging the same manifest replaces its exact snapshot set', () async {
    final verifiedManifest = await fixture.verify(assets: const []);
    final retainedKey = DwRepoQueryKey<Object>.getOne(
      modelClassName: 'ResourceRecord',
      apiGroup: 'resources',
      filters: const {'id': 42},
    ).toStorageKey();
    final removedKey = DwRepoQueryKey<Object>.getOne(
      modelClassName: 'ResourceCollection',
      apiGroup: 'resources',
      filters: const {'id': 7},
    ).toStorageKey();
    DwOfflinePackageSnapshot snapshot(String key, String title) =>
        DwOfflinePackageSnapshot(
          queryStorageKey: key,
          responseJson: {
            'success': true,
            'data': {'title': title},
          },
        );

    await coordinator.start(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      signedManifestEnvelopeJson: verifiedManifest.canonicalEnvelopeJson,
      repositoryContentRevision:
          verifiedManifest.manifest.repositoryContentDigest,
      snapshots: [
        snapshot(retainedKey, 'old resource'),
        snapshot(removedKey, 'old collection'),
      ],
    );
    await coordinator.start(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      signedManifestEnvelopeJson: verifiedManifest.canonicalEnvelopeJson,
      repositoryContentRevision:
          verifiedManifest.manifest.repositoryContentDigest,
      snapshots: [snapshot(retainedKey, 'new resource')],
    );

    final rows = await database
        .select(database.dwOfflinePackageSnapshots)
        .get();
    expect(rows.map((row) => row.queryKey), [retainedKey]);
    expect(rows.single.envelopeJson, contains('new resource'));
  });

  test('rejects a replay older than the persisted signed package', () async {
    final newer = await fixture.verify(
      assets: const [],
      manifestRevision: 'manifest-2',
      leaseId: 'lease-stable',
      leaseRecordVersion: 2,
    );
    final older = await fixture.verify(
      assets: const [],
      manifestRevision: 'manifest-1',
      leaseId: 'lease-stable',
      leaseRecordVersion: 1,
    );
    await coordinator.start(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      signedManifestEnvelopeJson: newer.canonicalEnvelopeJson,
      repositoryContentRevision: newer.manifest.repositoryContentDigest,
      snapshots: const [],
    );

    final result = await coordinator.start(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      signedManifestEnvelopeJson: older.canonicalEnvelopeJson,
      repositoryContentRevision: older.manifest.repositoryContentDigest,
      snapshots: const [],
    );

    expect(result.status, DwOfflinePackageDownloadStartStatus.replayRejected);
    final package = await database
        .select(database.dwOfflinePackages)
        .getSingle();
    expect(package.activeManifestRevision, 'manifest-2');
  });

  test(
    'successful access refresh removes inactive package revisions',
    () async {
      final queryKey = DwRepoQueryKey<Object>.getOne(
        modelClassName: 'ResourceRecord',
        apiGroup: 'resources',
        filters: const {'id': 42},
      ).toStorageKey();
      final first = await fixture.verify(
        assets: const [],
        manifestRevision: 'manifest-1',
        leaseId: 'lease-stable',
        leaseRecordVersion: 1,
      );
      final refreshed = await fixture.verify(
        assets: const [],
        manifestRevision: 'manifest-2',
        leaseId: 'lease-stable',
        leaseRecordVersion: 2,
      );
      DwOfflinePackageSnapshot snapshot(String value) =>
          DwOfflinePackageSnapshot(
            queryStorageKey: queryKey,
            responseJson: {
              'success': true,
              'data': {'title': value},
            },
          );

      await coordinator.start(
        userScopeId: 'scope-a',
        packageId: 'package-a',
        signedManifestEnvelopeJson: first.canonicalEnvelopeJson,
        repositoryContentRevision: first.manifest.repositoryContentDigest,
        snapshots: [snapshot('first')],
      );
      await coordinator.start(
        userScopeId: 'scope-a',
        packageId: 'package-a',
        signedManifestEnvelopeJson: refreshed.canonicalEnvelopeJson,
        repositoryContentRevision: refreshed.manifest.repositoryContentDigest,
        snapshots: [snapshot('refreshed')],
      );

      final manifests = await database
          .select(database.dwOfflineManifests)
          .get();
      final snapshots = await database
          .select(database.dwOfflinePackageSnapshots)
          .get();
      expect(manifests.map((row) => row.manifestRevision), ['manifest-2']);
      expect(snapshots.map((row) => row.manifestRevision), ['manifest-2']);
    },
  );

  test('signed revocation removes an already downloaded package', () async {
    final active = await fixture.verify(
      assets: const [],
      manifestRevision: 'manifest-1',
      leaseId: 'lease-stable',
      leaseRecordVersion: 1,
    );
    final revoked = await fixture.verify(
      assets: const [],
      manifestRevision: 'manifest-2',
      leaseId: 'lease-stable',
      leaseRecordVersion: 2,
      leaseIsRevoked: true,
    );
    await coordinator.start(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      signedManifestEnvelopeJson: active.canonicalEnvelopeJson,
      repositoryContentRevision: active.manifest.repositoryContentDigest,
      snapshots: const [],
    );

    var snapshotsLoaded = false;
    final result = await coordinator.start(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      signedManifestEnvelopeJson: revoked.canonicalEnvelopeJson,
      repositoryContentRevision: revoked.manifest.repositoryContentDigest,
      snapshots: const [],
      snapshotLoader: () async {
        snapshotsLoaded = true;
        throw StateError('Revoked packages must not require content models.');
      },
    );

    expect(result.status, DwOfflinePackageDownloadStartStatus.accessRevoked);
    expect(snapshotsLoaded, isFalse);
    expect(await database.select(database.dwOfflinePackages).get(), isEmpty);
    expect(await database.select(database.dwOfflineJobs).get(), isEmpty);
  });

  test(
    'signed revocation cancels native work and remains a replay high-water mark',
    () async {
      final active = await fixture.verify(
        manifestRevision: 'manifest-1',
        leaseId: 'lease-stable',
        leaseRecordVersion: 1,
      );
      final revoked = await fixture.verify(
        assets: const [],
        manifestRevision: 'manifest-2',
        leaseId: 'lease-stable',
        leaseRecordVersion: 2,
        leaseIsRevoked: true,
      );
      await coordinator.start(
        userScopeId: 'scope-a',
        packageId: 'package-a',
        signedManifestEnvelopeJson: active.canonicalEnvelopeJson,
        repositoryContentRevision: active.manifest.repositoryContentDigest,
        snapshots: const [],
      );
      final nativeTaskId = transport.enqueuedTaskIds.single;

      final revocationResult = await coordinator.start(
        userScopeId: 'scope-a',
        packageId: 'package-a',
        signedManifestEnvelopeJson: revoked.canonicalEnvelopeJson,
        repositoryContentRevision: revoked.manifest.repositoryContentDigest,
        snapshots: const [],
      );
      final otherPackage = await fixture.verify(
        packageId: 'package-b',
        manifestRevision: 'manifest-b',
        assets: const [],
      );
      await coordinator.start(
        userScopeId: 'scope-a',
        packageId: 'package-b',
        signedManifestEnvelopeJson: otherPackage.canonicalEnvelopeJson,
        repositoryContentRevision:
            otherPackage.manifest.repositoryContentDigest,
        snapshots: const [],
      );
      final replayResult = await coordinator.start(
        userScopeId: 'scope-a',
        packageId: 'package-a',
        signedManifestEnvelopeJson: active.canonicalEnvelopeJson,
        repositoryContentRevision: active.manifest.repositoryContentDigest,
        snapshots: const [],
      );

      expect(
        revocationResult.status,
        DwOfflinePackageDownloadStartStatus.accessRevoked,
      );
      expect(transport.cancelledTaskIds, contains(nativeTaskId));
      expect(
        replayResult.status,
        DwOfflinePackageDownloadStartStatus.replayRejected,
      );
      final packages = await database.select(database.dwOfflinePackages).get();
      expect(packages.where((row) => row.packageId == 'package-a'), isEmpty);
      expect(
        packages.where((row) => row.packageId == 'package-b'),
        hasLength(1),
      );
      final jobs = await database.select(database.dwOfflineJobs).get();
      expect(jobs.where((row) => row.packageId == 'package-a'), isEmpty);
      expect(
        jobs.where((row) => row.packageId == 'package-b').single.jobState,
        'completed',
      );
      expect(await database.select(database.dwOfflineLeases).get(), isNotEmpty);
    },
  );

  test(
    'replacing a package cancels its previous native download task',
    () async {
      final first = await fixture.verify(
        manifestRevision: 'manifest-1',
        leaseId: 'lease-stable',
        leaseRecordVersion: 1,
      );
      final replacement = await fixture.verify(
        manifestRevision: 'manifest-2',
        leaseId: 'lease-stable',
        leaseRecordVersion: 2,
      );

      final firstResult = await coordinator.start(
        userScopeId: 'scope-a',
        packageId: 'package-a',
        signedManifestEnvelopeJson: first.canonicalEnvelopeJson,
        repositoryContentRevision: first.manifest.repositoryContentDigest,
        snapshots: const [],
      );
      final firstNativeTaskId = transport.enqueuedTaskIds.single;

      final replacementResult = await coordinator.start(
        userScopeId: 'scope-a',
        packageId: 'package-a',
        signedManifestEnvelopeJson: replacement.canonicalEnvelopeJson,
        repositoryContentRevision: replacement.manifest.repositoryContentDigest,
        snapshots: const [],
      );

      expect(firstResult.jobId, isNot(replacementResult.jobId));
      expect(transport.cancelledTaskIds, contains(firstNativeTaskId));
      expect(transport.enqueuedTaskIds, hasLength(2));
    },
  );
}

final class _TimeSource implements DwTrustedTimeSource {
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  Duration get monotonicElapsed => _stopwatch.elapsed;

  @override
  DateTime get wallClockUtcNow => DateTime.utc(2026);
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
  final StreamController<DwBackgroundDownloadUpdate> _updates =
      StreamController.broadcast();
  final List<String> enqueuedTaskIds = [];
  final List<String> cancelledTaskIds = [];

  @override
  Stream<DwBackgroundDownloadUpdate> get updates => _updates.stream;

  @override
  Future<Set<String>> activeTaskIds() async => const {};

  @override
  Future<bool> cancel(String taskId) async {
    cancelledTaskIds.add(taskId);
    return true;
  }

  @override
  Future<void> dispose() => _updates.close();

  @override
  Future<bool> enqueue(DwBackgroundDownloadRequest request) async {
    enqueuedTaskIds.add(request.taskId);
    return true;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> pause(String taskId) async => true;

  @override
  Future<bool> resume(String taskId) async => true;
}
