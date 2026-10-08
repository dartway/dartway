import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  for (final stalled in [false, true]) {
    test(
      stalled
          ? 'cleanup fails when an S3 page does not shrink after deletion'
          : 'cleanup decodes spaces and literal plus signs in S3 listings',
      () async {
        const bucket = 'dw-test-abcdefghijklmnop-prv-abcdefghij';
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        var deleted = false, bucketDeleted = false;
        var pages = 0;
        final sweeping = Completer<void>();
        final resume = Completer<void>();
        final deletedKeys = <String>[];
        server.listen((request) async {
          final path = request.uri.pathSegments;
          if (request.method == 'GET' && request.uri.path == '/') {
            request.response.write(
              '<ListAllMyBucketsResult><Buckets><Bucket>'
              '<Name>$bucket</Name></Bucket></Buckets></ListAllMyBucketsResult>',
            );
          } else if (request.method == 'GET') {
            if (!sweeping.isCompleted) {
              sweeping.complete();
              await resume.future;
            }
            pages++;
            expect(request.uri.queryParameters['encoding-type'], 'url');
            request.response.write(
              '<ListBucketResult>'
              '${deleted ? '' : '<Contents><Key>a+%2B%20file</Key></Contents>'}'
              '</ListBucketResult>',
            );
          } else if (request.method == 'DELETE') {
            request.response.statusCode = HttpStatus.noContent;
            if (path.length == 2) {
              deletedKeys.add(path.last);
              if (!stalled) deleted = true;
            } else {
              bucketDeleted = true;
            }
          } else {
            request.response.statusCode = HttpStatus.badRequest;
          }
          await request.response.close();
        });
        final config = packageConfigPath();
        final worker = File('bin/dartway_test_services.dart').absolute;
        final process = await Process.start(
          Platform.resolvedExecutable,
          ['--packages=$config', worker.path, 'cleanup', 'storage'],
          environment: {
            'DW_TEST_RUN_ID': 'abcdefghijklmnop',
            'DW_STORAGE_ENDPOINT': 'http://127.0.0.1:${server.port}',
            'DW_STORAGE_ACCESS_KEY': 'test-key',
            'DW_STORAGE_SECRET_KEY': 'test-secret',
          },
        );
        addTearDown(() => process.kill(ProcessSignal.sigkill));
        final output = process.stdout.transform(utf8.decoder).join();
        final errors = process.stderr.transform(utf8.decoder).join();
        await sweeping.future.timeout(const Duration(seconds: 20));
        // Main is already sweeping; another interrupt must not abort it.
        expect(process.kill(ProcessSignal.sigint), isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        resume.complete();
        final result = await process.exitCode.timeout(
          const Duration(seconds: 30),
        );
        expect(
          result,
          stalled ? 1 : 0,
          reason: '${await output}${await errors}',
        );
        expect(pages, 2);
        expect(deletedKeys, ['a + file']);
        expect(bucketDeleted, !stalled);
        if (stalled) {
          expect(await errors, contains('S3 cleanup made no progress'));
        }
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );
  }
}

String packageConfigPath() {
  // The production worker is launched with the server package's resolution.
  var directory = Directory.current;
  while (true) {
    final config = File('${directory.path}/.dart_tool/package_config.json');
    if (config.existsSync()) return config.absolute.path;
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('package config missing');
    }
    directory = parent;
  }
}
