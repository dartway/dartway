// ignore_for_file: invalid_use_of_internal_member

import 'dart:io';

import 'package:dartway_cli/src/deploy/outside_probe.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/src/files/dw_object_store.dart';
import 'package:dartway_core_server/src/files/dw_storage_buckets.dart';
import 'package:test/test.dart';

Future<void> _provisionOnly(DwFileStorageConfig source) async {
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
  await DwFileStorageSetup.provision(
    config,
    allowedOrigins: ['https://app.example.com'],
  );
  for (final bucket in [public, private]) {
    final cors = await DwOutsideProbe().storageCors(
      storageOrigin: source.endpoint.toString(),
      bucket: bucket,
      appOrigin: 'https://app.example.com',
    );
    expect(cors.passed, true, reason: cors.detail);
  }
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
}

void main() {
  test(
    'Kamal provision alone creates visibility and CORS preconditions',
    () => _provisionOnly(
      DwFileStorageConfig.fromEnvironment(Platform.environment),
    ),
    tags: ['services'],
  );

  test(
    'provision-only preflight on the generated RustFS image',
    () async {
      final name = 'dw530-cors-${DateTime.now().microsecondsSinceEpoch}';
      final up = await Process.run('docker', [
        'run',
        '-d',
        '--name',
        name,
        '-e',
        'RUSTFS_ACCESS_KEY=dw530access',
        '-e',
        'RUSTFS_SECRET_KEY=dw530secretvalue',
        '-p',
        '127.0.0.1::9000',
        DwStack.storageImage,
        '/data',
      ]);
      expect(up.exitCode, 0, reason: '${up.stderr}');
      addTearDown(() async {
        await Process.run('docker', ['rm', '-f', name]);
      });
      final port = await Process.run('docker', ['port', name, '9000']);
      final endpoint = Uri.parse('http://${(port.stdout as String).trim()}');
      final client = HttpClient();
      try {
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (true) {
          try {
            final response = await (await client.getUrl(
              endpoint.resolve('/health'),
            )).close();
            await response.drain<void>();
            if (response.statusCode == 200) break;
          } on IOException {
            /* RustFS is still starting. */
          }
          if (DateTime.now().isAfter(deadline))
            fail('RustFS did not become healthy');
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      } finally {
        client.close(force: true);
      }
      // /health can answer before RustFS's S3 layer accepts bucket calls.
      // A signed HEAD of an absent bucket must answer 404, rather than 503.
      final readiness = DwObjectStore(
        DwFileStorageConfig(
          endpoint: endpoint,
          accessKey: 'dw530access',
          secretKey: 'dw530secretvalue',
        ),
        requestTimeout: const Duration(seconds: 2),
      );
      try {
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (true) {
          final response = await readiness.send(
            'HEAD',
            bucket: 'dw530-not-created',
          );
          await response.drain<void>();
          if (response.statusCode == 404) break;
          if (DateTime.now().isAfter(deadline))
            fail('RustFS S3 layer answered ${response.statusCode}');
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      } finally {
        readiness.close();
      }
      await _provisionOnly(
        DwFileStorageConfig(
          endpoint: endpoint,
          accessKey: 'dw530access',
          secretKey: 'dw530secretvalue',
        ),
      );
    },
    tags: ['docker'],
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
