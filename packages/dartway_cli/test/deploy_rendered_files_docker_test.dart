@Tags(['docker'])
library;

import 'dart:io';

import 'package:dartway_cli/src/deploy/renderer.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

/// The TLS rendering, judged by the tools that will read it on a server:
/// Compose parses the merged project, and nginx accepts the configuration
/// with a certificate in place and every upstream name resolvable. The local
/// stack proof runs the plain-HTTP rendering; this is the other half, which
/// only a server with a certificate would otherwise read for the first time.
void main() {
  for (final MapEntry(key: variant, value: stack) in stackVariants().entries) {
    group(variant, () {
      late Directory dir;
      final renderer = DwStackRenderer(stack: stack);

      setUp(() {
        dir = Directory.systemTemp.createTempSync('dw_rendered_');
        File(
          p.join(dir.path, 'docker-compose.yml'),
        ).writeAsStringSync(renderer.composeFile);
        File(
          p.join(dir.path, 'nginx.conf'),
        ).writeAsStringSync(renderer.nginxFile);
        for (final package in [stack.serverPackage, stack.flutterPackage]) {
          File(p.join(dir.path, package, 'Dockerfile'))
            ..createSync(recursive: true)
            ..writeAsStringSync('FROM scratch\n');
        }
        File(p.join(dir.path, '.env')).writeAsStringSync(
          stack.requiredSecretKeys.map((key) => "$key='value'\n").join(),
        );
      });
      tearDown(() => dir.deleteSync(recursive: true));

      test(
        'Compose accepts the project, and refuses it without its secrets',
        () {
          final valid = Process.runSync('docker', [
            'compose',
            'config',
            '--quiet',
          ], workingDirectory: dir.path);
          expect(valid.exitCode, 0, reason: '${valid.stderr}');

          File(p.join(dir.path, '.env')).writeAsStringSync('');
          final refused = Process.runSync('docker', [
            'compose',
            'config',
            '--quiet',
          ], workingDirectory: dir.path);
          expect(refused.exitCode, isNot(0));
          // Compose names the first secret it misses, whichever that is.
          expect('${refused.stderr}', contains('is missing from .env'));
        },
      );

      test('nginx -t accepts the TLS configuration', () {
        final certificate = '/etc/letsencrypt/live/${stack.target.apiDomain}';
        final result = Process.runSync('docker', [
          'run',
          '--rm',
          '-v',
          '${dir.path}/nginx.conf:/etc/nginx/conf.d/default.conf:ro',
          for (final host in ['server', 'web', 'storage']) ...[
            '--add-host',
            '$host:127.0.0.1',
          ],
          DwStack.nginxImage,
          'sh',
          '-c',
          'apk add -q openssl >/dev/null 2>&1 && '
              'mkdir -p $certificate /etc/nginx/dartway/http '
              '/etc/nginx/dartway/api /etc/nginx/dartway/app && '
              'openssl req -x509 -nodes -newkey rsa:2048 -days 1 '
              '-keyout $certificate/privkey.pem '
              '-out $certificate/fullchain.pem -subj /CN=proof '
              '>/dev/null 2>&1 && nginx -t',
        ]);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect('${result.stderr}', contains('test is successful'));
      });
    });
  }
}
