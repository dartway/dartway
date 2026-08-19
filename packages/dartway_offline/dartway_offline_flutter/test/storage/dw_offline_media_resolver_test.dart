import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dartway_offline_flutter/src/access/dw_offline_lease_policy.dart';
import 'package:dartway_offline_flutter/src/repository/dw_offline_read_delegate.dart';
import 'package:dartway_offline_flutter/src/storage/dw_offline_asset_store.dart';
import 'package:dartway_offline_flutter/src/storage/dw_offline_database.dart';
import 'package:dartway_offline_flutter/src/storage/dw_offline_media_resolver.dart';

import '../support/signed_manifest_fixture.dart';

void main() {
  late Directory supportDirectory;
  late DwOfflineDatabase offlineDatabase;
  late DwOfflineAssetStore assetStore;
  late TestSignedManifestFixture manifestFixture;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'offline_media_resolver_',
    );
    offlineDatabase = DwOfflineDatabase(NativeDatabase.memory());
    assetStore = DwOfflineAssetStore(
      applicationSupportDirectory: supportDirectory,
      database: offlineDatabase,
    );
    manifestFixture = await TestSignedManifestFixture.create();
  });

  tearDown(() async {
    await offlineDatabase.close();
    if (supportDirectory.existsSync()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test('opens an authorized ready URL and pins its local blob', () async {
    final verifiedManifest = await _MediaResolverFixture.publishPackage(
      manifestFixture,
      assetStore,
    );
    final resolver = DwOfflineMediaResolver(
      database: offlineDatabase,
      assetStore: assetStore,
      packageAccessPolicy: const _PackageAccessPolicy(isAllowed: true),
    );

    final mediaHandle = await resolver.openForDownloadUrl(
      userScopeId: 'scope-a',
      downloadUrl: 'https://cdn.example.test/asset-a.bin',
    );

    expect(mediaHandle, isNotNull);
    expect(mediaHandle!.fileUri.scheme, 'file');
    expect(mediaHandle.mimeType, 'application/octet-stream');
    final localFile = File.fromUri(mediaHandle.fileUri);
    expect(await localFile.readAsBytes(), const [1, 2, 3, 4, 5]);
    await assetStore.deletePackage(
      userScopeId: 'scope-a',
      packageId: verifiedManifest.manifest.packageId,
    );
    expect(localFile.existsSync(), isTrue);

    await mediaHandle.close();

    expect(localFile.existsSync(), isFalse);
  });

  test(
    'does not expose a ready blob when every package lease is denied',
    () async {
      await _MediaResolverFixture.publishPackage(manifestFixture, assetStore);
      final resolver = DwOfflineMediaResolver(
        database: offlineDatabase,
        assetStore: assetStore,
        packageAccessPolicy: const _PackageAccessPolicy(isAllowed: false),
      );

      final mediaHandle = await resolver.openForDownloadUrl(
        userScopeId: 'scope-a',
        downloadUrl: 'https://cdn.example.test/asset-a.bin',
      );

      expect(mediaHandle, isNull);
    },
  );

  test(
    'chooses the most recently activated asset for a repeated URL',
    () async {
      const sharedUrl = 'https://cdn.example.test/shared.bin';
      await _MediaResolverFixture.publishPackage(
        manifestFixture,
        assetStore,
        packageId: 'package-a',
        assetId: 'asset-a',
        assetRevision: 'r1',
        downloadUrl: sharedUrl,
        mimeType: 'video/mp4',
        bytes: const [1, 2, 3, 4, 5],
      );
      await _MediaResolverFixture.publishPackage(
        manifestFixture,
        assetStore,
        packageId: 'package-z',
        assetId: 'asset-z',
        assetRevision: 'r2',
        downloadUrl: sharedUrl,
        mimeType: 'application/pdf',
        bytes: const [6, 7, 8],
      );
      await offlineDatabase.customUpdate(
        "UPDATE dw_offline_packages SET updated_at_epoch_ms = "
        "CASE package_id WHEN 'package-a' THEN 100 ELSE 200 END",
        updates: {offlineDatabase.dwOfflinePackages},
      );
      final resolver = DwOfflineMediaResolver(
        database: offlineDatabase,
        assetStore: assetStore,
        packageAccessPolicy: const _PackageAccessPolicy(isAllowed: true),
      );

      final mediaHandle = await resolver.openForDownloadUrl(
        userScopeId: 'scope-a',
        downloadUrl: sharedUrl,
      );

      expect(mediaHandle, isNotNull);
      final openedMedia = mediaHandle!;
      addTearDown(openedMedia.close);
      expect(openedMedia.mimeType, 'application/pdf');
      expect(await File.fromUri(openedMedia.fileUri).readAsBytes(), const [
        6,
        7,
        8,
      ]);
    },
  );
}

abstract final class _MediaResolverFixture {
  static Future<DwVerifiedOfflineManifest> publishPackage(
    TestSignedManifestFixture manifestFixture,
    DwOfflineAssetStore assetStore, {
    String packageId = 'package-a',
    String assetId = 'asset-a',
    String assetRevision = 'r1',
    String? downloadUrl,
    String mimeType = 'application/octet-stream',
    List<int> bytes = const [1, 2, 3, 4, 5],
  }) async {
    final asset = manifestFixture.assetMap(
      assetId: assetId,
      assetRevision: assetRevision,
      bytes: bytes,
    );
    if (downloadUrl != null) asset['downloadUrl'] = downloadUrl;
    asset['mimeType'] = mimeType;
    final verifiedManifest = await manifestFixture.verify(
      packageId: packageId,
      assets: [asset],
    );
    await assetStore.beginStagingManifest(verifiedManifest);
    await assetStore.publishAsset(
      userScopeId: 'scope-a',
      assetDescriptor: verifiedManifest.manifest.assets.single,
      bytes: Stream.value(bytes),
    );
    await assetStore.activateStagingManifest(
      userScopeId: 'scope-a',
      packageId: verifiedManifest.manifest.packageId,
      manifestRevision: verifiedManifest.manifest.manifestRevision,
      payloadDigest: verifiedManifest.payloadDigest,
    );
    return verifiedManifest;
  }
}

final class _PackageAccessPolicy implements DwOfflinePackageAccessPolicy {
  const _PackageAccessPolicy({required this.isAllowed});

  final bool isAllowed;

  @override
  Future<bool> canReadPackage({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
  }) async => isAllowed;
}
