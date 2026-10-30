import 'dart:io';

import 'package:dartway_cli/src/deploy/database_backup.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

void main() {
  test(
    'rendered backup keeps local dumps and targets the configured store',
    () {
      final script = dwDatabaseBackupScript(
        stackFrom(
          extra: '''  backup:
    bucket: private-backups
    endpoint: https://s3.twcstorage.ru
    region: ru-1
    recipient: age1recipient
''',
        ),
      );

      final awsCalls = script
          .split('\n')
          .where((line) => RegExp(r'\baws ').hasMatch(line));
      expect(awsCalls, isNotEmpty);
      for (final call in awsCalls) {
        expect(call, contains('--endpoint-url "\$aws_endpoint"'));
        expect(call, contains('--region "\$aws_region"'));
      }
      expect(script, contains("aws_endpoint='https://s3.twcstorage.ru'"));
      expect(script, contains('keep_encrypted=true'));
      expect(
        script,
        contains('[ "\$keep_encrypted" = true ] || rm -f "\$encrypted"'),
      );
      expect(
        script,
        isNot(contains("trap 'rm -f \"\$plain\" \"\$encrypted\"' EXIT")),
      );
    },
  );

  test('external database password is passed in a temporary env file', () {
    final script = dwDatabaseBackupScript(
      stackFrom(
        extra: '''  database: external
  backup:
    bucket: private-backups
    endpoint: https://s3.twcstorage.ru
    recipient: age1recipient
''',
      ),
    );

    expect(script, contains('--env-file "\$pg_env"'));
    expect(script, contains('umask 077'));
    expect(script, contains('rm -f "\$plain" "\$pg_env"'));
    expect(script, isNot(contains('-e PGPASSWORD=')));
  });

  test(
    'rendered script prunes pre-deploy dumps and never copies them weekly',
    () {
      final sandbox = Directory.systemTemp.createTempSync('dw-backup-test-');
      addTearDown(() => sandbox.deleteSync(recursive: true));
      final root = p.join(sandbox.path, 'backups');
      final rendered = dwDatabaseBackupScript(
        stackFrom(
          extra: '''  backup:
    bucket: private-backups
    endpoint: https://s3.twcstorage.ru
    recipient: age1recipient
    pre_deploy: 5
''',
        ),
      );
      final script = rendered
          .split('\n')
          .map((line) {
            if (line.startsWith('source ')) return ':';
            if (line.startsWith("root='")) return "root='$root'";
            if (line.endsWith(' > "\$plain"')) {
              return "printf 'dump' > \"\$plain\"";
            }
            if (line.startsWith('age -r ')) {
              return 'cp "\$plain" "\$encrypted"';
            }
            if (line.startsWith('aws ') && line.contains(' s3 cp ')) return ':';
            return line.replaceAll('"\$(date -u +%u)" = 7', '"7" = 7');
          })
          .join('\n');
      final scriptFile = File(p.join(sandbox.path, 'backup.sh'))
        ..writeAsStringSync(script);

      for (var run = 1; run <= 7; run++) {
        final result = Process.runSync('bash', [
          scriptFile.path,
          'pre-deploy',
          'version-$run',
        ]);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
      }

      expect(
        Directory(
          p.join(root, 'pre-deploy'),
        ).listSync().whereType<File>().length,
        5,
      );
      expect(Directory(p.join(root, 'weekly')).listSync(), isEmpty);
    },
  );
}
