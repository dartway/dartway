import 'dart:async';
import 'dart:io';

import 'package:dartway_offline_flutter/dartway_offline_flutter.dart';
import 'package:dartway_offline_flutter/src/download/dw_background_download_transport.dart';
import 'package:dartway_offline_flutter/src/network/dw_network_class.dart';
import 'package:dartway_offline_flutter/src/storage/disk_space_plus_source.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/signed_manifest_fixture.dart';

void main() {
  late Directory supportDirectory;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'dw_offline_client_',
    );
  });

  // Nothing to unregister: the client offers its store, it never installs one.
  tearDown(() async {
    await supportDirectory.delete(recursive: true);
  });

  test('standard client composes and owns the mobile runtime', () async {
    final transport = _Transport();
    final client = await DwOfflineClient.create(
      pinnedPublicKeys: const {},
      expectedAudience: 'mobile',
      mutationPlanner: _NoOfflineMutations(),
      mutationReplayTransport: (_) async =>
          const DwOutboxReplayResult.accepted(),
      databaseExecutor: NativeDatabase.memory(),
      applicationSupportDirectory: supportDirectory,
      downloadTransport: transport,
      networkSource: _NetworkSource(),
      diskSpaceSource: _DiskSpaceSource(),
      timeSource: _TimeSource(),
    );

    await client.initialize();
    await client.activateUserScope(DwOfflineUserScope(userScopeId: 'scope-a'));
    final progressKey = DwRepoQueryKey<Object>.getAll(
      modelClassName: 'AccountResourceState',
    ).toStorageKey();
    await client.retainScopeQueries({progressKey});

    expect(client.localReads, isNotNull);
    expect(client.localWrites, isNotNull);
    expect(transport.initializeCalls, 1);
    expect(await client.watchPendingMutations('scope-a').first, isEmpty);
    await client.synchronizePendingMutations('scope-a');
    expect(() => client.watchPendingMutations('scope-b'), throwsStateError);
    expect(
      () => client.synchronizePendingMutations('scope-b'),
      throwsStateError,
    );

    await client.dispose();
    expect(client.localReads, isNull);
    expect(client.localWrites, isNull);
    expect(transport.disposeCalls, 1);
  });

  test('standard client starts a verified package download', () async {
    final fixture = await TestSignedManifestFixture.create();
    final manifest = await fixture.verify(assets: const []);
    final client = await DwOfflineClient.create(
      pinnedPublicKeys: fixture.pinnedPublicKeys,
      expectedAudience: 'mobile',
      mutationPlanner: _NoOfflineMutations(),
      mutationReplayTransport: (_) async =>
          const DwOutboxReplayResult.accepted(),
      databaseExecutor: NativeDatabase.memory(),
      applicationSupportDirectory: supportDirectory,
      downloadTransport: _Transport(),
      networkSource: _NetworkSource(),
      diskSpaceSource: _DiskSpaceSource(),
      timeSource: _TimeSource(),
    );
    await client.initialize();
    await client.activateUserScope(DwOfflineUserScope(userScopeId: 'scope-a'));

    final result = await client.startPackageDownload(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      signedManifestEnvelopeJson: manifest.canonicalEnvelopeJson,
      repositoryContentRevision: manifest.manifest.repositoryContentDigest,
      snapshots: const [],
    );

    expect(result.status, DwOfflinePackageDownloadStartStatus.started);
    expect(result.jobId, isNotEmpty);
    final status = (await client.watchPackageDownloads('scope-a').first).single;
    expect(status.packageId, 'package-a');
    expect(status.state, DwDownloadJobState.completed);
    expect(status.progress, 1);
    expect(
      await client.canReadPackage(
        userScopeId: 'scope-a',
        packageId: 'package-a',
      ),
      isTrue,
    );
    expect(() => client.watchPackageDownloads('scope-b'), throwsStateError);
    expect(
      await client.openDownloadedMedia(
        userScopeId: 'scope-a',
        downloadUrl: 'https://cdn.example.test/not-downloaded.mp4',
      ),
      isNull,
    );
    expect(
      () => client.openDownloadedMedia(
        userScopeId: 'scope-b',
        downloadUrl: 'https://cdn.example.test/not-downloaded.mp4',
      ),
      throwsStateError,
    );

    await client.deletePackage(userScopeId: 'scope-a', packageId: 'package-a');
    expect(
      await client.canReadPackage(
        userScopeId: 'scope-a',
        packageId: 'package-a',
      ),
      isFalse,
    );
    expect(await client.watchPackageDownloads('scope-a').first, isEmpty);
    await client.dispose();
  });

  test('online transition requests validation for active packages', () async {
    final fixture = await TestSignedManifestFixture.create();
    final manifest = await fixture.verify(assets: const []);
    final networkSource = _ControllableNetworkSource();
    final client = await DwOfflineClient.create(
      pinnedPublicKeys: fixture.pinnedPublicKeys,
      expectedAudience: 'mobile',
      mutationPlanner: _NoOfflineMutations(),
      mutationReplayTransport: (_) async =>
          const DwOutboxReplayResult.accepted(),
      databaseExecutor: NativeDatabase.memory(),
      applicationSupportDirectory: supportDirectory,
      downloadTransport: _Transport(),
      networkSource: networkSource,
      diskSpaceSource: _DiskSpaceSource(),
      timeSource: _TimeSource(),
    );
    await client.initialize();
    await client.activateUserScope(DwOfflineUserScope(userScopeId: 'scope-a'));
    await client.startPackageDownload(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      signedManifestEnvelopeJson: manifest.canonicalEnvelopeJson,
      repositoryContentRevision: manifest.manifest.repositoryContentDigest,
      snapshots: const [],
    );
    networkSource.current = DwNetworkClass.offline;
    expect(await client.hasNetworkConnection(), isFalse);
    expect(
      await client.packagesRequiringOnlineValidationNow('scope-a'),
      isEmpty,
    );

    final validationRequest = client
        .watchPackagesRequiringOnlineValidation('scope-a')
        .first;
    await Future<void>.delayed(Duration.zero);
    networkSource.emit(DwNetworkClass.unmetered);
    expect(await client.hasNetworkConnection(), isTrue);

    expect(await validationRequest, ['package-a']);
    expect(await client.packagesRequiringOnlineValidationNow('scope-a'), [
      'package-a',
    ]);
    await client.dispose();
    await networkSource.dispose();
  });

  test('purge invalidates an in-flight package snapshot load', () async {
    final fixture = await TestSignedManifestFixture.create();
    final manifest = await fixture.verify(assets: const []);
    final client = await DwOfflineClient.create(
      pinnedPublicKeys: fixture.pinnedPublicKeys,
      expectedAudience: 'mobile',
      mutationPlanner: _NoOfflineMutations(),
      mutationReplayTransport: (_) async =>
          const DwOutboxReplayResult.accepted(),
      databaseExecutor: NativeDatabase.memory(),
      applicationSupportDirectory: supportDirectory,
      downloadTransport: _Transport(),
      networkSource: _NetworkSource(),
      diskSpaceSource: _DiskSpaceSource(),
      timeSource: _TimeSource(),
    );
    await client.initialize();
    final scopeA = DwOfflineUserScope(userScopeId: 'scope-a');
    await client.activateUserScope(scopeA);
    final loaderEntered = Completer<void>();
    final releaseLoader = Completer<void>();

    final start = client.startPackageDownload(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      signedManifestEnvelopeJson: manifest.canonicalEnvelopeJson,
      repositoryContentRevision: manifest.manifest.repositoryContentDigest,
      snapshots: const [],
      snapshotLoader: () async {
        loaderEntered.complete();
        await releaseLoader.future;
        return const <DwOfflinePackageSnapshot>[];
      },
    );
    await loaderEntered.future;
    final purge = client.purgeUserScope(scopeA);
    await Future<void>.delayed(Duration.zero);
    releaseLoader.complete();

    await expectLater(start, throwsStateError);
    await purge;
    await client.activateUserScope(scopeA);
    expect(await client.watchPackageDownloads('scope-a').first, isEmpty);
    await client.dispose();
  });
}

final class _NoOfflineMutations implements DwOfflineMutationPlanner {
  @override
  Future<DwRepoWritePlan<bool>?>
  prepareDeleteMutation<Model extends SerializableModel>({
    required DwRepoBinding binding,
    required Model model,
    String? apiGroup,
  }) async => null;

  @override
  Future<DwRepoWritePlan<DwModelWrapper>?>
  prepareSaveMutation<Model extends SerializableModel>({
    required DwRepoBinding binding,
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

final class _ControllableNetworkSource implements DwNetworkClassSource {
  final _changes = StreamController<DwNetworkClass>.broadcast();
  DwNetworkClass current = DwNetworkClass.unmetered;

  @override
  Future<DwNetworkClass> currentNetworkClass() async => current;

  @override
  Stream<DwNetworkClass> get networkClassChanges => _changes.stream;

  void emit(DwNetworkClass value) {
    current = value;
    _changes.add(value);
  }

  Future<void> dispose() => _changes.close();
}

final class _DiskSpaceSource implements DwDiskSpaceSource {
  @override
  Future<DwDiskSpaceSnapshot> read() async => DwDiskSpaceSnapshot(
    freeBytes: BigInt.from(1024 * 1024 * 1024),
    totalBytes: BigInt.from(2 * 1024 * 1024 * 1024),
  );
}

final class _TimeSource implements DwTrustedTimeSource {
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  Duration get monotonicElapsed => _stopwatch.elapsed;

  @override
  DateTime get wallClockUtcNow => DateTime.utc(2026);
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
