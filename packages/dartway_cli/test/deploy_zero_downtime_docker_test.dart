@Tags(['docker'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dartway_cli/src/deploy/deploy_runner.dart';
import 'package:dartway_cli/src/deploy/deploy_stats.dart';
import 'package:dartway_cli/src/deploy/renderer.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

/// A deploy under a request loop answers no request with an error.
///
/// The proxy is the pinned nginx image with the configuration the renderer
/// writes, the server and the web app are replaced by the deploy's own steps
/// — the new container beside the serving one, the old one stopped after it
/// — and a client inside the stack's network asks both through the proxy,
/// back to back, for the whole time. The server and the web app are a
/// static file server each: what is proven is the proxy and the
/// replacement, not what a server answers.
void main() {
  final random = Random.secure();
  final project =
      'dwzero${List.generate(6, (_) => random.nextInt(36).toRadixString(36)).join()}';
  const port = 8088;
  late Directory dir;
  final shell = LocalShell();

  Future<DwSshResult> sh(String script) async {
    final result = await shell.run(script);
    expect(
      result.ok,
      isTrue,
      reason: '$script\n${result.stdout}\n${result.stderr}',
    );
    return result;
  }

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('dw_zero_downtime_');
    final stack = stackFrom(front: const DwPlainHttpFront(port));
    File(
      p.join(dir.path, 'nginx.conf'),
    ).writeAsStringSync(DwStackRenderer(stack: stack).nginxFile);
    for (final include in ['http', 'api', 'app']) {
      Directory(
        p.join(dir.path, 'nginx.d', include),
      ).createSync(recursive: true);
    }
    // A file server for each, answering with the build's version. nginx,
    // because it stops the way a DartWay server does — SIGQUIT, the
    // image's stop signal, stops accepting and answers what is in flight
    // — and because the web image of a project is one.
    String dockerfile(int listen) =>
        '''
FROM ${DwStack.nginxImage}
RUN printf 'server { listen $listen; root /www; }\\n' >/etc/nginx/conf.d/default.conf
COPY version /www/health
COPY version /www/dw/GetVersion
COPY version /www/index.html
CMD ["sh", "-c", "if [ \\"\$DW_MIGRATE_ONLY\\" = true ]; then echo migrated; exit 0; fi; exec nginx -g 'daemon off;'"]
''';
    File(
      p.join(dir.path, 'server.Dockerfile'),
    ).writeAsStringSync(dockerfile(DwStack.serverPort));
    File(p.join(dir.path, 'web.Dockerfile')).writeAsStringSync(dockerfile(80));
    String health(int listen) =>
        '''
    healthcheck:
      test: ["CMD", "wget", "-q", "-O", "/dev/null", "http://127.0.0.1:$listen/health"]
      interval: 1s
      timeout: 2s
      retries: 3
''';
    File(p.join(dir.path, 'docker-compose.yml')).writeAsStringSync('''
name: $project
services:
  ${DwStack.serverService}:
    build: {context: ., dockerfile: server.Dockerfile}
${health(DwStack.serverPort)}
  ${DwStack.webService}:
    build: {context: ., dockerfile: web.Dockerfile}
${health(80)}
  ${DwStack.nginxService}:
    image: ${DwStack.nginxImage}
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./nginx.d:/etc/nginx/dartway:ro
    depends_on: [${DwStack.serverService}, ${DwStack.webService}]
    networks: [default, routed]
networks:
  routed:
    name: ${project}_routed
''');
    File(p.join(dir.path, 'version')).writeAsStringSync('v1\n');
    await sh(
      "cd '${dir.path}' && docker compose build -q && docker compose up -d --wait",
    );
    for (final service in ['server', 'web']) {
      await sh(
        "cd '${dir.path}' && docker network connect --alias dw-$service '${project}_routed' \$(docker compose ps -q $service)",
      );
    }
  });

  tearDown(() async {
    await shell.run(
      "docker rm -f '$project-loop' >/dev/null 2>&1; "
      "docker volume rm '$project-control' >/dev/null 2>&1; "
      "cd '${dir.path}' && docker compose down -v --rmi local --remove-orphans >/dev/null 2>&1",
    );
    dir.deleteSync(recursive: true);
  });

  test('a deploy under a request loop answers every request', () async {
    // Back to back, both hosts, until told to stop: every answer's body (the
    // version) or its error, one line each.
    await sh('''
docker volume create '$project-control' >/dev/null
docker run -d --name '$project-loop' --network '${project}_default' -v '$project-control:/control' busybox:1.37 sh -c '
  while [ ! -f /control/stop ]; do
    for host in api.example.com app.example.com; do
      path=/dw/GetVersion; [ "\$host" = app.example.com ] && path=/
      if answer=\$(wget -q -T 10 -O - --header "Host: \$host" "http://${DwStack.nginxService}:$port\$path" 2>&1); then
        echo "ok \$host \$answer"
      else
        echo "FAILED \$host \$answer"
      fi
    done
  done' >/dev/null
''');
    final runner = DwDeployRunner(
      ssh: shell,
      stack: stackFrom(
        front: const DwPlainHttpFront(port),
        extra: '  project: $project\n  min_free_disk: 1MB\n',
      ),
      appDir: dir.path,
      storeDir: p.join(dir.path, 'state'),
    );
    // Two deploys, so the second replaces a container the first one started.
    for (final version in ['v2', 'v3']) {
      await Future<void>.delayed(const Duration(seconds: 2));
      File(p.join(dir.path, 'version')).writeAsStringSync('$version\n');
      expect((await runner.beginLocalDeployment()).ok, isTrue);
      for (final step in [
        runner.build,
        runner.replaceServer,
        runner.startWeb,
        runner.startStack,
        runner.reloadProxy,
      ]) {
        final result = await step();
        expect(result.ok, isTrue, reason: '${result.stdout}\n${result.stderr}');
      }
    }
    await Future<void>.delayed(const Duration(seconds: 2));
    await sh('''
docker run --rm -v '$project-control:/control' busybox:1.37 touch /control/stop
docker wait '$project-loop' >/dev/null
''');
    final lines = (await sh(
      "docker logs '$project-loop'",
    )).stdout.split('\n').where((line) => line.isNotEmpty).toList();
    final failed = lines.where((line) => !line.startsWith('ok ')).toList();
    final served = {
      for (final line in lines.where((line) => line.startsWith('ok ')))
        line.split(' ').last,
    };
    printOnFailure('${lines.length} requests');
    // What the proxy said about any of them, beside its access log.
    printOnFailure(
      (await shell.run(
        "cd '${dir.path}' && docker compose logs --no-log-prefix "
        "${DwStack.nginxService} 2>&1 | grep -v '^{' | grep -v 'notice'",
      )).stdout,
    );
    printOnFailure(
      (await shell.run(
        "cd '${dir.path}' && docker compose logs --no-log-prefix "
        "${DwStack.nginxService} 2>&1 | grep '^{' | grep -v '\"status\":200'",
      )).stdout,
    );
    expect(failed, isEmpty, reason: '${failed.length} of ${lines.length}');
    // And none waited long: a request that met an address just gone waits
    // one connect timeout (1 s) and is answered by the next address.
    final times = [
      for (final line in (await sh(
        "cd '${dir.path}' && docker compose logs --no-log-prefix "
        '${DwStack.nginxService}',
      )).stdout.split('\n'))
        if (line.startsWith('{'))
          ((jsonDecode(line) as Map<String, Object?>)['request_time'] as num)
              .toDouble(),
    ]..sort();
    printOnFailure('slowest: ${times.reversed.take(5).toList()}');
    expect(times, hasLength(greaterThan(200)));
    expect(times.last, lessThan(2.5));
    expect(served, containsAll(['v1', 'v2', 'v3']));
    expect(lines.length, greaterThan(200));
    // `deploy stats` reads the same log: every call it answered, timed.
    final stats = DwDeployStats(
      ssh: shell,
      stack: stackFrom(extra: '  project: $project\n  database: external\n'),
      appDir: dir.path,
    );
    final report = await stats.read(hours: 1);
    final calls = lines.where((line) => line.startsWith('ok api.')).length;
    expect(report.calls.map((row) => row.call), ['GetVersion']);
    expect(report.calls.single.count, calls);
    expect(report.calls.single.serverErrors, 0);
    expect(report.calls.single.p95, lessThanOrEqualTo(times.last));
    expect(
      stats.format(report, hours: 1),
      contains(RegExp(r'GetVersion +\d+ +\d+ +\d+ +\d+ +0\n')),
    );
    // One container each is left, of the last build.
    final remaining = await sh(
      "cd '${dir.path}' && docker compose ps -a -q ${DwStack.serverService} | wc -l",
    );
    expect(remaining.stdout.trim(), '1');
  }, timeout: const Timeout(Duration(minutes: 5)));
  test(
    'a listening but unhealthy replacement receives zero routed calls',
    () async {
      // Keep the port open long enough for Docker DNS to refresh while health
      // stays 503. A routing bug returns vbad even though rollout fails.
      final dockerfile = File(p.join(dir.path, 'server.Dockerfile'));
      dockerfile.writeAsStringSync(
        dockerfile.readAsStringSync().replaceFirst(
          'root /www;',
          'root /www; location = /health { return 503; }',
        ),
      );
      final compose = File(p.join(dir.path, 'docker-compose.yml'));
      compose.writeAsStringSync(
        compose.readAsStringSync().replaceFirst(
          '      retries: 3',
          '      retries: 3\n      start_period: 8s',
        ),
      );
      File(p.join(dir.path, 'version')).writeAsStringSync('vbad\n');
      final runner = DwDeployRunner(
        ssh: shell,
        stack: stackFrom(extra: '  project: $project\n  min_free_disk: 1MB\n'),
        appDir: dir.path,
        storeDir: p.join(dir.path, 'state'),
      );
      await runner.beginLocalDeployment();
      final built = await runner.build();
      expect(built.ok, isTrue, reason: built.stderr);
      await sh('''
docker volume create '$project-control' >/dev/null
docker run -d --name '$project-loop' --network '${project}_default' -v '$project-control:/control' busybox:1.37 sh -c '
  while [ ! -f /control/stop ]; do
    wget -q -T 2 -O - --header "Host: api.example.com" "http://nginx:$port/dw/GetVersion" || echo FAILED
    sleep 0.05
  done' >/dev/null
''');
      final replaced = await runner.replaceServer();
      expect(replaced.ok, isFalse);
      expect(replaced.stderr, contains('previous server keeps serving'));
      await sh('''
docker run --rm -v '$project-control:/control' busybox:1.37 touch /control/stop
docker wait '$project-loop' >/dev/null
''');
      final responses = (await sh("docker logs '$project-loop'")).stdout;
      expect(responses, contains('v1'));
      expect(
        responses,
        isNot(contains('vbad')),
        reason: 'an unhealthy server must never receive routed calls',
      );
      expect(responses, isNot(contains('FAILED')));
      final after = await sh(
        "docker run --rm --network '${project}_default' busybox:1.37 wget -q -O - --header 'Host: api.example.com' http://nginx:$port/dw/GetVersion",
      );
      expect(after.stdout.trim(), 'v1');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
