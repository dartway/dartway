import 'package:dartway_cli/src/deploy/database_backup.dart';
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
}
