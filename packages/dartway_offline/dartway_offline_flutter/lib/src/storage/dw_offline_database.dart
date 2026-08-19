import 'dart:convert';
import 'package:drift/drift.dart';

import '../access/dw_offline_lease_policy.dart';

import 'tables/dw_offline_assets.dart';
import 'tables/dw_offline_download_tasks.dart';
import 'tables/dw_offline_jobs.dart';
import 'tables/dw_offline_leases.dart';
import 'tables/dw_offline_manifests.dart';
import 'tables/dw_offline_outbox.dart';
import 'tables/dw_offline_package_assets.dart';
import 'tables/dw_offline_package_snapshots.dart';
import 'tables/dw_offline_packages.dart';
import 'tables/dw_offline_reader_pins.dart';
import 'tables/dw_offline_snapshots.dart';
import 'tables/dw_offline_staging_assets.dart';

part 'dw_offline_database.g.dart';

/// One asset edge installed when a staging manifest becomes active.
class DwOfflineManifestAssetReference {
  const DwOfflineManifestAssetReference({
    required this.assetId,
    required this.assetRevision,
    required this.isRequired,
  });

  final String assetId;
  final String assetRevision;
  final bool isRequired;
}

/// User-scoped crash-safe index for generic offline packages and mutations.
///
/// All timestamps are UTC Unix epoch milliseconds. JSON and envelope columns
/// are opaque strings: this layer persists them without interpreting content.
@DriftDatabase(
  tables: [
    DwOfflinePackages,
    DwOfflineAssets,
    DwOfflinePackageAssets,
    DwOfflineJobs,
    DwOfflineDownloadTasks,
    DwOfflineSnapshots,
    DwOfflineOutbox,
    DwOfflinePackageSnapshots,
    DwOfflineLeases,
    DwOfflineReaderPins,
    DwOfflineManifests,
    DwOfflineStagingAssets,
  ],
)
class DwOfflineDatabase extends _$DwOfflineDatabase {
  DwOfflineDatabase(super.executor);

  static const int currentSchemaVersion = 5;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (schemaMigrator) => schemaMigrator.createAll(),
    onUpgrade: (schemaMigrator, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await schemaMigrator.createTable(dwOfflineReaderPins);
      }
      if (oldVersion < 3) {
        await schemaMigrator.addColumn(
          dwOfflinePackages,
          dwOfflinePackages.activeManifestDigest,
        );
        await schemaMigrator.addColumn(
          dwOfflinePackages,
          dwOfflinePackages.stagingManifestDigest,
        );
        await schemaMigrator.addColumn(
          dwOfflineAssets,
          dwOfflineAssets.downloadUrl,
        );
        await schemaMigrator.addColumn(
          dwOfflineAssets,
          dwOfflineAssets.allowedRedirectHostsJson,
        );
        await schemaMigrator.addColumn(
          dwOfflineAssets,
          dwOfflineAssets.blobName,
        );
        await schemaMigrator.createTable(dwOfflineManifests);
        await schemaMigrator.createTable(dwOfflineStagingAssets);
        if (oldVersion >= 2) {
          await customStatement(
            'ALTER TABLE dw_offline_reader_pins RENAME TO dw_offline_reader_pins_v2',
          );
          await schemaMigrator.createTable(dwOfflineReaderPins);
          await customStatement('''
            INSERT INTO dw_offline_reader_pins
              (user_scope_id, reader_id, asset_id, asset_revision, pinned_at_epoch_ms)
            SELECT user_scope_id, reader_id, asset_id, asset_revision, pinned_at_epoch_ms
            FROM dw_offline_reader_pins_v2
          ''');
          await customStatement('DROP TABLE dw_offline_reader_pins_v2');
        }
      }
      if (oldVersion < 4) {
        await schemaMigrator.addColumn(
          dwOfflineJobs,
          dwOfflineJobs.manifestRevision,
        );
        await schemaMigrator.addColumn(
          dwOfflineJobs,
          dwOfflineJobs.manifestDigest,
        );
        await schemaMigrator.addColumn(dwOfflineJobs, dwOfflineJobs.priority);
        await schemaMigrator.addColumn(
          dwOfflineJobs,
          dwOfflineJobs.packageTotalBytes,
        );
        await schemaMigrator.addColumn(
          dwOfflineJobs,
          dwOfflineJobs.consentedManifestDigest,
        );
        await schemaMigrator.addColumn(
          dwOfflineJobs,
          dwOfflineJobs.nextEligibleAtEpochMs,
        );
        await schemaMigrator.addColumn(
          dwOfflineJobs,
          dwOfflineJobs.pauseReason,
        );
        await schemaMigrator.createTable(dwOfflineDownloadTasks);
      }
      if (oldVersion < 5) {
        await schemaMigrator.createTable(dwOfflinePackageSnapshots);
      }
    },
    beforeOpen: (openingDetails) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Persists one verified manifest and its immutable staging graph atomically.
  Future<void> beginStagingManifest(
    DwVerifiedOfflineManifest verifiedManifest,
  ) {
    final manifest = verifiedManifest.manifest;
    _validateUserScopeId(manifest.userScopeId);
    return transaction(() async {
      final nowEpochMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final existingPackage =
          await (select(dwOfflinePackages)..where(
                (row) =>
                    row.userScopeId.equals(manifest.userScopeId) &
                    row.packageId.equals(manifest.packageId),
              ))
              .getSingleOrNull();
      if (existingPackage == null) {
        await into(dwOfflinePackages).insert(
          DwOfflinePackagesCompanion.insert(
            userScopeId: manifest.userScopeId,
            packageId: manifest.packageId,
            contentIdentity: manifest.contentIdentity,
            stagingManifestRevision: Value(manifest.manifestRevision),
            stagingManifestDigest: Value(verifiedManifest.payloadDigest),
            aggregateStatus: 'staging',
            completedAssetCount: 0,
            totalAssetCount: manifest.assets.length,
            createdAtEpochMs: nowEpochMs,
            updatedAtEpochMs: nowEpochMs,
          ),
        );
      } else {
        if (existingPackage.contentIdentity != manifest.contentIdentity) {
          throw StateError(
            'Package content identity conflicts with persisted state.',
          );
        }
        await (update(dwOfflinePackages)..where(
              (row) =>
                  row.userScopeId.equals(manifest.userScopeId) &
                  row.packageId.equals(manifest.packageId),
            ))
            .write(
              DwOfflinePackagesCompanion(
                stagingManifestRevision: Value(manifest.manifestRevision),
                stagingManifestDigest: Value(verifiedManifest.payloadDigest),
                aggregateStatus: const Value('staging'),
                totalAssetCount: Value(manifest.assets.length),
                updatedAtEpochMs: Value(nowEpochMs),
              ),
            );
      }
      final existingManifest =
          await (select(dwOfflineManifests)..where(
                (row) =>
                    row.userScopeId.equals(manifest.userScopeId) &
                    row.packageId.equals(manifest.packageId) &
                    row.manifestRevision.equals(manifest.manifestRevision),
              ))
              .getSingleOrNull();
      if (existingManifest != null &&
          (existingManifest.payloadDigest != verifiedManifest.payloadDigest ||
              existingManifest.envelopeJson !=
                  verifiedManifest.canonicalEnvelopeJson)) {
        throw StateError('Manifest revision is already bound to other bytes.');
      }
      if (existingManifest == null) {
        await into(dwOfflineManifests).insert(
          DwOfflineManifestsCompanion.insert(
            userScopeId: manifest.userScopeId,
            packageId: manifest.packageId,
            manifestRevision: manifest.manifestRevision,
            payloadDigest: verifiedManifest.payloadDigest,
            envelopeJson: verifiedManifest.canonicalEnvelopeJson,
            payloadBytes: Uint8List.fromList(
              verifiedManifest.canonicalPayloadBytes,
            ),
            createdAtEpochMs: nowEpochMs,
          ),
        );
      }
      await (delete(dwOfflineStagingAssets)..where(
            (row) =>
                row.userScopeId.equals(manifest.userScopeId) &
                row.packageId.equals(manifest.packageId),
          ))
          .go();
      for (final assetDescriptor in manifest.assets) {
        final existingAsset = await _assetRowOrNull(
          userScopeId: manifest.userScopeId,
          assetId: assetDescriptor.assetId,
          assetRevision: assetDescriptor.assetRevision,
        );
        final redirectHostsJson = jsonEncode(
          assetDescriptor.allowedRedirectHosts,
        );
        if (existingAsset == null) {
          await into(dwOfflineAssets).insert(
            DwOfflineAssetsCompanion.insert(
              userScopeId: manifest.userScopeId,
              assetId: assetDescriptor.assetId,
              assetRevision: assetDescriptor.assetRevision,
              expectedSizeBytes: assetDescriptor.expectedSizeBytes,
              checksum: assetDescriptor.sha256Hex,
              mimeType: assetDescriptor.mimeType,
              relativePath: assetDescriptor.logicalRelativePath,
              downloadUrl: Value(assetDescriptor.downloadUrl),
              allowedRedirectHostsJson: Value(redirectHostsJson),
              assetState: 'missing',
              createdAtEpochMs: nowEpochMs,
              updatedAtEpochMs: nowEpochMs,
            ),
          );
        } else if (existingAsset.expectedSizeBytes !=
                assetDescriptor.expectedSizeBytes ||
            existingAsset.checksum != assetDescriptor.sha256Hex ||
            existingAsset.mimeType != assetDescriptor.mimeType ||
            existingAsset.relativePath != assetDescriptor.logicalRelativePath ||
            existingAsset.downloadUrl != assetDescriptor.downloadUrl ||
            existingAsset.allowedRedirectHostsJson != redirectHostsJson) {
          throw StateError(
            'Asset revision metadata conflicts with persisted state.',
          );
        }
        await into(dwOfflineStagingAssets).insert(
          DwOfflineStagingAssetsCompanion.insert(
            userScopeId: manifest.userScopeId,
            packageId: manifest.packageId,
            manifestRevision: manifest.manifestRevision,
            assetId: assetDescriptor.assetId,
            assetRevision: assetDescriptor.assetRevision,
            isRequired: assetDescriptor.isRequired,
            createdAtEpochMs: nowEpochMs,
          ),
        );
      }
    });
  }

  Future<void> markAssetReady({
    required String userScopeId,
    required String assetId,
    required String assetRevision,
    required String blobName,
  }) async {
    final changedRows =
        await (update(dwOfflineAssets)..where(
              (row) =>
                  row.userScopeId.equals(userScopeId) &
                  row.assetId.equals(assetId) &
                  row.assetRevision.equals(assetRevision) &
                  row.isTombstoned.equals(false),
            ))
            .write(
              DwOfflineAssetsCompanion(
                assetState: const Value('ready'),
                blobName: Value(blobName),
                updatedAtEpochMs: Value(
                  DateTime.now().toUtc().millisecondsSinceEpoch,
                ),
              ),
            );
    if (changedRows != 1) throw StateError('Asset is not publishable.');
  }

  /// Activates only the persisted staging graph; required missing assets abort.
  Future<void> activateStagingManifest({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
    required String payloadDigest,
    Future<void> Function()? duringTransaction,
  }) {
    return transaction(() async {
      final packageRow =
          await (select(dwOfflinePackages)..where(
                (row) =>
                    row.userScopeId.equals(userScopeId) &
                    row.packageId.equals(packageId),
              ))
              .getSingleOrNull();
      if (packageRow == null) {
        throw StateError('Staging manifest binding does not match.');
      }
      final isAlreadyActive =
          packageRow.activeManifestRevision == manifestRevision &&
          packageRow.activeManifestDigest == payloadDigest &&
          packageRow.stagingManifestRevision == null &&
          packageRow.stagingManifestDigest == null;
      if (isAlreadyActive) return;
      if (packageRow.stagingManifestRevision != manifestRevision ||
          packageRow.stagingManifestDigest != payloadDigest) {
        throw StateError('Staging manifest binding does not match.');
      }
      final stagingRows =
          await (select(dwOfflineStagingAssets)..where(
                (row) =>
                    row.userScopeId.equals(userScopeId) &
                    row.packageId.equals(packageId) &
                    row.manifestRevision.equals(manifestRevision),
              ))
              .get();
      final readyReferences = <DwOfflineManifestAssetReference>[];
      for (final stagingRow in stagingRows) {
        final assetRow = await _requireAssetRow(
          userScopeId: userScopeId,
          assetId: stagingRow.assetId,
          assetRevision: stagingRow.assetRevision,
        );
        final isReady =
            assetRow.assetState == 'ready' &&
            !assetRow.isTombstoned &&
            assetRow.blobName != null;
        if (stagingRow.isRequired && !isReady) {
          throw StateError('A required staging asset is not ready.');
        }
        if (isReady) {
          readyReferences.add(
            DwOfflineManifestAssetReference(
              assetId: stagingRow.assetId,
              assetRevision: stagingRow.assetRevision,
              isRequired: stagingRow.isRequired,
            ),
          );
        }
      }
      await _replaceActiveEdges(
        userScopeId: userScopeId,
        packageId: packageId,
        assetReferences: readyReferences,
      );
      await duringTransaction?.call();
      await (update(dwOfflinePackages)..where(
            (row) =>
                row.userScopeId.equals(userScopeId) &
                row.packageId.equals(packageId),
          ))
          .write(
            DwOfflinePackagesCompanion(
              activeManifestRevision: Value(manifestRevision),
              activeManifestDigest: Value(payloadDigest),
              stagingManifestRevision: const Value(null),
              stagingManifestDigest: const Value(null),
              aggregateStatus: const Value('ready'),
              completedAssetCount: Value(readyReferences.length),
              updatedAtEpochMs: Value(
                DateTime.now().toUtc().millisecondsSinceEpoch,
              ),
            ),
          );
      await (delete(dwOfflineStagingAssets)..where(
            (row) =>
                row.userScopeId.equals(userScopeId) &
                row.packageId.equals(packageId) &
                row.manifestRevision.equals(manifestRevision),
          ))
          .go();
      await (delete(dwOfflineManifests)..where(
            (row) =>
                row.userScopeId.equals(userScopeId) &
                row.packageId.equals(packageId) &
                row.manifestRevision.equals(manifestRevision).not(),
          ))
          .go();
      // Lease history is an independent replay high-water mark. In particular,
      // a signed revocation must survive deletion of its package and later
      // activation of unrelated manifests in the same user scope.
      await customUpdate(
        "UPDATE dw_offline_assets SET is_tombstoned = 1 "
        "WHERE user_scope_id = ? AND ref_count = 0 AND asset_state = 'ready' "
        'AND NOT EXISTS (SELECT 1 FROM dw_offline_staging_assets staging '
        'WHERE staging.user_scope_id = dw_offline_assets.user_scope_id '
        'AND staging.asset_id = dw_offline_assets.asset_id '
        'AND staging.asset_revision = dw_offline_assets.asset_revision)',
        variables: [Variable<String>(userScopeId)],
        updates: {dwOfflineAssets},
      );
    });
  }

  /// Atomically replaces package edges and their asset ownership counts before
  /// promoting the requested staging manifest.
  ///
  /// Asset references are distinct by asset id and revision. Duplicate inputs
  /// describe one edge and therefore one owner. An empty manifest is valid at
  /// this generic storage layer and atomically clears all previous edges.
  Future<void> activateManifest({
    required String userScopeId,
    required String packageId,
    required String stagingManifestRevision,
    required Iterable<DwOfflineManifestAssetReference> assetReferences,
  }) {
    _validateUserScopeId(userScopeId);
    return transaction(() async {
      final packageRow =
          await (select(dwOfflinePackages)..where(
                (row) =>
                    row.userScopeId.equals(userScopeId) &
                    row.packageId.equals(packageId),
              ))
              .getSingleOrNull();
      if (packageRow == null) {
        throw StateError('Offline package does not exist in the user scope.');
      }
      if (packageRow.stagingManifestRevision != stagingManifestRevision) {
        throw StateError('Staging manifest revision does not match.');
      }

      final distinctAssetReferences =
          <(String, String), DwOfflineManifestAssetReference>{
            for (final assetReference in assetReferences)
              (assetReference.assetId, assetReference.assetRevision):
                  assetReference,
          };
      final oldEdgeRows =
          await (select(dwOfflinePackageAssets)..where(
                (row) =>
                    row.userScopeId.equals(userScopeId) &
                    row.packageId.equals(packageId),
              ))
              .get();
      final oldAssetIdentities = {
        for (final oldEdgeRow in oldEdgeRows)
          (oldEdgeRow.assetId, oldEdgeRow.assetRevision),
      };
      final newAssetIdentities = distinctAssetReferences.keys.toSet();

      for (final assetIdentity in newAssetIdentities) {
        await _requireAssetRow(
          userScopeId: userScopeId,
          assetId: assetIdentity.$1,
          assetRevision: assetIdentity.$2,
        );
      }
      for (final removedAssetIdentity in oldAssetIdentities.difference(
        newAssetIdentities,
      )) {
        await _writeAssetRefCountDelta(
          userScopeId: userScopeId,
          assetId: removedAssetIdentity.$1,
          assetRevision: removedAssetIdentity.$2,
          adjustment: -1,
        );
      }
      for (final addedAssetIdentity in newAssetIdentities.difference(
        oldAssetIdentities,
      )) {
        await _writeAssetRefCountDelta(
          userScopeId: userScopeId,
          assetId: addedAssetIdentity.$1,
          assetRevision: addedAssetIdentity.$2,
          adjustment: 1,
        );
      }

      await (delete(dwOfflinePackageAssets)..where(
            (row) =>
                row.userScopeId.equals(userScopeId) &
                row.packageId.equals(packageId),
          ))
          .go();
      for (final assetReference in distinctAssetReferences.values) {
        await into(dwOfflinePackageAssets).insert(
          DwOfflinePackageAssetsCompanion.insert(
            userScopeId: userScopeId,
            packageId: packageId,
            assetId: assetReference.assetId,
            assetRevision: assetReference.assetRevision,
            isRequired: assetReference.isRequired,
            createdAtEpochMs: DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
        );
      }

      await (update(dwOfflinePackages)..where(
            (row) =>
                row.userScopeId.equals(userScopeId) &
                row.packageId.equals(packageId),
          ))
          .write(
            DwOfflinePackagesCompanion(
              activeManifestRevision: Value(stagingManifestRevision),
              stagingManifestRevision: const Value(null),
              updatedAtEpochMs: Value(
                DateTime.now().toUtc().millisecondsSinceEpoch,
              ),
            ),
          );
    });
  }

  Future<int> incrementAssetRefCount({
    required String userScopeId,
    required String assetId,
    required String assetRevision,
  }) {
    return _adjustAssetRefCount(
      userScopeId: userScopeId,
      assetId: assetId,
      assetRevision: assetRevision,
      adjustment: 1,
    );
  }

  Future<int> decrementAssetRefCount({
    required String userScopeId,
    required String assetId,
    required String assetRevision,
  }) {
    return _adjustAssetRefCount(
      userScopeId: userScopeId,
      assetId: assetId,
      assetRevision: assetRevision,
      adjustment: -1,
    );
  }

  /// Replaces an earlier intent for the same scoped entity with the latest
  /// mutation identity, idempotency key, and opaque envelope while retaining
  /// the entity's original queue position timestamp.
  Future<void> coalesceOutboxIntent(DwOfflineOutboxCompanion latestIntent) {
    final userScopeId = latestIntent.userScopeId.value;
    _validateUserScopeId(userScopeId);
    return transaction(() async {
      final existingIntent =
          await (select(dwOfflineOutbox)..where(
                (row) =>
                    row.userScopeId.equals(userScopeId) &
                    row.entityType.equals(latestIntent.entityType.value) &
                    row.entityId.equals(latestIntent.entityId.value),
              ))
              .getSingleOrNull();
      if (existingIntent == null) {
        final scopeRows = await (select(
          dwOfflineOutbox,
        )..where((row) => row.userScopeId.equals(userScopeId))).get();
        final requestedOrder = latestIntent.createdAtEpochMs.value;
        final latestOrder = scopeRows.fold<int?>(null, (current, row) {
          return current == null || row.createdAtEpochMs > current
              ? row.createdAtEpochMs
              : current;
        });
        final queueOrder = latestOrder == null || requestedOrder > latestOrder
            ? requestedOrder
            : latestOrder + 1;
        await into(
          dwOfflineOutbox,
        ).insert(latestIntent.copyWith(createdAtEpochMs: Value(queueOrder)));
        return;
      }

      await (update(dwOfflineOutbox)..where(
            (row) =>
                row.userScopeId.equals(userScopeId) &
                row.entityType.equals(latestIntent.entityType.value) &
                row.entityId.equals(latestIntent.entityId.value),
          ))
          .write(
            latestIntent.copyWith(
              createdAtEpochMs: Value(existingIntent.createdAtEpochMs),
            ),
          );
    });
  }

  /// Removes all persisted state owned by exactly one validated user scope.
  Future<void> purgeUserScope(String userScopeId) {
    _validateUserScopeId(userScopeId);
    return transaction(() async {
      await _deleteScopeRows(dwOfflineReaderPins, userScopeId);
      await _deleteScopeRows(dwOfflineStagingAssets, userScopeId);
      await _deleteScopeRows(dwOfflinePackageSnapshots, userScopeId);
      await _deleteScopeRows(dwOfflineManifests, userScopeId);
      await _deleteScopeRows(dwOfflinePackageAssets, userScopeId);
      await _deleteScopeRows(dwOfflineJobs, userScopeId);
      await _deleteScopeRows(dwOfflinePackages, userScopeId);
      await _deleteScopeRows(dwOfflineAssets, userScopeId);
      await _deleteScopeRows(dwOfflineSnapshots, userScopeId);
      await _deleteScopeRows(dwOfflineOutbox, userScopeId);
      await _deleteScopeRows(dwOfflineLeases, userScopeId);
    });
  }

  Future<void> deletePackage({
    required String userScopeId,
    required String packageId,
  }) {
    _validateUserScopeId(userScopeId);
    if (packageId.trim().isEmpty || packageId != packageId.trim()) {
      throw ArgumentError.value(packageId, 'packageId');
    }
    return transaction(() async {
      final packageRow =
          await (select(dwOfflinePackages)..where(
                (row) =>
                    row.userScopeId.equals(userScopeId) &
                    row.packageId.equals(packageId),
              ))
              .getSingleOrNull();
      if (packageRow == null) return;
      await (delete(dwOfflinePackageAssets)..where(
            (row) =>
                row.userScopeId.equals(userScopeId) &
                row.packageId.equals(packageId),
          ))
          .go();
      await (delete(dwOfflinePackages)..where(
            (row) =>
                row.userScopeId.equals(userScopeId) &
                row.packageId.equals(packageId),
          ))
          .go();
      await customUpdate(
        'UPDATE dw_offline_assets SET ref_count = '
        '(SELECT COUNT(*) FROM dw_offline_package_assets edges '
        'WHERE edges.user_scope_id = dw_offline_assets.user_scope_id '
        'AND edges.asset_id = dw_offline_assets.asset_id '
        'AND edges.asset_revision = dw_offline_assets.asset_revision) '
        'WHERE user_scope_id = ?',
        variables: [Variable<String>(userScopeId)],
        updates: {dwOfflineAssets},
      );
      await customUpdate(
        "UPDATE dw_offline_assets SET is_tombstoned = 1 "
        "WHERE user_scope_id = ? AND ref_count = 0 "
        'AND NOT EXISTS (SELECT 1 FROM dw_offline_staging_assets staging '
        'WHERE staging.user_scope_id = dw_offline_assets.user_scope_id '
        'AND staging.asset_id = dw_offline_assets.asset_id '
        'AND staging.asset_revision = dw_offline_assets.asset_revision)',
        variables: [Variable<String>(userScopeId)],
        updates: {dwOfflineAssets},
      );
    });
  }

  Future<void> _replaceActiveEdges({
    required String userScopeId,
    required String packageId,
    required Iterable<DwOfflineManifestAssetReference> assetReferences,
  }) async {
    final distinctReferences =
        <(String, String), DwOfflineManifestAssetReference>{
          for (final assetReference in assetReferences)
            (assetReference.assetId, assetReference.assetRevision):
                assetReference,
        };
    await (delete(dwOfflinePackageAssets)..where(
          (row) =>
              row.userScopeId.equals(userScopeId) &
              row.packageId.equals(packageId),
        ))
        .go();
    for (final assetReference in distinctReferences.values) {
      await into(dwOfflinePackageAssets).insert(
        DwOfflinePackageAssetsCompanion.insert(
          userScopeId: userScopeId,
          packageId: packageId,
          assetId: assetReference.assetId,
          assetRevision: assetReference.assetRevision,
          isRequired: assetReference.isRequired,
          createdAtEpochMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        ),
      );
    }
    await customUpdate(
      'UPDATE dw_offline_assets SET ref_count = '
      '(SELECT COUNT(*) FROM dw_offline_package_assets edges '
      'WHERE edges.user_scope_id = dw_offline_assets.user_scope_id '
      'AND edges.asset_id = dw_offline_assets.asset_id '
      'AND edges.asset_revision = dw_offline_assets.asset_revision) '
      'WHERE user_scope_id = ?',
      variables: [Variable<String>(userScopeId)],
      updates: {dwOfflineAssets},
    );
  }

  Future<int> _adjustAssetRefCount({
    required String userScopeId,
    required String assetId,
    required String assetRevision,
    required int adjustment,
  }) {
    _validateUserScopeId(userScopeId);
    return transaction(
      () => _writeAssetRefCountDelta(
        userScopeId: userScopeId,
        assetId: assetId,
        assetRevision: assetRevision,
        adjustment: adjustment,
      ),
    );
  }

  Future<int> _writeAssetRefCountDelta({
    required String userScopeId,
    required String assetId,
    required String assetRevision,
    required int adjustment,
  }) async {
    final assetRow = await _requireAssetRow(
      userScopeId: userScopeId,
      assetId: assetId,
      assetRevision: assetRevision,
    );
    final adjustedRefCount = assetRow.refCount + adjustment;
    if (adjustedRefCount < 0) {
      throw StateError('Offline asset reference count cannot be negative.');
    }

    await (update(dwOfflineAssets)..where(
          (row) =>
              row.userScopeId.equals(userScopeId) &
              row.assetId.equals(assetId) &
              row.assetRevision.equals(assetRevision),
        ))
        .write(DwOfflineAssetsCompanion(refCount: Value(adjustedRefCount)));
    return adjustedRefCount;
  }

  Future<DwOfflineAssetRow> _requireAssetRow({
    required String userScopeId,
    required String assetId,
    required String assetRevision,
  }) async {
    final assetRow =
        await (select(dwOfflineAssets)..where(
              (row) =>
                  row.userScopeId.equals(userScopeId) &
                  row.assetId.equals(assetId) &
                  row.assetRevision.equals(assetRevision),
            ))
            .getSingleOrNull();
    if (assetRow == null) {
      throw StateError('Offline asset does not exist in the user scope.');
    }
    return assetRow;
  }

  Future<DwOfflineAssetRow?> _assetRowOrNull({
    required String userScopeId,
    required String assetId,
    required String assetRevision,
  }) {
    return (select(dwOfflineAssets)..where(
          (row) =>
              row.userScopeId.equals(userScopeId) &
              row.assetId.equals(assetId) &
              row.assetRevision.equals(assetRevision),
        ))
        .getSingleOrNull();
  }

  Future<int> _deleteScopeRows(
    TableInfo<Table, Object?> table,
    String userScopeId,
  ) {
    return customUpdate(
      'DELETE FROM ${table.actualTableName} WHERE user_scope_id = ?',
      variables: [Variable<String>(userScopeId)],
      updates: {table},
    );
  }

  void _validateUserScopeId(String userScopeId) {
    if (userScopeId.trim().isEmpty) {
      throw ArgumentError.value(
        userScopeId,
        'userScopeId',
        'must be a non-empty stable user identity.',
      );
    }
  }
}
