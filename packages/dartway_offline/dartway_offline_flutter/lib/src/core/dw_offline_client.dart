import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../access/dw_offline_access_store.dart';
import '../access/dw_offline_lease_policy.dart';
import '../download/background_downloader_transport.dart';
import '../download/dw_background_download_transport.dart';
import '../download/dw_download_asset_publisher.dart';
import '../download/dw_download_job_store.dart';
import '../download/dw_download_scheduler.dart';
import '../download/dw_download_state.dart';
import '../download/dw_offline_package_download_coordinator.dart';
import '../network/connectivity_network_classifier.dart';
import '../network/dw_network_class.dart';
import '../outbox/dw_offline_outbox.dart';
import '../outbox/dw_offline_outbox_synchronizer.dart';
import '../repository/dw_offline_local_reads.dart';
import '../repository/dw_offline_local_writes.dart';
import '../storage/disk_space_plus_source.dart';
import '../storage/dw_offline_asset_store.dart';
import '../storage/dw_offline_database.dart';
import '../storage/dw_offline_media_resolver.dart';
import 'dw_mobile_offline_runtime.dart';
import 'dw_offline_config.dart';
import 'dw_offline_user_scope.dart';

/// Ready-to-use mobile composition of the DartWay offline subsystem.
final class DwOfflineClient implements DwOfflineRuntime {
  DwOfflineClient._({
    required DwMobileOfflineRuntime runtime,
    required DwOfflinePackageDownloadCoordinator packageDownloadCoordinator,
    required DwOfflineAccessStore accessStore,
    required DwDownloadJobStore jobStore,
    required DwDownloadScheduler downloadScheduler,
    required DwOfflineAssetStore assetStore,
    required DwOfflineMediaResolver mediaResolver,
    required DwOfflineOutbox outbox,
    required DwOfflineOutboxSynchronizer outboxSynchronizer,
    required DwOfflineDatabase database,
    required DwNetworkClassSource networkSource,
  }) : _runtime = runtime,
       _packageDownloadCoordinator = packageDownloadCoordinator,
       _accessStore = accessStore,
       _jobStore = jobStore,
       _downloadScheduler = downloadScheduler,
       _assetStore = assetStore,
       _mediaResolver = mediaResolver,
       _outbox = outbox,
       _outboxSynchronizer = outboxSynchronizer,
       _database = database,
       _networkSource = networkSource;

  final DwMobileOfflineRuntime _runtime;
  final DwOfflinePackageDownloadCoordinator _packageDownloadCoordinator;
  final DwOfflineAccessStore _accessStore;
  final DwDownloadJobStore _jobStore;
  final DwDownloadScheduler _downloadScheduler;
  final DwOfflineAssetStore _assetStore;
  final DwOfflineMediaResolver _mediaResolver;
  final DwOfflineOutbox _outbox;
  final DwOfflineOutboxSynchronizer _outboxSynchronizer;
  final DwOfflineDatabase _database;
  final DwNetworkClassSource _networkSource;
  String? _activeUserScopeId;
  int _scopeGeneration = 0;
  final Set<Future<void>> _inFlightPackageDownloads = {};

  static Future<DwOfflineClient> create({
    required Map<String, List<int>> pinnedPublicKeys,
    required String expectedAudience,
    required DwOfflineMutationPlanner mutationPlanner,
    required DwOutboxReplayTransport mutationReplayTransport,
    String databaseName = 'dartway_offline',
    QueryExecutor? databaseExecutor,
    Directory? applicationSupportDirectory,
    DwBackgroundDownloadTransport? downloadTransport,
    DwNetworkClassSource? networkSource,
    DwDiskSpaceSource? diskSpaceSource,
    DwTrustedTimeSource? timeSource,
  }) async {
    final database = DwOfflineDatabase(
      databaseExecutor ?? driftDatabase(name: databaseName),
    );
    final supportDirectory =
        applicationSupportDirectory ?? await getApplicationSupportDirectory();
    final trustedTimeSource = timeSource ?? DwSystemTrustedTimeSource();
    final manifestVerifier = DwOfflineManifestVerifier(
      pinnedPublicKeys: pinnedPublicKeys,
    );
    final accessStore = DwOfflineAccessStore(
      database: database,
      manifestVerifier: manifestVerifier,
      expectedAudience: expectedAudience,
      timeSource: trustedTimeSource,
    );
    final assetStore = DwOfflineAssetStore(
      applicationSupportDirectory: supportDirectory,
      database: database,
    );
    final localReads = DwOfflineLocalReads(
      database: database,
      packageAccessPolicy: accessStore,
    );
    final localWrites = DwOfflineLocalWrites(
      database: database,
      mutationPlanner: mutationPlanner,
    );
    final jobStore = DwDownloadJobStore(database);
    final resolvedNetworkSource =
        networkSource ?? DwConnectivityNetworkClassifier();
    final scheduler = DwDownloadScheduler(
      jobStore: jobStore,
      transport: downloadTransport ?? DwBackgroundDownloaderTransport(),
      networkSource: resolvedNetworkSource,
      diskSpaceSource: diskSpaceSource ?? DwDiskSpacePlusSource(),
      assetPublisher: DwOfflineAssetStorePublisher(assetStore),
      nowEpochMs: () => DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    final runtime = DwMobileOfflineRuntime(
      database: database,
      assetStore: assetStore,
      downloadScheduler: scheduler,
      localReads: localReads,
      localWrites: localWrites,
    );
    final packageDownloadCoordinator = DwOfflinePackageDownloadCoordinator(
      database: database,
      manifestVerifier: manifestVerifier,
      expectedAudience: expectedAudience,
      accessStore: accessStore,
      assetStore: assetStore,
      localReads: localReads,
      jobStore: jobStore,
      scheduler: scheduler,
    );
    final mediaResolver = DwOfflineMediaResolver(
      database: database,
      assetStore: assetStore,
      packageAccessPolicy: accessStore,
    );
    final outbox = DwOfflineOutbox(database);
    final outboxSynchronizer = DwOfflineOutboxSynchronizer(
      outbox: outbox,
      networkSource: resolvedNetworkSource,
      replayTransport: mutationReplayTransport,
    );
    return DwOfflineClient._(
      runtime: runtime,
      packageDownloadCoordinator: packageDownloadCoordinator,
      accessStore: accessStore,
      jobStore: jobStore,
      downloadScheduler: scheduler,
      assetStore: assetStore,
      mediaResolver: mediaResolver,
      outbox: outbox,
      outboxSynchronizer: outboxSynchronizer,
      database: database,
      networkSource: resolvedNetworkSource,
    );
  }

  @override
  Future<void> initialize() async {
    await _runtime.initialize();
    await _outboxSynchronizer.initialize();
  }

  @override
  DwRepoLocalReads? get localReads => _runtime.localReads;

  @override
  DwRepoLocalWrites? get localWrites => _runtime.localWrites;

  @override
  Future<void> activateUserScope(DwOfflineUserScope userScope) async {
    _scopeGeneration += 1;
    _activeUserScopeId = null;
    await _waitForPackageDownloads();
    await _runtime.activateUserScope(userScope);
    try {
      await _outboxSynchronizer.activateUserScope(userScope.userScopeId);
      _activeUserScopeId = userScope.userScopeId;
    } on Object {
      await _runtime.deactivateUserScope(userScope);
      rethrow;
    }
  }

  @override
  Future<void> deactivateUserScope(DwOfflineUserScope userScope) async {
    if (_activeUserScopeId == userScope.userScopeId) {
      _scopeGeneration += 1;
      _activeUserScopeId = null;
    }
    await _waitForPackageDownloads();
    final outboxDeactivation = _outboxSynchronizer.deactivateUserScope(
      userScope.userScopeId,
    );
    await _runtime.deactivateUserScope(userScope);
    await outboxDeactivation;
  }

  @override
  Future<void> purgeUserScope(DwOfflineUserScope userScope) async {
    if (_activeUserScopeId == userScope.userScopeId) {
      _scopeGeneration += 1;
      _activeUserScopeId = null;
    }
    await _waitForPackageDownloads();
    final outboxDeactivation = _outboxSynchronizer.deactivateUserScope(
      userScope.userScopeId,
    );
    await _runtime.purgeUserScope(userScope);
    await outboxDeactivation;
  }

  Future<void> retainScopeQueries(Iterable<String> queryStorageKeys) =>
      _runtime.retainScopeQueries(queryStorageKeys);

  Stream<List<DwRepoMutation>> watchPendingMutations(String userScopeId) {
    _requireActiveScope(userScopeId);
    return _outbox.watchPendingMutations(userScopeId);
  }

  Future<void> synchronizePendingMutations(String userScopeId) {
    _requireActiveScope(userScopeId);
    return _outboxSynchronizer.synchronizeNow();
  }

  Future<DwOfflinePackageDownloadStartResult> startPackageDownload({
    required String userScopeId,
    required String packageId,
    required String signedManifestEnvelopeJson,
    required String repositoryContentRevision,
    required Iterable<DwOfflinePackageSnapshot> snapshots,
    Future<Iterable<DwOfflinePackageSnapshot>> Function()? snapshotLoader,
    int priority = 0,
  }) {
    _requireActiveScope(userScopeId);
    final generation = _scopeGeneration;
    final operation = _packageDownloadCoordinator.start(
      userScopeId: userScopeId,
      packageId: packageId,
      signedManifestEnvelopeJson: signedManifestEnvelopeJson,
      repositoryContentRevision: repositoryContentRevision,
      snapshots: snapshots,
      snapshotLoader: snapshotLoader,
      isScopeActive: () =>
          _activeUserScopeId == userScopeId && _scopeGeneration == generation,
      priority: priority,
    );
    late final Future<void> trackedOperation;
    trackedOperation = operation
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() {
          _inFlightPackageDownloads.remove(trackedOperation);
        });
    _inFlightPackageDownloads.add(trackedOperation);
    return operation;
  }

  Stream<List<DwOfflinePackageDownloadStatus>> watchPackageDownloads(
    String userScopeId,
  ) {
    _requireActiveScope(userScopeId);
    return _jobStore.watchPackageDownloads(userScopeId);
  }

  /// Emits active package ids when a device becomes able to contact the
  /// application server. The application owns the business-specific refresh
  /// request; DartWay owns connectivity and durable package discovery.
  Stream<List<String>> watchPackagesRequiringOnlineValidation(
    String userScopeId,
  ) {
    _requireActiveScope(userScopeId);
    return _watchPackagesRequiringOnlineValidation(userScopeId);
  }

  Future<List<String>> packagesRequiringOnlineValidationNow(
    String userScopeId,
  ) async {
    _requireActiveScope(userScopeId);
    if (await _networkSource.currentNetworkClass() == DwNetworkClass.offline) {
      return const [];
    }
    return _activePackageIds(userScopeId);
  }

  Future<bool> hasNetworkConnection() async =>
      await _networkSource.currentNetworkClass() != DwNetworkClass.offline;

  Future<bool> canReadPackage({
    required String userScopeId,
    required String packageId,
  }) async {
    _requireActiveScope(userScopeId);
    if (packageId.trim().isEmpty || packageId != packageId.trim()) {
      throw ArgumentError.value(packageId, 'packageId');
    }
    final packageRow =
        await (_database.select(_database.dwOfflinePackages)..where(
              (row) =>
                  row.userScopeId.equals(userScopeId) &
                  row.packageId.equals(packageId),
            ))
            .getSingleOrNull();
    final manifestRevision = packageRow?.activeManifestRevision;
    if (manifestRevision == null) return false;
    return _accessStore.canReadPackage(
      userScopeId: userScopeId,
      packageId: packageId,
      manifestRevision: manifestRevision,
    );
  }

  Stream<List<String>> _watchPackagesRequiringOnlineValidation(
    String userScopeId,
  ) async* {
    var wasOnline = false;
    final initialNetworkClass = await _networkSource.currentNetworkClass();
    var isOnline = initialNetworkClass != DwNetworkClass.offline;
    if (isOnline) yield await _activePackageIds(userScopeId);
    wasOnline = isOnline;
    await for (final networkClass in _networkSource.networkClassChanges) {
      _requireActiveScope(userScopeId);
      isOnline = networkClass != DwNetworkClass.offline;
      if (isOnline && !wasOnline) {
        yield await _activePackageIds(userScopeId);
      }
      wasOnline = isOnline;
    }
  }

  Future<List<String>> _activePackageIds(String userScopeId) async {
    final packageRows =
        await (_database.select(_database.dwOfflinePackages)..where(
              (row) =>
                  row.userScopeId.equals(userScopeId) &
                  row.activeManifestRevision.isNotNull(),
            ))
            .get();
    final packageIds =
        packageRows
            .map((packageRow) => packageRow.packageId)
            .toList(growable: false)
          ..sort();
    return packageIds;
  }

  Future<void> pauseDownload({
    required String userScopeId,
    required String jobId,
  }) {
    _requireActiveScope(userScopeId);
    return _downloadScheduler.pauseJob(userScopeId: userScopeId, jobId: jobId);
  }

  Future<void> resumeDownload({
    required String userScopeId,
    required String jobId,
  }) {
    _requireActiveScope(userScopeId);
    return _downloadScheduler.resumeJob(userScopeId: userScopeId, jobId: jobId);
  }

  Future<void> retryFailedDownload({
    required String userScopeId,
    required String jobId,
  }) {
    _requireActiveScope(userScopeId);
    return _downloadScheduler.retryFailedAssets(
      userScopeId: userScopeId,
      jobId: jobId,
    );
  }

  Future<void> grantMeteredDownloadConsent({
    required String userScopeId,
    required String jobId,
    required String manifestDigest,
  }) {
    _requireActiveScope(userScopeId);
    return _downloadScheduler.grantConsent(
      userScopeId: userScopeId,
      jobId: jobId,
      manifestDigest: manifestDigest,
    );
  }

  Future<void> cancelDownload({
    required String userScopeId,
    required String jobId,
  }) {
    _requireActiveScope(userScopeId);
    return _downloadScheduler.cancelJob(userScopeId: userScopeId, jobId: jobId);
  }

  Future<DwOfflineMediaHandle?> openDownloadedMedia({
    required String userScopeId,
    required String downloadUrl,
  }) {
    _requireActiveScope(userScopeId);
    return _mediaResolver.openForDownloadUrl(
      userScopeId: userScopeId,
      downloadUrl: downloadUrl,
    );
  }

  /// Opens an active downloaded asset by its application-defined identifier.
  Future<DwOfflineMediaHandle?> openDownloadedAsset({
    required String userScopeId,
    required String assetId,
  }) {
    _requireActiveScope(userScopeId);
    return _mediaResolver.openForAssetId(
      userScopeId: userScopeId,
      assetId: assetId,
    );
  }

  Future<void> deletePackage({
    required String userScopeId,
    required String packageId,
  }) async {
    _requireActiveScope(userScopeId);
    final statuses = await _jobStore.watchPackageDownloads(userScopeId).first;
    for (final status in statuses.where(
      (status) =>
          status.packageId == packageId &&
          status.state != DwDownloadJobState.completed &&
          status.state != DwDownloadJobState.cancelled &&
          status.state != DwDownloadJobState.failed,
    )) {
      await _downloadScheduler.cancelJob(
        userScopeId: userScopeId,
        jobId: status.jobId,
      );
    }
    await _assetStore.deletePackage(
      userScopeId: userScopeId,
      packageId: packageId,
    );
  }

  @override
  Future<void> dispose() async {
    _scopeGeneration += 1;
    _activeUserScopeId = null;
    await _waitForPackageDownloads();
    await _outboxSynchronizer.dispose();
    await _runtime.dispose();
    _activeUserScopeId = null;
  }

  void _requireActiveScope(String userScopeId) {
    if (_activeUserScopeId != userScopeId) {
      throw StateError('Activate this offline user scope first.');
    }
  }

  Future<void> _waitForPackageDownloads() async {
    while (_inFlightPackageDownloads.isNotEmpty) {
      await Future.wait(List<Future<void>>.of(_inFlightPackageDownloads));
    }
  }
}

/// Wall-clock plus process-monotonic source used by the trusted lease clock.
final class DwSystemTrustedTimeSource implements DwTrustedTimeSource {
  DwSystemTrustedTimeSource() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  DateTime get wallClockUtcNow => DateTime.now().toUtc();

  @override
  Duration get monotonicElapsed => _stopwatch.elapsed;
}
