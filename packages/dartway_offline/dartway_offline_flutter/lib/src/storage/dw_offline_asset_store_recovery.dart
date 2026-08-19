part of 'dw_offline_asset_store.dart';

extension _DwOfflineAssetStoreRecovery on DwOfflineAssetStore {
  Future<void> _releaseReaderPin({
    required String userScopeId,
    required String readerId,
    required String assetId,
    required String assetRevision,
  }) async {
    await _deleteReaderPin(
      userScopeId: userScopeId,
      readerId: readerId,
      assetId: assetId,
      assetRevision: assetRevision,
    );
    await _collectTombstone(userScopeId, assetId, assetRevision);
  }

  Future<void> _deleteReaderPin({
    required String userScopeId,
    required String readerId,
    required String assetId,
    required String assetRevision,
  }) {
    return (_database.delete(_database.dwOfflineReaderPins)..where(
          (row) =>
              row.userScopeId.equals(userScopeId) &
              row.readerId.equals(readerId) &
              row.assetId.equals(assetId) &
              row.assetRevision.equals(assetRevision),
        ))
        .go();
  }

  Future<void> _collectTombstones(String userScopeId) async {
    final tombstoneRows =
        await (_database.select(_database.dwOfflineAssets)..where(
              (row) =>
                  row.userScopeId.equals(userScopeId) &
                  row.isTombstoned.equals(true),
            ))
            .get();
    for (final tombstoneRow in tombstoneRows) {
      await _collectTombstone(
        userScopeId,
        tombstoneRow.assetId,
        tombstoneRow.assetRevision,
      );
    }
  }

  Future<void> _collectTombstone(
    String userScopeId,
    String assetId,
    String assetRevision,
  ) async {
    final assetRow = await _assetRow(
      userScopeId: userScopeId,
      assetId: assetId,
      assetRevision: assetRevision,
    );
    if (!assetRow.isTombstoned || assetRow.refCount != 0) return;
    final pinCount =
        await (_database.select(_database.dwOfflineReaderPins)..where(
              (row) =>
                  row.userScopeId.equals(userScopeId) &
                  row.assetId.equals(assetId) &
                  row.assetRevision.equals(assetRevision),
            ))
            .get()
            .then((rows) => rows.length);
    if (pinCount != 0) return;
    final blobFile = blobFileFor(
      userScopeId: userScopeId,
      assetId: assetId,
      assetRevision: assetRevision,
    );
    if (await blobFile.exists()) await blobFile.delete();
    await _checkpoint(
      DwOfflineAssetStoreCheckpoint.afterUnlinkBeforeDatabaseFinalize,
    );
    await (_database.delete(_database.dwOfflineAssets)..where(
          (row) =>
              row.userScopeId.equals(userScopeId) &
              row.assetId.equals(assetId) &
              row.assetRevision.equals(assetRevision),
        ))
        .go();
  }

  Future<void> _activateCompleteStaging(String userScopeId) async {
    final packageRows =
        await (_database.select(_database.dwOfflinePackages)..where(
              (row) =>
                  row.userScopeId.equals(userScopeId) &
                  row.stagingManifestRevision.isNotNull(),
            ))
            .get();
    for (final packageRow in packageRows) {
      final durableJob =
          await (_database.select(_database.dwOfflineJobs)..where(
                (row) =>
                    row.userScopeId.equals(userScopeId) &
                    row.packageId.equals(packageRow.packageId) &
                    row.manifestRevision.equals(
                      packageRow.stagingManifestRevision!,
                    ) &
                    row.manifestDigest.equals(
                      packageRow.stagingManifestDigest!,
                    ),
              ))
              .getSingleOrNull();
      if (durableJob == null) continue;
      if (durableJob.jobState != 'running' &&
          durableJob.jobState != 'activating') {
        continue;
      }
      final durableTasks =
          await (_database.select(_database.dwOfflineDownloadTasks)..where(
                (row) =>
                    row.userScopeId.equals(userScopeId) &
                    row.jobId.equals(durableJob.jobId),
              ))
              .get();
      final tasksAreComplete = durableTasks.every(
        (task) =>
            task.taskState == 'completed' ||
            (!task.isRequired && task.taskState == 'failed'),
      );
      if (!tasksAreComplete) continue;
      try {
        await _database.activateStagingManifest(
          userScopeId: userScopeId,
          packageId: packageRow.packageId,
          manifestRevision: packageRow.stagingManifestRevision!,
          payloadDigest: packageRow.stagingManifestDigest!,
        );
      } on StateError {
        // Incomplete durable staging remains retryable and active stays intact.
      }
    }
  }

  Future<void> _recomputeRefCounts(String userScopeId) {
    return _database.customUpdate(
      'UPDATE dw_offline_assets SET ref_count = '
      '(SELECT COUNT(*) FROM dw_offline_package_assets edges '
      'WHERE edges.user_scope_id = dw_offline_assets.user_scope_id '
      'AND edges.asset_id = dw_offline_assets.asset_id '
      'AND edges.asset_revision = dw_offline_assets.asset_revision) '
      'WHERE user_scope_id = ?',
      variables: [Variable<String>(userScopeId)],
      updates: {_database.dwOfflineAssets},
    );
  }

  DwOfflineAssetDescriptor? _descriptorFromRow(DwOfflineAssetRow assetRow) {
    final redirectHostsJson = assetRow.allowedRedirectHostsJson;
    final downloadUrl = assetRow.downloadUrl;
    if (redirectHostsJson == null || downloadUrl == null) return null;
    final Object? decodedHosts;
    try {
      decodedHosts = jsonDecode(redirectHostsJson);
    } on FormatException {
      return null;
    }
    if (decodedHosts is! List<Object?> ||
        decodedHosts.any((host) => host is! String)) {
      return null;
    }
    return DwOfflineAssetDescriptor.internalForStorage(
      assetId: assetRow.assetId,
      assetRevision: assetRow.assetRevision,
      downloadUrl: downloadUrl,
      allowedRedirectHosts: decodedHosts.cast<String>(),
      expectedSizeBytes: assetRow.expectedSizeBytes,
      sha256Hex: assetRow.checksum,
      mimeType: assetRow.mimeType,
      logicalRelativePath: assetRow.relativePath,
      isRequired: false,
    );
  }
}
