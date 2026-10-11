import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer storage;
  late DwFileStorageConfig config;
  final cors = <({String bucket, String? md5, String body})>[];
  final probes = <String>[];
  var status = 200;
  var code = '';

  setUp(() async {
    cors.clear();
    probes.clear();
    status = 200;
    code = '';
    storage = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final endpoint = Uri.parse('http://127.0.0.1:${storage.port}');
    config = DwFileStorageConfig(
      endpoint: endpoint,
      accessKey: 'test-key',
      secretKey: 'test-secret',
      publicBucket: 'test-public',
      publicBaseUrl: endpoint.resolve('/test-public'),
      privateBucket: 'test-private',
    );
    storage.listen((request) async {
      final body = await utf8.decodeStream(request);
      if (request.uri.queryParameters.containsKey('cors')) {
        cors.add((
          bucket: request.uri.pathSegments.first,
          md5: request.headers.value('content-md5'),
          body: body,
        ));
        request.response.statusCode = status;
        if (status >= 300) {
          request.response.write('<Error><Code>$code</Code></Error>');
        }
      } else if (request.uri.path.endsWith('/_dartway/visibility-probe')) {
        probes.add(request.uri.pathSegments.first);
      }
      await request.response.close();
    });
    addTearDown(() => storage.close(force: true));
  });

  Future<ProcessResult> worker(String mode) => Process.run(
    Platform.resolvedExecutable,
    ['test/fixtures/provision_storage.dart', mode],
    environment: {
      'DW_STORAGE_ENDPOINT': '${config.endpoint}',
      'DW_STORAGE_ACCESS_KEY': config.accessKey,
      'DW_STORAGE_SECRET_KEY': config.secretKey,
      'DW_STORAGE_PUBLIC_BUCKET': config.publicBucket!,
      'DW_STORAGE_PUBLIC_BASE_URL': '${config.publicBaseUrl}',
      'DW_STORAGE_PRIVATE_BUCKET': config.privateBucket!,
      'DW_ALLOWED_ORIGINS': 'https://exported.example',
    },
  );

  test('DwTestStorage ignores exported DW_ALLOWED_ORIGINS for CORS', () async {
    final result = await worker('test-storage');
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(cors, isEmpty);
    expect(probes, hasLength(2));
  });

  test(
    'provision sends Content-MD5 and GET/PUT CORS to both buckets',
    () async {
      await DwFileStorageSetup.provision(
        config,
        allowedOrigins: ['https://app.example'],
      );
      expect(cors.map((request) => request.bucket), [
        'test-public',
        'test-private',
      ]);
      for (final request in cors) {
        expect(
          request.md5,
          base64.encode(md5.convert(utf8.encode(request.body)).bytes),
        );
        expect(
          request.body,
          contains('<AllowedOrigin>https://app.example</AllowedOrigin>'),
        );
        expect(request.body, contains('<AllowedMethod>GET</AllowedMethod>'));
        expect(request.body, contains('<AllowedMethod>PUT</AllowedMethod>'));
      }
      expect(probes, ['test-public', 'test-private']);
    },
  );

  test(
    '501 NotImplemented warns with storage and bucket and continues',
    () async {
      status = 501;
      code = 'NotImplemented';
      final result = await worker('provision');
      expect(result.exitCode, 0, reason: '${result.stderr}');
      for (final bucket in ['test-public', 'test-private']) {
        expect(result.stderr, contains('WARNING'));
        expect(result.stderr, contains('${config.endpoint}'));
        expect(result.stderr, contains('bucket "$bucket"'));
      }
      expect(cors, hasLength(2));
      expect(probes, ['test-public', 'test-private']);
    },
  );

  for (final (errorStatus, errorCode) in [
    (403, 'AccessDenied'),
    (501, 'OtherError'),
  ]) {
    test('CORS $errorStatus $errorCode is fatal', () async {
      status = errorStatus;
      code = errorCode;
      await expectLater(
        DwFileStorageSetup.provision(
          config,
          allowedOrigins: ['https://app.example'],
        ),
        throwsA(
          isA<DwStorageException>()
              .having((error) => error.status, 'status', errorStatus)
              .having((error) => error.errorCode, 'code', errorCode),
        ),
      );
      expect(cors, hasLength(1));
      expect(probes, isEmpty);
    });
  }
}
