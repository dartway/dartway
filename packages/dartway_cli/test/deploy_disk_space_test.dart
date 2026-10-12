import 'dart:io';

import 'package:dartway_cli/src/deploy/disk_space.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

void main() {
  late Directory temp;
  late File calls;
  late Map<String, String> environment;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('dw_df_');
    calls = File('${temp.path}/calls');
    environment = {
      'PATH': '${temp.path}:${Platform.environment['PATH']}',
      'DW_TEST_CALLS': calls.path,
    };
    final df = File('${temp.path}/df')
      ..writeAsStringSync('''#!/bin/sh
printf 'df %s\\n' "\$2" >> "\$DW_TEST_CALLS"
printf '%s\\n' 'Filesystem 1024-blocks Used Available Capacity Mounted on' '/dev/vda1 31457280 10000000 10485760 40% /'
''');
    final docker = File('${temp.path}/docker')
      ..writeAsStringSync('''#!/bin/sh
printf 'docker' >> "\$DW_TEST_CALLS"
printf ' %s' "\$@" >> "\$DW_TEST_CALLS"
printf '\\n' >> "\$DW_TEST_CALLS"
if [ "\$1" = info ]; then
  printf '%s\\n' "\$DW_TEST_DOCKER_ROOT"
else
  printf '%s\\n' 'Filesystem 1024-blocks Used Available Capacity Mounted on' '/dev/vda1 31457280 10000000 10485760 40% /'
fi
''');
    for (final file in [df, docker]) {
      expect((await Process.run('chmod', ['+x', file.path])).exitCode, 0);
    }
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('an existing Docker root is measured by host df', () async {
    final root = Directory('${temp.path}/docker data')..createSync();

    final result = await _check({
      ...environment,
      'DW_TEST_DOCKER_ROOT': root.path,
    });

    expect(result.ok, isTrue);
    expect(result.stdout, '${root.path}: 10.0 GiB free of 30.0 GiB');
    expect(calls.readAsLinesSync(), [
      'docker info -f {{.DockerRootDir}}',
      'df ${root.path}',
    ]);
  });

  test('a Docker-only root is mounted and measured in a container', () async {
    const root = '/docker-vm-only/root';

    final result = await _check({...environment, 'DW_TEST_DOCKER_ROOT': root});

    expect(result.ok, isTrue);
    expect(result.stdout, '$root: 10.0 GiB free of 30.0 GiB');
    expect(calls.readAsLinesSync(), [
      'docker info -f {{.DockerRootDir}}',
      'docker run --rm --volume $root:$root:ro '
          '${DwStack.postgresImage} df -Pk $root',
    ]);
  });

  test('a missing root with no Docker still refuses the check', () async {
    File('${temp.path}/docker').writeAsStringSync('#!/bin/sh\nexit 1\n');

    final result = await _check(environment);

    expect(result.ok, isFalse);
    expect(result.stderr, "Cannot read free space on Docker's data root.");
  });
}

Future<DwSshResult> _check(Map<String, String> environment) =>
    dwCheckBuildDiskSpace(
      ssh: LocalShell(environment: environment),
      deployUser: 'deployer',
      minimum: '10GB',
      minimumBytes: 10 * 1024 * 1024 * 1024,
    );
