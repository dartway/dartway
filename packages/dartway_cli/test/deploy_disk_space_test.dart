import 'dart:io';

import 'package:dartway_cli/src/deploy/deploy_runner.dart';
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
          'mirror.example/${DwStack.postgresImage} df -Pk $root',
    ]);
  });

  test('a Docker-only root refuses when container df fails', () async {
    final root = '${temp.path}/missing-docker-root';
    File('${temp.path}/docker').writeAsStringSync('''#!/bin/sh
if [ "\$1" = info ]; then
  printf '%s\\n' "\$DW_TEST_DOCKER_ROOT"
else
  exit 1
fi
''');

    final result = await _check({...environment, 'DW_TEST_DOCKER_ROOT': root});

    expect(result.ok, isFalse);
    expect(result.stdout, isEmpty);
    expect(result.stderr, isEmpty);
  });

  test('cleanup prunes and reports space for a Docker-only root', () async {
    final root = '${temp.path}/missing-docker-root';
    final journal = Directory('${temp.path}/store/deploy-run')
      ..createSync(recursive: true);
    for (final service in ['server', 'web']) {
      File('${journal.path}/$service.previous').writeAsStringSync('');
    }
    File('${temp.path}/docker').writeAsStringSync('''#!/bin/sh
printf 'docker' >> "\$DW_TEST_CALLS"
printf ' %s' "\$@" >> "\$DW_TEST_CALLS"
printf '\\n' >> "\$DW_TEST_CALLS"
case "\$*" in
  info*) printf '%s\\n' "\$DW_TEST_DOCKER_ROOT" ;;
  'run --rm --volume $root:$root:ro mirror.example/${DwStack.postgresImage} df -Pk $root')
    if [ -f '${temp.path}/pruned' ]; then free=10485761; else free=10485760; fi
    printf '%s\\n' 'Filesystem 1024-blocks Used Available Capacity Mounted on'
    printf '/dev/vda1 31457280 10000000 %s 40%% /\\n' "\$free" ;;
  run*) echo "unexpected fallback image or pull policy: \$*" >&2; exit 1 ;;
  'system df'*)
    if [ ! -f '${temp.path}/pruned' ]; then printf '%s\\n' 'false 1MB'; fi ;;
  'image ls'*'service=server') printf '%s\\n' 'sha256:unused' ;;
  'image inspect'*) printf '%s\\n' 'shop,server' ;;
  'builder prune'*) touch '${temp.path}/pruned' ;;
esac
''');
    final runner = DwDeployRunner(
      ssh: LocalShell(
        environment: {...environment, 'DW_TEST_DOCKER_ROOT': root},
      ),
      stack: stackFrom(extra: '  registry_mirror: mirror.example\n'),
      appDir: temp.path,
      storeDir: '${temp.path}/store',
    );

    final result = await runner.cleanup();

    expect(result.ok, isTrue, reason: result.stderr);
    expect(result.stderr, isEmpty);
    expect(DwDeployRunner.cleanupReport(result), {
      'images_removed': 1,
      'cache_records_removed': 1,
      'freed_bytes': 1024,
      'cache_shared_bytes': 0,
    });
    final issued = calls.readAsLinesSync();
    expect(issued.where((call) => call.startsWith('docker run ')), [
      for (var reading = 0; reading < 2; reading++)
        'docker run --rm --volume $root:$root:ro '
            'mirror.example/${DwStack.postgresImage} df -Pk $root',
    ]);
    expect(issued, contains('docker image rm sha256:unused'));
    expect(issued, contains('docker builder prune -a -f --keep-storage 10GB'));
  });
}

Future<DwSshResult> _check(Map<String, String> environment) =>
    dwCheckBuildDiskSpace(
      ssh: LocalShell(environment: environment),
      deployUser: 'deployer',
      minimum: '10GB',
      minimumBytes: 10 * 1024 * 1024 * 1024,
      dockerImage: 'mirror.example/${DwStack.postgresImage}',
    );
