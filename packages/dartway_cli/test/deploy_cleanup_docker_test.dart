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
      'unchanged deploy keeps its build cache (${containerd ? 'containerd' : 'classic'} store)',
      () async {
        final shell = await startEngine(containerd: containerd);
        final setup = await shell.run(r'''
set -e
mkdir -p /stack /state
cat >/stack/docker-compose.yml <<'YAML'
name: shop
services:
  server:
    build: .
    healthcheck:
      test: [CMD, test, -f, /payload]
      interval: 1s
      retries: 1
  web:
    build: .
YAML
cat >/stack/Dockerfile <<'DOCKER'
FROM busybox:1.37
COPY source /source
RUN dd if=/dev/urandom of=/payload bs=1M count=3
CMD ["sh", "-c", "if [ \"$DW_MIGRATE_ONLY\" = true ]; then exit 0; fi; trap 'exit 0' TERM; sleep 86400 & wait"]
DOCKER
echo unchanged >/stack/source
''');
        expect(setup.ok, isTrue, reason: setup.stderr);
        final runner = DwDeployRunner(
          ssh: shell,
          stack: stackFrom(extra: '  min_free_disk: 1MB\n'),
          appDir: '/stack',
          storeDir: '/state',
        );
        expect((await runner.build()).ok, isTrue);
        expect((await runner.replaceServer()).ok, isTrue);
        expect((await runner.startWeb()).ok, isTrue);
        final cleaned = await runner.cleanup();
        expect(cleaned.ok, isTrue, reason: cleaned.stderr);
        expect((await shell.run('rm -rf /state/deploy-run')).ok, isTrue);
        final second = await runner.build();
        expect(second.ok, isTrue, reason: second.stderr);
        final output = '${second.stdout}\n${second.stderr}';
        final cachedSteps = RegExp(
          r'#(\d+) \[(server|web) \d+/\d+\] (COPY|RUN) ',
        ).allMatches(output).toList();
        expect(cachedSteps, isNotEmpty, reason: output);
        for (final step in cachedSteps) {
          expect(output, contains('#${step[1]} CACHED'), reason: output);
        }
      },
    );

    test(
      'an interrupted build never becomes the rollback image (${containerd ? 'containerd' : 'classic'} store)',
      () async {
        final shell = await startEngine(containerd: containerd);
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
      retries: 1
  web:
    build: .
YAML
cat >/stack/Dockerfile <<'DOCKER'
FROM busybox:1.37
COPY health /health
CMD ["sh", "-c", "if [ \"$DW_MIGRATE_ONLY\" = true ]; then exit 0; fi; trap 'exit 0' TERM; sleep 86400 & wait"]
DOCKER
echo ok >/stack/health
''');
        expect(setup.ok, isTrue, reason: setup.stderr);
        final runner = DwDeployRunner(
          ssh: shell,
          stack: stackFrom(extra: '  min_free_disk: 1MB\n'),
          appDir: '/stack',
          storeDir: '/state',
        );
        expect((await runner.build()).ok, isTrue);
        expect((await runner.replaceServer()).ok, isTrue);
        final serving = await shell.run(
          "docker inspect -f '{{.Image}}' \"\$(cd /stack && docker compose ps -q server)\"",
        );
        expect(serving.ok, isTrue);
        // An earlier build moved the tag but failed before the server step
        // without a durable rollback pin; the original container still serves.
        expect(
          (await shell.run(
            'rm -rf /state/deploy-run; echo bad >/stack/health',
          )).ok,
          isTrue,
        );
        final interrupted = await shell.run(
          'cd /stack && docker compose build',
        );
        expect(interrupted.ok, isTrue, reason: interrupted.stderr);
        expect((await shell.run('rm -rf /state/deploy-run')).ok, isTrue);
        final fresh = await runner.build();
        if (!fresh.ok) {
          expect(
            fresh.stderr,
            contains('Cannot resolve the running server image'),
          );
          expect(
            (await shell.run('test ! -f /state/deploy-run/server.previous')).ok,
            isTrue,
          );
        } else {
          final failed = await runner.replaceServer();
          expect(failed.ok, isFalse);
          expect(
            failed.stderr,
            contains('the previous server is running again'),
          );
        }
        final recovered = await shell.run(
          "docker inspect -f '{{.Image}}' \"\$(cd /stack && docker compose ps -q server)\"",
        );
        expect(recovered.stdout.trim(), serving.stdout.trim());
        final healthy = await shell.run(
          '${DwDeployRunner.waitHealthyFunction(timeoutSeconds: 10)}\n'
          'dw_wait_healthy "\$(cd /stack && docker compose ps -q server)" rollback',
        );
        expect(healthy.ok, isTrue, reason: healthy.stderr);
      },
    );

    test(
      'three deploys bound images and cache (${containerd ? 'containerd' : 'classic'} store)',
      () async {
        final shell = await startEngine(containerd: containerd);
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
            extra: '  build_cache_keep: 4MB\n  min_free_disk: 1MB\n',
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
          // Kept images plus the current source exceed the 4 MB budget. Preserve their
          // keys and warn; the private cache must still respect the budget.
          expect(
            cleaned.exitCode,
            1,
            reason: '${cleaned.stdout}\n${cleaned.stderr}',
          );
          expect(cleaned.stderr, contains('Docker retains cache references'));
          expect(DwDeployRunner.cleanupReport(cleaned), isNotNull);
          final privateCache = await shell.run(
            "docker buildx du --builder default --format '{{if not .Shared}}{{.Size}}{{end}}'",
          );
          expect(privateCache.ok, isTrue, reason: privateCache.stderr);
          final privateBytes = privateCache.stdout
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .fold<int>(0, (sum, line) => sum + diskBytes(line.trim()));
          expect(
            privateBytes,
            lessThanOrEqualTo(4 * 1024 * 1024),
            reason: privateCache.stdout,
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
    test('failed migration keeps the previous server serving '
        '(${containerd ? 'containerd' : 'classic'} store)', () async {
      final shell = await startEngine(containerd: containerd);
      var monorepo = Directory.current.absolute;
      while (!Directory('${monorepo.path}/packages').existsSync()) {
        if (monorepo.parent.path == monorepo.path) {
          throw StateError('not inside the monorepo');
        }
        monorepo = monorepo.parent;
      }
      const packages = [
        'dartway_core_server',
        'dartway_core_shared',
        'dartway_client',
        'dartway_orm',
      ];
      expect((await shell.run('mkdir -p /stack/packages /state')).ok, isTrue);
      for (final package in packages) {
        expect(
          (await shell.run('mkdir -p /stack/packages/$package')).ok,
          isTrue,
        );
        for (final source in ['lib', 'pubspec.yaml']) {
          final copied = await Process.run('docker', [
            'cp',
            '${monorepo.path}/packages/$package/$source',
            '${shell.name}:/stack/packages/$package/$source',
          ]);
          expect(copied.exitCode, 0, reason: '${copied.stderr}');
        }
      }
      final copied = await Process.run('docker', [
        'cp',
        '${monorepo.path}/packages/dartway_cli/test/support/deploy_rollback_server.dart',
        '${shell.name}:/stack/server.dart',
      ]);
      expect(copied.exitCode, 0, reason: '${copied.stderr}');
      final setup = await shell.run("""
set -e
cat >/stack/pubspec.yaml <<'YAML'
name: deploy_rollback_fixture
environment:
  sdk: ^3.11.0
dependencies:
  dartway_core_server:
    path: packages/dartway_core_server
dependency_overrides:
${packages.map((package) => '  $package:\n    path: packages/$package').join('\n')}
YAML
sed -i '/^resolution: workspace/d' /stack/packages/*/pubspec.yaml
cat >/stack/docker-compose.yml <<'YAML'
name: shop
services:
  postgres:
    image: postgres:17-alpine
    environment:
      POSTGRES_PASSWORD: fixture
    healthcheck:
      test: [CMD-SHELL, 'pg_isready -U postgres']
      interval: 1s
      timeout: 5s
      retries: 30
  server:
    build: .
    environment:
      DW_DATABASE_HOST: postgres
      DW_DATABASE_NAME: postgres
      DW_DATABASE_USER: postgres
      DW_DATABASE_PASSWORD: fixture
      DW_DATABASE_SSL: 'false'
    healthcheck:
      test: [CMD, /server, health, localhost]
      interval: 1s
      timeout: 5s
      retries: 10
  web:
    image: busybox:1.37
YAML
cat >/stack/Dockerfile <<'DOCKER'
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.yaml .
COPY packages packages
RUN dart pub get
COPY server.dart .
RUN dart compile exe server.dart -o /server
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /server /server
COPY migration /migration
CMD ["/server"]
DOCKER
echo ok >/stack/migration
cd /stack
docker compose up -d --wait postgres
""");
      expect(setup.ok, isTrue, reason: '${setup.stdout}\n${setup.stderr}');
      final runner = DwDeployRunner(
        ssh: shell,
        stack: stackFrom(extra: '  min_free_disk: 1MB\n'),
        appDir: '/stack',
        storeDir: '/state',
      );
      final firstBuild = await runner.build();
      expect(firstBuild.ok, isTrue, reason: firstBuild.stderr);
      final firstServer = await runner.replaceServer();
      expect(firstServer.ok, isTrue, reason: firstServer.stderr);
      final previous = await shell.run(
        "docker inspect -f '{{.Image}}' \"\$(cd /stack && docker compose ps -q server)\"",
      );
      expect(previous.ok, isTrue, reason: previous.stderr);
      expect(
        (await shell.run(
          'rm -rf /state/deploy-run; echo fail >/stack/migration',
        )).ok,
        isTrue,
      );
      final failingBuild = await runner.build();
      expect(failingBuild.ok, isTrue, reason: failingBuild.stderr);
      final failed = await runner.replaceServer();
      final output = '${failed.stdout}\n${failed.stderr}';
      expect(failed.exitCode, 1, reason: output);
      expect(
        output,
        contains('relation "deliberately_missing" does not exist'),
      );
      expect(output, contains('they rolled back'));
      // Check the transaction's actual effects, independently of its log.
      final rolledBack = await shell.run("""
cd /stack && docker compose exec -T postgres psql -U postgres -Atc "SELECT to_regclass('rollback_marker') IS NULL, (SELECT count(*) FROM dw_migrations WHERE namespace = 'app')"
""");
      expect(rolledBack.ok, isTrue, reason: rolledBack.stderr);
      expect(rolledBack.stdout.trim(), 't|0');
      expect(
        output,
        isNot(contains('could not be started again')),
        reason: output,
      );
      expect(output, contains('the previous server is running again'));
      final healthy = await shell.run(
        '${DwDeployRunner.waitHealthyFunction(timeoutSeconds: 30)}\n'
        'dw_wait_healthy "\$(cd /stack && docker compose ps -q server)" rollback',
      );
      expect(healthy.ok, isTrue, reason: healthy.stderr);
      final serving = await shell.run(
        "docker inspect -f '{{.Image}}' \"\$(cd /stack && docker compose ps -q server)\"",
      );
      expect(serving.ok, isTrue, reason: serving.stderr);
      expect(serving.stdout.trim(), previous.stdout.trim());
      // A separate client container must receive health and a real hello
      // through /dw/live from the recovered server, without a manual start.
      final answers = await shell.run(
        'cd /stack && docker compose run --rm --no-deps -T server /server probe server',
      );
      expect(
        answers.ok,
        isTrue,
        reason: '${answers.stdout}\n${answers.stderr}',
      );
      expect(answers.stdout, contains('/health 200'));
      expect(answers.stdout, contains('/dw/live hello'));
    });
  }
}

Future<EngineShell> startEngine({required bool containerd}) async {
  final name = 'dw-cleanup-${DateTime.now().microsecondsSinceEpoch}';
  Future<ProcessResult> host(List<String> args) => Process.run('docker', args);
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
  expect(ready!.ok, isTrue, reason: '${(await host(['logs', name])).stderr}');
  final driver = await shell.run("docker info -f '{{json .DriverStatus}}'");
  expect(driver.stdout.contains('io.containerd.snapshotter.v1'), containerd);
  return shell;
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
