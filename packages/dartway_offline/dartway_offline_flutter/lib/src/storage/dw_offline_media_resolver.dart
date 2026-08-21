import 'package:drift/drift.dart';

import '../repository/dw_offline_local_reads.dart';
import 'dw_offline_asset_store.dart';
import 'dw_offline_database.dart';
import 'dw_offline_reader_handle.dart';

/// Pins a verified local blob while a media player uses its file URI.
final class DwOfflineMediaHandle {
  DwOfflineMediaHandle._({
    required this.fileUri,
    required this.mimeType,
    required DwOfflineReaderHandle readerHandle,
  }) : _readerHandle = readerHandle;

  final Uri fileUri;
  final String mimeType;
  final DwOfflineReaderHandle _readerHandle;

  Future<void> close() => _readerHandle.close();
}

/// Resolves a signed asset only through an active, readable package.
final class DwOfflineMediaResolver {
  const DwOfflineMediaResolver({
    required DwOfflineDatabase database,
    required DwOfflineAssetStore assetStore,
    required DwOfflinePackageAccessPolicy packageAccessPolicy,
  }) : _database = database,
       _assetStore = assetStore,
       _packageAccessPolicy = packageAccessPolicy;

  final DwOfflineDatabase _database;
  final DwOfflineAssetStore _assetStore;
  final DwOfflinePackageAccessPolicy _packageAccessPolicy;

  Future<DwOfflineMediaHandle?> openForDownloadUrl({
    required String userScopeId,
    required String downloadUrl,
  }) => _openMatchingAsset(
    userScopeId: userScopeId,
    assetFilter: _database.dwOfflineAssets.downloadUrl.equals(downloadUrl),
  );

  Future<DwOfflineMediaHandle?> openForAssetId({
    required String userScopeId,
    required String assetId,
  }) => _openMatchingAsset(
    userScopeId: userScopeId,
    assetFilter: _database.dwOfflineAssets.assetId.equals(assetId),
  );

  Future<DwOfflineMediaHandle?> _openMatchingAsset({
    required String userScopeId,
    required Expression<bool> assetFilter,
  }) async {
    final joinedAssets =
        _database.select(_database.dwOfflineAssets).join([
            innerJoin(
              _database.dwOfflinePackageAssets,
              _database.dwOfflinePackageAssets.userScopeId.equalsExp(
                    _database.dwOfflineAssets.userScopeId,
                  ) &
                  _database.dwOfflinePackageAssets.assetId.equalsExp(
                    _database.dwOfflineAssets.assetId,
                  ) &
                  _database.dwOfflinePackageAssets.assetRevision.equalsExp(
                    _database.dwOfflineAssets.assetRevision,
                  ),
            ),
            innerJoin(
              _database.dwOfflinePackages,
              _database.dwOfflinePackages.userScopeId.equalsExp(
                    _database.dwOfflinePackageAssets.userScopeId,
                  ) &
                  _database.dwOfflinePackages.packageId.equalsExp(
                    _database.dwOfflinePackageAssets.packageId,
                  ),
            ),
          ])
          ..where(
            _database.dwOfflineAssets.userScopeId.equals(userScopeId) &
                assetFilter &
                _database.dwOfflineAssets.assetState.equals('ready') &
                _database.dwOfflineAssets.isTombstoned.equals(false) &
                _database.dwOfflinePackages.activeManifestRevision.isNotNull(),
          )
          ..orderBy([
            OrderingTerm.desc(_database.dwOfflinePackages.updatedAtEpochMs),
            OrderingTerm.asc(_database.dwOfflinePackages.packageId),
            OrderingTerm.asc(_database.dwOfflineAssets.assetId),
            OrderingTerm.desc(_database.dwOfflineAssets.assetRevision),
          ]);
    final candidateRows = await joinedAssets.get();
    for (final candidateRow in candidateRows) {
      final packageRow = candidateRow.readTable(_database.dwOfflinePackages);
      final manifestRevision = packageRow.activeManifestRevision;
      if (manifestRevision == null ||
          !await _packageAccessPolicy.canReadPackage(
            userScopeId: userScopeId,
            packageId: packageRow.packageId,
            manifestRevision: manifestRevision,
          )) {
        continue;
      }
      final assetRow = candidateRow.readTable(_database.dwOfflineAssets);
      final readerHandle = await _assetStore.openReader(
        userScopeId: userScopeId,
        assetId: assetRow.assetId,
        assetRevision: assetRow.assetRevision,
      );
      return DwOfflineMediaHandle._(
        fileUri: _assetStore
            .blobFileFor(
              userScopeId: userScopeId,
              assetId: assetRow.assetId,
              assetRevision: assetRow.assetRevision,
            )
            .uri,
        mimeType: assetRow.mimeType,
        readerHandle: readerHandle,
      );
    }
    return null;
  }
}
