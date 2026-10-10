import 'dart:io';

import 'package:dartway_cli/src/deploy/disk_space.dart';
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

void main() {
  late Directory temp;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('dw_df_');
  });
  tearDown(() => temp.deleteSync(recursive: true));

  for (final dockerAvailable in [true, false]) {
    for (final freeKiB in [10485759, 10485760]) {
      test('df: $freeKiB KiB, docker available=$dockerAvailable', () async {
        final docker = File('${temp.path}/docker')
          ..writeAsStringSync(
            '#!/bin/sh\n${dockerAvailable ? "echo '/custom/docker data'" : 'exit 1'}\n',
          );
        final df = File('${temp.path}/df')
          ..writeAsStringSync(
            '#!/bin/sh\n'
            'printf "%s\\n" "Filesystem 1024-blocks Used Available Capacity Mounted on" '
            '"/dev/vda1 31457280 10000000 $freeKiB 40% /"\n'
            'printf "%s\\n" "\$2" > "${temp.path}/queried"\n',
          );
        for (final file in [docker, df]) {
          expect((await Process.run('chmod', ['+x', file.path])).exitCode, 0);
        }
        final result = await dwCheckBuildDiskSpace(
          ssh: LocalShell(
            environment: {
              'PATH': '${temp.path}:${Platform.environment['PATH']}',
            },
          ),
          deployUser: 'deployer',
          minimum: '10GB',
          minimumBytes: 10 * 1024 * 1024 * 1024,
        );
        final path = dockerAvailable
            ? '/custom/docker data'
            : '/var/lib/docker';
        expect(File('${temp.path}/queried').readAsStringSync().trim(), path);
        expect(result.ok, freeKiB >= 10485760);
        expect(result.ok ? result.stdout : result.stderr, contains(path));
      });
    }
  }
}
