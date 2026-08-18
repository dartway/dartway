import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart';
import 'package:path/path.dart' as path;

import '../access/dw_offline_lease_policy.dart';
import 'dw_offline_database.dart';
import 'dw_offline_reader_handle.dart';

part 'dw_offline_asset_store_filesystem.dart';
part 'dw_offline_asset_store_recovery.dart';

enum DwOfflineAssetStoreCheckpoint {
  beforeRename,
  afterRenameBeforeReadyCommit,
  afterReadyBeforeActivation,
  beforeActivation,
  duringActivation,
  afterActivation,
  afterUnlinkBeforeDatabaseFinalize,
}

final class DwOfflineSimulatedProcessInterruption implements Exception {
  const DwOfflineSimulatedProcessInterruption(this.checkpoint);

  final DwOfflineAssetStoreCheckpoint checkpoint;
}

final class DwOfflineAssetIntegrityException implements Exception {
  const DwOfflineAssetIntegrityException(this.message);

  final String message;

  @override
  String toString() => 'DwOfflineAssetIntegrityException: $message';
}

typedef DwOfflineAssetStoreFaultInjector =
    Future<void> Function(DwOfflineAssetStoreCheckpoint checkpoint);

/// User-scoped, streaming, crash-reconcilable blob publication and reading.
final class DwOfflineAssetStore {
  DwOfflineAssetStore({
    required Directory applicationSupportDirectory,
    required DwOfflineDatabase database,
    DwOfflineAssetStoreFaultInjector? faultInjector,
  }) : _applicationSupportDirectory = applicationSupportDirectory,
       _database = database,
       _faultInjector = faultInjector;

  final Directory _applicationSupportDirectory;
  final DwOfflineDatabase _database;
  final DwOfflineAssetStoreFaultInjector? _faultInjector;
  final Map<String, Future<void>> _scopeQueues = {};
  final Map<String, Set<DwOfflineReaderHandle>> _openReaders = {};
  final Set<String> _blockedScopes = {};

  Directory scopeStagingDirectory(String userScopeId) =>
      Directory(path.join(_scopeRoot(userScopeId).path, 'staging'));

  File blobFileFor({
    required String userScopeId,
    required String assetId,
    required String assetRevision,
  }) {
    return File(
      path.join(
        _scopeRoot(userScopeId).path,
        'blobs',
        _blobName(assetId, assetRevision),
      ),
    );
  }

  Future<void> beginStagingManifest(
    DwVerifiedOfflineManifest verifiedManifest,
  ) {
    return _serializeAvailable(verifiedManifest.manifest.userScopeId, () async {
      await _prepareScopeDirectories(verifiedManifest.manifest.userScopeId);
      await _database.beginStagingManifest(verifiedManifest);
    });
  }

  Future<void> publishAsset({
    required String userScopeId,
    required DwOfflineAssetDescriptor assetDescriptor,
    required Stream<List<int>> bytes,
  }) {
    return _serializeAvailable(userScopeId, () async {
      await _prepareScopeDirectories(userScopeId);
      await _requireMatchingAssetMetadata(userScopeId, assetDescriptor);
      final destinationFile = blobFileFor(
        userScopeId: userScopeId,
        assetId: assetDescriptor.assetId,
        assetRevision: assetDescriptor.assetRevision,
      );
      if (await _entityExists(destinationFile.path)) {
        await _requireRegularFile(destinationFile.path);
        if (!await _fileMatches(destinationFile, assetDescriptor)) {
          throw const DwOfflineAssetIntegrityException(
            'Existing blob destination is corrupt.',
          );
        }
        await _database.markAssetReady(
          userScopeId: userScopeId,
          assetId: assetDescriptor.assetId,
          assetRevision: assetDescriptor.assetRevision,
          blobName: path.basename(destinationFile.path),
        );
        return;
      }

      final partialFile = File(
        path.join(
          scopeStagingDirectory(userScopeId).path,
          '${_randomToken()}.partial',
        ),
      );
      RandomAccessFile? partialWriter;
      var renamed = false;
      var preserveCrashResidue = false;
      try {
        await _requireNoLink(partialFile.path);
        await partialFile.create(exclusive: true);
        partialWriter = await partialFile.open(mode: FileMode.write);
        final digestReceiver = _AssetDigestReceiver();
        final digestWriter = crypto.sha256.startChunkedConversion(
          digestReceiver,
        );
        var receivedBytes = 0;
        await for (final byteChunk in bytes) {
          receivedBytes += byteChunk.length;
          if (receivedBytes > assetDescriptor.expectedSizeBytes) {
            throw const DwOfflineAssetIntegrityException(
              'Asset stream exceeds the signed size.',
            );
          }
          digestWriter.add(byteChunk);
          await partialWriter.writeFrom(byteChunk);
        }
        digestWriter.close();
        if (receivedBytes != assetDescriptor.expectedSizeBytes) {
          throw const DwOfflineAssetIntegrityException(
            'Asset stream does not match the signed size.',
          );
        }
        if (digestReceiver.digest.toString() != assetDescriptor.sha256Hex) {
          throw const DwOfflineAssetIntegrityException(
            'Asset stream does not match the signed SHA-256.',
          );
        }
        await partialWriter.flush();
        await partialWriter.close();
        partialWriter = null;
        await _checkpoint(DwOfflineAssetStoreCheckpoint.beforeRename);
        await _requireNoLink(destinationFile.path);
        if (await destinationFile.exists()) {
          throw const DwOfflineAssetIntegrityException(
            'Blob destination appeared during publication.',
          );
        }
        await partialFile.rename(destinationFile.path);
        renamed = true;
        await _checkpoint(
          DwOfflineAssetStoreCheckpoint.afterRenameBeforeReadyCommit,
        );
        await _database.markAssetReady(
          userScopeId: userScopeId,
          assetId: assetDescriptor.assetId,
          assetRevision: assetDescriptor.assetRevision,
          blobName: path.basename(destinationFile.path),
        );
        await _checkpoint(
          DwOfflineAssetStoreCheckpoint.afterReadyBeforeActivation,
        );
      } on DwOfflineSimulatedProcessInterruption {
        preserveCrashResidue = true;
        rethrow;
      } finally {
        await partialWriter?.close();
        if (!renamed && !preserveCrashResidue && await partialFile.exists()) {
          await partialFile.delete();
        }
      }
    });
  }

  Future<bool> isAssetReady({
    required String userScopeId,
    required DwOfflineAssetDescriptor assetDescriptor,
  }) {
    return _serializeAvailable(userScopeId, () async {
      try {
        await _requireMatchingAssetMetadata(userScopeId, assetDescriptor);
        final assetRow = await _assetRow(
          userScopeId: userScopeId,
          assetId: assetDescriptor.assetId,
          assetRevision: assetDescriptor.assetRevision,
        );
        final blobName = assetRow.blobName;
        if (assetRow.assetState != 'ready' || blobName == null) return false;
        final blobFile = blobFileFor(
          userScopeId: userScopeId,
          assetId: assetDescriptor.assetId,
          assetRevision: assetDescriptor.assetRevision,
        );
        if (path.basename(blobFile.path) != blobName) return false;
        await _requireRegularFile(blobFile.path);
        return _fileMatches(blobFile, assetDescriptor);
      } on Object {
        return false;
      }
    });
  }

  Future<void> activateStagingManifest({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
    required String payloadDigest,
  }) {
    return _serializeAvailable(userScopeId, () async {
      await _checkpoint(DwOfflineAssetStoreCheckpoint.beforeActivation);
      await _database.activateStagingManifest(
        userScopeId: userScopeId,
        packageId: packageId,
        manifestRevision: manifestRevision,
        payloadDigest: payloadDigest,
        duringTransaction: () =>
            _checkpoint(DwOfflineAssetStoreCheckpoint.duringActivation),
      );
      await _checkpoint(DwOfflineAssetStoreCheckpoint.afterActivation);
      await _collectTombstones(userScopeId);
    });
  }

  Future<DwOfflineReaderHandle> openReader({
    required String userScopeId,
    required String assetId,
    required String assetRevision,
  }) {
    return _serializeAvailable(userScopeId, () async {
      final assetRow = await _assetRow(
        userScopeId: userScopeId,
        assetId: assetId,
        assetRevision: assetRevision,
      );
      if (assetRow.assetState != 'ready' ||
          assetRow.isTombstoned ||
          assetRow.blobName == null) {
        throw StateError('Offline asset is not readable.');
      }
      final readerId = _randomToken();
      await _database
          .into(_database.dwOfflineReaderPins)
          .insert(
            DwOfflineReaderPinsCompanion.insert(
              userScopeId: userScopeId,
              readerId: readerId,
              assetId: assetId,
              assetRevision: assetRevision,
              pinnedAtEpochMs: DateTime.now().toUtc().millisecondsSinceEpoch,
            ),
          );
      try {
        final blobFile = File(
          path.join(_scopeRoot(userScopeId).path, 'blobs', assetRow.blobName!),
        );
        await _requireRegularFile(blobFile.path);
        final randomAccessFile = await blobFile.open(mode: FileMode.read);
        late final DwOfflineReaderHandle readerHandle;
        readerHandle = DwOfflineReaderHandle.internal(
          randomAccessFile: randomAccessFile,
          releasePin: () async {
            await _releaseReaderPin(
              userScopeId: userScopeId,
              readerId: readerId,
              assetId: assetId,
              assetRevision: assetRevision,
            );
            _openReaders[userScopeId]?.remove(readerHandle);
          },
        );
        _openReaders.putIfAbsent(userScopeId, () => {}).add(readerHandle);
        return readerHandle;
      } catch (_) {
        await _deleteReaderPin(
          userScopeId: userScopeId,
          readerId: readerId,
          assetId: assetId,
          assetRevision: assetRevision,
        );
        await _markAssetRepairNeeded(userScopeId, assetId, assetRevision);
        rethrow;
      }
    });
  }

  Future<void> tombstoneAsset({
    required String userScopeId,
    required String assetId,
    required String assetRevision,
  }) {
    return _serializeAvailable(userScopeId, () async {
      final assetRow = await _assetRow(
        userScopeId: userScopeId,
        assetId: assetId,
        assetRevision: assetRevision,
      );
      if (assetRow.refCount != 0) {
        throw StateError('An owned asset cannot be tombstoned.');
      }
      await (_database.update(_database.dwOfflineAssets)..where(
            (row) =>
                row.userScopeId.equals(userScopeId) &
                row.assetId.equals(assetId) &
                row.assetRevision.equals(assetRevision),
          ))
          .write(const DwOfflineAssetsCompanion(isTombstoned: Value(true)));
      await _collectTombstone(userScopeId, assetId, assetRevision);
    });
  }

  Future<void> reconcileUserScope(String userScopeId) {
    return _serializeAvailable(userScopeId, () async {
      await _prepareScopeDirectories(userScopeId);
      final hasLiveReaders = _openReaders[userScopeId]?.isNotEmpty ?? false;
      if (!hasLiveReaders) {
        await (_database.delete(
          _database.dwOfflineReaderPins,
        )..where((row) => row.userScopeId.equals(userScopeId))).go();
      }
      final stagingDirectory = scopeStagingDirectory(userScopeId);
      await for (final stagingEntity in stagingDirectory.list()) {
        if (stagingEntity is File &&
            path.basename(stagingEntity.path).endsWith('.partial')) {
          await stagingEntity.delete();
        }
      }
      final assetRows = await (_database.select(
        _database.dwOfflineAssets,
      )..where((row) => row.userScopeId.equals(userScopeId))).get();
      final ownedBlobNames = <String>{};
      for (final assetRow in assetRows) {
        final expectedBlob = blobFileFor(
          userScopeId: userScopeId,
          assetId: assetRow.assetId,
          assetRevision: assetRow.assetRevision,
        );
        if (await _entityExists(expectedBlob.path)) {
          ownedBlobNames.add(path.basename(expectedBlob.path));
          final descriptor = _descriptorFromRow(assetRow);
          if (await _isRegularFile(expectedBlob.path) &&
              descriptor != null &&
              await _fileMatches(expectedBlob, descriptor)) {
            if (!assetRow.isTombstoned) {
              await _database.markAssetReady(
                userScopeId: userScopeId,
                assetId: assetRow.assetId,
                assetRevision: assetRow.assetRevision,
                blobName: path.basename(expectedBlob.path),
              );
            }
          } else {
            await _markAssetRepairNeeded(
              userScopeId,
              assetRow.assetId,
              assetRow.assetRevision,
            );
            if (!hasLiveReaders) {
              await _deleteInvalidBlob(expectedBlob.path);
            }
          }
        } else if (assetRow.assetState == 'ready') {
          await _markAssetRepairNeeded(
            userScopeId,
            assetRow.assetId,
            assetRow.assetRevision,
          );
        }
      }
      final blobDirectory = Directory(
        path.join(_scopeRoot(userScopeId).path, 'blobs'),
      );
      await for (final blobEntity in blobDirectory.list()) {
        if (blobEntity is File &&
            !ownedBlobNames.contains(path.basename(blobEntity.path))) {
          await blobEntity.delete();
        }
      }
      await _recomputeRefCounts(userScopeId);
      await _collectTombstones(userScopeId);
      await _activateCompleteStaging(userScopeId);
      await _collectTombstones(userScopeId);
    });
  }

  Future<void> deletePackage({
    required String userScopeId,
    required String packageId,
  }) {
    return _serializeAvailable(userScopeId, () async {
      await _database.deletePackage(
        userScopeId: userScopeId,
        packageId: packageId,
      );
      await _collectTombstones(userScopeId);
    });
  }

  Future<void> purgeUserScope(String userScopeId) {
    if (!_blockedScopes.add(userScopeId)) {
      return Future<void>.error(
        StateError('Offline user scope is already being purged.'),
      );
    }
    return _serialize(userScopeId, () async {
      try {
        final readerHandles = List<DwOfflineReaderHandle>.from(
          _openReaders[userScopeId] ?? const {},
        );
        for (final readerHandle in readerHandles) {
          await readerHandle.close();
        }
        await _database.purgeUserScope(userScopeId);
        final scopeRoot = _scopeRoot(userScopeId);
        if (await scopeRoot.exists()) await scopeRoot.delete(recursive: true);
      } finally {
        _openReaders.remove(userScopeId);
        _blockedScopes.remove(userScopeId);
      }
    });
  }

  Future<void> _requireMatchingAssetMetadata(
    String userScopeId,
    DwOfflineAssetDescriptor assetDescriptor,
  ) async {
    final assetRow = await _assetRow(
      userScopeId: userScopeId,
      assetId: assetDescriptor.assetId,
      assetRevision: assetDescriptor.assetRevision,
    );
    if (assetRow.expectedSizeBytes != assetDescriptor.expectedSizeBytes ||
        assetRow.checksum != assetDescriptor.sha256Hex ||
        assetRow.mimeType != assetDescriptor.mimeType ||
        assetRow.relativePath != assetDescriptor.logicalRelativePath ||
        assetRow.downloadUrl != assetDescriptor.downloadUrl ||
        assetRow.allowedRedirectHostsJson !=
            jsonEncode(assetDescriptor.allowedRedirectHosts)) {
      throw StateError('Asset descriptor does not match durable metadata.');
    }
  }

  Future<DwOfflineAssetRow> _assetRow({
    required String userScopeId,
    required String assetId,
    required String assetRevision,
  }) async {
    final assetRow =
        await (_database.select(_database.dwOfflineAssets)..where(
              (row) =>
                  row.userScopeId.equals(userScopeId) &
                  row.assetId.equals(assetId) &
                  row.assetRevision.equals(assetRevision),
            ))
            .getSingleOrNull();
    if (assetRow == null) throw StateError('Offline asset does not exist.');
    return assetRow;
  }

  Future<void> _markAssetRepairNeeded(
    String userScopeId,
    String assetId,
    String assetRevision,
  ) {
    return (_database.update(_database.dwOfflineAssets)..where(
          (row) =>
              row.userScopeId.equals(userScopeId) &
              row.assetId.equals(assetId) &
              row.assetRevision.equals(assetRevision),
        ))
        .write(
          const DwOfflineAssetsCompanion(
            assetState: Value('repairNeeded'),
            blobName: Value(null),
          ),
        );
  }

  String _randomToken() {
    final randomSource = Random.secure();
    return List<int>.generate(
      24,
      (_) => randomSource.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<T> _serialize<T>(String userScopeId, Future<T> Function() operation) {
    final precedingOperation =
        _scopeQueues[userScopeId] ?? Future<void>.value();
    final queuedOperation = precedingOperation.then((_) => operation());
    final queueTail = queuedOperation.then<void>((_) {}, onError: (_, _) {});
    _scopeQueues[userScopeId] = queueTail;
    unawaited(
      queueTail.then((_) {
        if (identical(_scopeQueues[userScopeId], queueTail)) {
          _scopeQueues.remove(userScopeId);
        }
      }),
    );
    return queuedOperation;
  }

  Future<T> _serializeAvailable<T>(
    String userScopeId,
    Future<T> Function() operation,
  ) {
    if (_blockedScopes.contains(userScopeId)) {
      return Future<T>.error(StateError('Offline user scope is being purged.'));
    }
    return _serialize(userScopeId, operation);
  }

  Future<void> _checkpoint(DwOfflineAssetStoreCheckpoint checkpoint) async {
    await _faultInjector?.call(checkpoint);
  }
}
