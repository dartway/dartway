// ignore_for_file: invalid_use_of_internal_member

import 'dart:io';

import 'package:dartway_cli/src/deploy/outside_probe.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/src/files/dw_object_store.dart';
import 'package:dartway_core_server/src/files/dw_storage_buckets.dart';
import 'package:test/test.dart';

void main() {
  test('Kamal provision alone creates the outside visibility probe', () async {
    final source = DwFileStorageConfig.fromEnvironment(Platform.environment);
    final prefix = 'dw-kamal-${DateTime.now().microsecondsSinceEpoch}';
    final public = '$prefix-public';
    final private = '$prefix-private';
    final config = DwFileStorageConfig(
      endpoint: source.endpoint,
      region: source.region,
      accessKey: source.accessKey,
      secretKey: source.secretKey,
      pathStyle: true,
      publicBucket: public,
      publicBaseUrl: source.endpoint.replace(path: '/$public'),
      privateBucket: private,
      verifyBuckets: false,
    );
    final store = DwObjectStore(
      config,
      requestTimeout: const Duration(seconds: 10),
    );
    addTearDown(() async {
      try {
        for (final bucket in [public, private]) {
          await store.delete(bucket, DwBucketCheck.probeKey);
          await (await store.send('DELETE', bucket: bucket)).drain<void>();
        }
      } finally {
        store.close();
      }
    });
    // The Kamal API entry point calls only provision: no storage-init and no
    // server startup bucket verification may create the objects for this test.
    await DwFileStorageSetup.provision(config);
    final result = await DwOutsideProbe().storageVisibility(
      storageOrigin: source.endpoint.toString(),
      publicBucket: public,
      privateBucket: private,
    );
    expect(result.passed, true, reason: result.detail);
    // Anonymous refusal alone cannot prove the private probe exists on S3.
    for (final bucket in [public, private]) {
      final read = await store.send(
        'GET',
        bucket: bucket,
        key: DwBucketCheck.probeKey,
      );
      expect(read.statusCode, 200);
      expect(
        await read.fold<List<int>>([], (all, bytes) => all..addAll(bytes)),
        DwBucketCheck.probeBody,
      );
    }
  }, tags: ['services']);
}
