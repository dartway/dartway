import 'dart:io';

import '../access/dw_offline_lease_policy.dart';
import '../storage/dw_offline_asset_store.dart';

abstract interface class DwDownloadAssetPublisher {
  Future<void> reconcileUserScope(String userScopeId);

  Future<void> publish({
    required String userScopeId,
    required DwOfflineAssetDescriptor assetDescriptor,
    required String temporaryFilePath,
  });

  Future<void> discard(String temporaryFilePath);

  Future<void> activate({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
    required String manifestDigest,
  });
}

final class DwOfflineAssetStorePublisher implements DwDownloadAssetPublisher {
  const DwOfflineAssetStorePublisher(this._assetStore);

  final DwOfflineAssetStore _assetStore;

  @override
  Future<void> reconcileUserScope(String userScopeId) {
    return _assetStore.reconcileUserScope(userScopeId);
  }

  @override
  Future<void> publish({
    required String userScopeId,
    required DwOfflineAssetDescriptor assetDescriptor,
    required String temporaryFilePath,
  }) async {
    final temporaryFile = File(temporaryFilePath);
    if (!await temporaryFile.exists()) {
      if (await _assetStore.isAssetReady(
        userScopeId: userScopeId,
        assetDescriptor: assetDescriptor,
      )) {
        return;
      }
      throw StateError('Completed native download file is missing.');
    }
    await _assetStore.publishAsset(
      userScopeId: userScopeId,
      assetDescriptor: assetDescriptor,
      bytes: temporaryFile.openRead(),
    );
    await temporaryFile.delete();
  }

  @override
  Future<void> discard(String temporaryFilePath) async {
    final temporaryFile = File(temporaryFilePath);
    if (await temporaryFile.exists()) await temporaryFile.delete();
  }

  @override
  Future<void> activate({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
    required String manifestDigest,
  }) {
    return _assetStore.activateStagingManifest(
      userScopeId: userScopeId,
      packageId: packageId,
      manifestRevision: manifestRevision,
      payloadDigest: manifestDigest,
    );
  }
}
