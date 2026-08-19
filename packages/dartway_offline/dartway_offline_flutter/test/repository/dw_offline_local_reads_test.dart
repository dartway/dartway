import 'dart:convert';

import 'package:dartway_offline_flutter/src/access/dw_offline_lease_policy.dart';
import 'package:dartway_offline_flutter/src/repository/dw_offline_local_reads.dart';
import 'package:dartway_offline_flutter/src/storage/dw_offline_database.dart';
import 'package:dartway_offline_shared/dartway_offline_shared.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/signed_manifest_fixture.dart';

void main() {
  late DwOfflineDatabase database;
  late TestSignedManifestFixture manifestFixture;
  late _PackageAccessPolicy accessPolicy;
  late DwOfflineLocalReads delegate;
  late DwRepoQueryKey<Object> resourceQuery;

  setUp(() async {
    database = DwOfflineDatabase(NativeDatabase.memory());
    manifestFixture = await TestSignedManifestFixture.create();
    accessPolicy = _PackageAccessPolicy();
    delegate = DwOfflineLocalReads(
      database: database,
      packageAccessPolicy: accessPolicy,
    );
    resourceQuery = DwRepoQueryKey<Object>.getOne(
      modelClassName: 'ResourceRecord',
      filters: const {'id': 42},
    );
    await delegate.activateUserScope('scope-a');
  });

  tearDown(() async {
    await delegate.deactivateUserScope();
    await database.close();
  });

  test('unselected online queries are not persisted', () async {
    final binding = (await delegate.resolveBinding())!;

    final result = await delegate.storeSnapshotIfCurrent(
      binding: binding,
      queryKey: resourceQuery,
      snapshot: snapshot(binding.scope, 42),
    );

    expect(result, DwRepoReadSnapshotStoreResult.ignored);
    expect(await database.select(database.dwOfflineSnapshots).get(), isEmpty);
  });

  test('scope-retained progress snapshot survives a cold read', () async {
    final progressQuery = DwRepoQueryKey<Object>.getAll(
      modelClassName: 'AccountResourceState',
      filters: const {'userProfileId': 7},
    );
    await delegate.retainScopeQueryStorageKey(progressQuery.toStorageKey());
    final binding = (await delegate.resolveBinding())!;
    expect(
      await delegate.storeSnapshotIfCurrent(
        binding: binding,
        queryKey: progressQuery,
        snapshot: snapshot(binding.scope, 1),
      ),
      DwRepoReadSnapshotStoreResult.stored,
    );

    await delegate.deactivateUserScope();
    await delegate.activateUserScope('scope-a');
    await delegate.retainScopeQuery(progressQuery);
    final restoredBinding = (await delegate.resolveBinding())!;

    expect(
      (await delegate.loadSnapshot(
        binding: restoredBinding,
        queryKey: progressQuery,
      ))?.responseJson,
      {'isOk': true, 'value': 1},
    );
  });

  test(
    'package snapshot is readable only after activation and lease approval',
    () async {
      final offlineResource = <String, Object?>{
        'className': 'ResourceRecord',
        'data': <String, Object?>{'id': 42, 'title': 'Offline resource'},
        'isDeleted': false,
      };
      final manifest = await manifestFixture.verify(
        assets: [manifestFixture.assetMap(isRequired: false)],
        repositoryContentDigest: DwOfflineRepositoryContentRevision.compute([
          offlineResource,
        ]),
      );
      await database.beginStagingManifest(manifest);
      await delegate.installPackageSnapshotStorageKey(
        verifiedManifest: manifest,
        queryStorageKey: resourceQuery.toStorageKey(),
        snapshot: DwRepoReadSnapshot(
          schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
          scope: DwRepoScope('scope-a'),
          responseJson: {'isOk': true, 'value': offlineResource},
        ),
      );
      var binding = (await delegate.resolveBinding())!;

      expect(
        await delegate.loadSnapshot(binding: binding, queryKey: resourceQuery),
        isNull,
      );

      await database.activateStagingManifest(
        userScopeId: 'scope-a',
        packageId: 'package-a',
        manifestRevision: 'manifest-1',
        payloadDigest: manifest.payloadDigest,
      );
      accessPolicy.allow(manifest);
      binding = (await delegate.resolveBinding())!;

      expect(
        (await delegate.loadSnapshot(
          binding: binding,
          queryKey: resourceQuery,
        ))?.responseJson,
        {'isOk': true, 'value': offlineResource},
      );

      accessPolicy.allowedPackages.clear();
      expect(
        await delegate.loadSnapshot(binding: binding, queryKey: resourceQuery),
        isNull,
      );
    },
  );

  test('tampered signed package snapshot is never returned', () async {
    final signedModel = <String, Object?>{
      'className': 'ResourceRecord',
      'data': <String, Object?>{'id': 42, 'title': 'Signed resource'},
      'isDeleted': false,
    };
    final repositoryContentDigest = DwOfflineRepositoryContentRevision.compute([
      signedModel,
    ]);
    final manifest = await manifestFixture.verify(
      manifestRevision: 'manifest-integrity-check',
      repositoryContentDigest: repositoryContentDigest,
      assets: const [],
    );
    await database.beginStagingManifest(manifest);
    await delegate.installPackageSnapshotStorageKey(
      verifiedManifest: manifest,
      queryStorageKey: resourceQuery.toStorageKey(),
      snapshot: DwRepoReadSnapshot(
        schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
        scope: DwRepoScope('scope-a'),
        responseJson: {'isOk': true, 'value': signedModel},
      ),
    );
    await database.activateStagingManifest(
      userScopeId: 'scope-a',
      packageId: 'package-a',
      manifestRevision: 'manifest-integrity-check',
      payloadDigest: manifest.payloadDigest,
    );
    accessPolicy.allow(manifest);
    await database.customUpdate(
      'UPDATE dw_offline_package_snapshots SET envelope_json = ?',
      variables: [
        Variable<String>(
          jsonEncode({
            'isOk': true,
            'value': {
              ...signedModel,
              'data': {'id': 42, 'title': 'Tampered resource'},
            },
          }),
        ),
      ],
      updates: {database.dwOfflinePackageSnapshots},
    );
    final binding = (await delegate.resolveBinding())!;

    expect(
      await delegate.loadSnapshot(binding: binding, queryKey: resourceQuery),
      isNull,
    );
  });

  test(
    'newest authorized package list snapshot wins duplicate models',
    () async {
      final collectionQuery = DwRepoQueryKey<Object>.getAll(
        modelClassName: 'ResourceCollection',
      );
      Map<String, Object?> model(int id, String title) => {
        'className': 'ResourceCollection',
        'data': {'id': id, 'title': title},
        'isDeleted': false,
      };
      final firstValues = [model(1, 'old'), model(2, 'second')];
      final secondValues = [model(1, 'new'), model(3, 'third')];
      final firstManifest = await manifestFixture.verify(
        packageId: 'package-a',
        assets: const [],
        repositoryContentDigest: DwOfflineRepositoryContentRevision.compute(
          firstValues,
        ),
      );
      final secondManifest = await manifestFixture.verify(
        packageId: 'package-b',
        manifestRevision: 'manifest-2',
        leaseRecordVersion: 2,
        assets: const [],
        repositoryContentDigest: DwOfflineRepositoryContentRevision.compute(
          secondValues,
        ),
      );
      for (final (manifest, values) in [
        (firstManifest, firstValues),
        (secondManifest, secondValues),
      ]) {
        await database.beginStagingManifest(manifest);
        await delegate.installPackageSnapshotStorageKey(
          verifiedManifest: manifest,
          queryStorageKey: collectionQuery.toStorageKey(),
          snapshot: DwRepoReadSnapshot(
            schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
            scope: DwRepoScope('scope-a'),
            responseJson: {'isOk': true, 'value': values},
          ),
        );
        await database.activateStagingManifest(
          userScopeId: 'scope-a',
          packageId: manifest.manifest.packageId,
          manifestRevision: manifest.manifest.manifestRevision,
          payloadDigest: manifest.payloadDigest,
        );
        accessPolicy.allow(manifest);
      }
      await database.customUpdate(
        'UPDATE dw_offline_packages SET updated_at_epoch_ms = ? '
        'WHERE user_scope_id = ? AND package_id = ?',
        variables: const [
          Variable<int>(200),
          Variable<String>('scope-a'),
          Variable<String>('package-b'),
        ],
        updates: {database.dwOfflinePackages},
      );
      await database.customUpdate(
        'UPDATE dw_offline_packages SET updated_at_epoch_ms = ? '
        'WHERE user_scope_id = ? AND package_id = ?',
        variables: const [
          Variable<int>(100),
          Variable<String>('scope-a'),
          Variable<String>('package-a'),
        ],
        updates: {database.dwOfflinePackages},
      );
      final binding = (await delegate.resolveBinding())!;

      final restored = await delegate.loadSnapshot(
        binding: binding,
        queryKey: collectionQuery,
      );

      expect(restored?.responseJson['value'], [
        model(1, 'new'),
        model(3, 'third'),
        model(2, 'second'),
      ]);
    },
  );

  test('scope switching prevents cross-account snapshot reads', () async {
    final progressQuery = DwRepoQueryKey<Object>.getAll(
      modelClassName: 'UserExercise',
      filters: const {'userProfileId': 7},
    );
    await delegate.retainScopeQuery(progressQuery);
    final firstBinding = (await delegate.resolveBinding())!;
    await delegate.storeSnapshotIfCurrent(
      binding: firstBinding,
      queryKey: progressQuery,
      snapshot: snapshot(firstBinding.scope, 3),
    );

    await delegate.activateUserScope('scope-b');
    await delegate.retainScopeQuery(progressQuery);
    final secondBinding = (await delegate.resolveBinding())!;

    expect(
      await delegate.loadSnapshot(
        binding: secondBinding,
        queryKey: progressQuery,
      ),
      isNull,
    );
    expect(await delegate.isBindingCurrent(firstBinding), isFalse);
  });

  test(
    'corrupt scope snapshot is removed instead of failing repeatedly',
    () async {
      final progressQuery = DwRepoQueryKey<Object>.getAll(
        modelClassName: 'AccountResourceState',
        filters: const {'userProfileId': 7},
      );
      await delegate.retainScopeQuery(progressQuery);
      await database.customStatement(
        'INSERT INTO dw_offline_snapshots '
        '(user_scope_id, query_key, envelope_json, captured_at_epoch_ms) '
        'VALUES (?, ?, ?, ?)',
        ['scope-a', progressQuery.toStorageKey(), '{', 1],
      );
      final binding = (await delegate.resolveBinding())!;

      expect(
        await delegate.loadSnapshot(binding: binding, queryKey: progressQuery),
        isNull,
      );
      expect(await database.select(database.dwOfflineSnapshots).get(), isEmpty);
    },
  );
}

DwRepoReadSnapshot snapshot(DwRepoScope scope, int value) {
  return DwRepoReadSnapshot(
    schemaVersion: DwRepoReadSnapshot.currentSchemaVersion,
    scope: scope,
    responseJson: {'isOk': true, 'value': value},
  );
}

final class _PackageAccessPolicy implements DwOfflineRepositoryReadPolicy {
  final Set<String> allowedPackages = {};
  final Map<String, String> repositoryContentDigests = {};

  void allow(DwVerifiedOfflineManifest manifest) {
    allowedPackages.add(manifest.manifest.packageId);
    repositoryContentDigests[manifest.manifest.packageId] =
        manifest.manifest.repositoryContentDigest;
  }

  @override
  Future<String?> authorizedRepositoryContentDigest({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
  }) async => allowedPackages.contains(packageId)
      ? repositoryContentDigests[packageId]
      : null;

  @override
  Future<bool> canReadPackage({
    required String userScopeId,
    required String packageId,
    required String manifestRevision,
  }) async {
    return allowedPackages.contains(packageId);
  }
}
