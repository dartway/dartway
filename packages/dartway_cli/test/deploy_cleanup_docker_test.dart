@Tags(['docker'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dartway_cli/src/deploy/deploy_runner.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

void main() {
  for (final containerd in [false, true]) {
    test(
      'three deploys bound images and cache (${containerd ? 'containerd' : 'classic'} store)',
      () async {
        final name = 'dw-cleanup-${DateTime.now().microsecondsSinceEpoch}';
        Future<ProcessResult> host(List<String> args) =>
            Process.run('docker', args);
        final started = await host([
          'run',
          '-d',
          '--privileged',
          '--name',
          name,
          '-e',
          'DOCKER_TLS_CERTDIR=',
          'docker:29.1.3-dind',
          if (!containerd) '--storage-driver=overlay2',
          '--feature=containerd-snapshotter=$containerd',
        ]);
        expect(started.exitCode, 0, reason: '${started.stderr}');
        addTearDown(() async {
          await host(['rm', '-f', '-v', name]);
        });
        final shell = EngineShell(name);
        DwSshResult? ready;
        for (var attempt = 0; attempt < 90; attempt++) {
          ready = await shell.run('docker info');
          if (ready.ok) break;
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        expect(
          ready!.ok,
          isTrue,
          reason: '${(await host(['logs', name])).stderr}',
        );
        final driver = await shell.run(
          "docker info -f '{{json .DriverStatus}}'",
        );
        expect(
          driver.stdout.contains('io.containerd.snapshotter.v1'),
          containerd,
        );
        final setup = await shell.run(r'''
set -e
mkdir -p /stack /state
cat >/stack/docker-compose.yml <<'YAML'
name: shop
services:
  server:
    build: .
    healthcheck:
      test: [CMD-SHELL, 'test "$$(cat /health)" = ok']
      interval: 1s
      timeout: 1s
      retries: 1
  web:
    build: .
YAML
cat >/stack/Dockerfile <<'DOCKER'
FROM busybox:1.37
COPY payload /payload
COPY health /health
CMD ["sh", "-c", "if [ \"$DW_MIGRATE_ONLY\" = true ]; then exit 0; fi; trap 'exit 0' TERM; sleep 86400 & wait"]
DOCKER
# Foreign images and accessories must survive even with no container.
docker pull busybox:1.37
mkdir -p /fixture
printf 'FROM busybox:1.37\nRUN echo fixture >/fixture\n' >/fixture/Dockerfile
docker build --label com.docker.compose.project=second --label com.docker.compose.service=server -t second-server:latest /fixture
docker tag second-server:latest shop-server:foreign
for accessory in postgres rustfs nginx certbot; do
  docker build --label com.docker.compose.project=shop --label com.docker.compose.service="$accessory" -t "$accessory:fixture" /fixture
done
docker tag nginx:fixture shop-web:accessory
''');
        expect(setup.ok, isTrue, reason: setup.stderr);
        final runner = DwDeployRunner(
          ssh: shell,
          stack: stackFrom(
            extra: '  build_cache_keep: 1MB\n  min_free_disk: 1MB\n',
          ),
          appDir: '/stack',
          storeDir: '/state',
        );
        final serverImages = <String>[];
        final webImages = <String>[];
        var usedAfterTwo = 0;
        for (var deploy = 1; deploy <= 3; deploy++) {
          expect((await shell.run('rm -rf /state/deploy-run')).ok, isTrue);
          final built = await shell.run(
            'echo ${deploy == 3 ? 'bad' : 'ok'} >/stack/health; dd if=/dev/urandom of=/stack/payload bs=1M count=3 2>/dev/null',
          );
          expect(built.ok, isTrue, reason: built.stderr);
          final imagesBuilt = await runner.build();
          expect(imagesBuilt.ok, isTrue, reason: imagesBuilt.stderr);
          if (deploy == 3) {
            // Deploy 2 has already cleaned the store. A failed third server
            // must still find and start its rollback image, with healthy code.
            final failed = await runner.replaceServer();
            expect(failed.ok, isFalse);
            expect(
              failed.stderr,
              contains('the previous server is running again'),
            );
            final rolledBack = await shell.run(
              "docker image inspect -f '{{.Id}}' shop-server:latest",
            );
            expect(rolledBack.stdout.trim(), serverImages.last);
            final healthy = await shell.run(
              '${DwDeployRunner.waitHealthyFunction(timeoutSeconds: 10)}\n'
              'dw_wait_healthy "\$(cd /stack && docker compose ps -q server)" rollback',
            );
            expect(healthy.ok, isTrue, reason: healthy.stderr);
            expect((await shell.run('echo ok >/stack/health')).ok, isTrue);
            expect((await runner.build()).ok, isTrue);
          }
          final server = await runner.replaceServer();
          expect(server.ok, isTrue, reason: server.stderr);
          final web = await runner.startWeb();
          expect(web.ok, isTrue, reason: web.stderr);
          serverImages.add(
            (await shell.run(
              "cd /stack && docker image inspect -f '{{.Id}}' shop-server:latest",
            )).stdout.trim(),
          );
          webImages.add(
            (await shell.run(
              "cd /stack && docker image inspect -f '{{.Id}}' shop-web:latest",
            )).stdout.trim(),
          );
          final cleanup = runner
              .steps(skipGitUpdate: true)
              .singleWhere((step) => step.id == 'cleanup');
          final cleaned = await cleanup.run();
          expect(
            cleaned.ok,
            isTrue,
            reason: '${cleaned.stdout}\n${cleaned.stderr}',
          );
          final usage = await shell.run(
            "docker system df --format '{{json .}}'",
          );
          expect(usage.ok, isTrue, reason: usage.stderr);
          final rows = usage.stdout
              .split('\n')
              .where((line) => line.isNotEmpty)
              .map((line) => jsonDecode(line) as Map<String, dynamic>)
              .toList();
          final bytes = rows.fold<int>(
            0,
            (sum, row) => sum + diskBytes(row['Size'] as String),
          );
          if (deploy == 2) usedAfterTwo = bytes;
          if (deploy == 3) {
            for (final entry in {
              'server': serverImages,
              'web': webImages,
            }.entries) {
              final images = await shell.run(
                'docker image ls -a --no-trunc -q --filter label=com.docker.compose.project=shop --filter label=com.docker.compose.service=${entry.key}',
              );
              expect(images.stdout.trim().split('\n').toSet(), {
                entry.value[1],
                entry.value[2],
              });
              final journal = await shell.run(
                'cat /state/deploy-run/${entry.key}.previous',
              );
              expect(journal.stdout.trim(), entry.value[1]);
            }
            expect(
              diskBytes(
                rows.singleWhere((row) => row['Type'] == 'Build Cache')['Size']
                    as String,
              ),
              lessThanOrEqualTo(1024 * 1024),
            );
            // Human sizes round and metadata varies; at most 1 MiB growth.
            expect(bytes, lessThanOrEqualTo(usedAfterTwo + 1024 * 1024));
          }
        }
        for (final image in [
          'second-server:latest',
          'shop-server:foreign',
          'shop-web:accessory',
          'postgres:fixture',
          'rustfs:fixture',
          'nginx:fixture',
          'certbot:fixture',
        ]) {
          expect(
            (await shell.run("docker image inspect '$image'")).ok,
            isTrue,
            reason: '$image must survive',
          );
        }
      },
    );
  }
}

int diskBytes(String size) {
  final match = RegExp(r'^([\d.]+)(B|kB|MB|GB)$').firstMatch(size)!;
  return (double.parse(match[1]!) *
          pow(1000, ['B', 'kB', 'MB', 'GB'].indexOf(match[2]!)))
      .round();
}

class EngineShell extends DwSshRunner {
  EngineShell(this.name) : super(host: 'isolated-engine', user: 'root');
  final String name;
  @override
  Future<DwSshResult> run(String command) async {
    final result = await Process.run('docker', [
      'exec',
      name,
      'sh',
      '-c',
      command,
    ]);
    return DwSshResult(
      exitCode: result.exitCode,
      stdout: result.stdout as String,
      stderr: result.stderr as String,
    );
  }

  @override
  Future<DwSshResult> runAs(String deployUser, String command) => run(command);
}
