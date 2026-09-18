import 'dart:io';

import 'package:dartway_cli/src/deploy/compose_files.dart';
import 'package:dartway_cli/src/deploy/deploy_runner.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

List<String> _ids(DwDeployRunner runner) =>
    runner.steps(skipGitUpdate: false).map((step) => step.id).toList();

void main() {
  group('the order of a deployment', () {
    final runner = DwDeployRunner(
      ssh: RecordingSsh(),
      stack: stackVariants()['minio and a site']!,
    );
    final ids = _ids(runner);

    void before(String first, String second) => expect(
      ids.indexOf(first),
      lessThan(ids.indexOf(second)),
      reason: '$first must run before $second: $ids',
    );

    test('is the whole sequence, in order', () {
      expect(ids, [
        'update-checkout',
        'bridge-override',
        'render-stack',
        'render-env',
        'compose-config',
        'build',
        'storage',
        'database',
        'server',
        'web',
        'stack',
        'check-upstreams',
        'nginx-test',
        'certificate',
        'restart-proxy',
      ]);
    });

    test('the environment is rendered before Compose reads the stack', () {
      before('render-env', 'compose-config');
      before('compose-config', 'build');
    });

    // The defect this order prevents: a compose file rendered by an older CLI
    // met a build argument it did not carry, and the deploy failed inside
    // `docker build` pointing at the project's Dockerfile.
    test('the stack is rendered before anything reads it', () {
      before('update-checkout', 'render-stack');
      before('render-stack', 'render-env');
      before('render-stack', 'compose-config');
      before('render-stack', 'build');
    });

    // Migrations need the database, and the proxy is pointed at the server
    // only once it is the new one.
    test('the server is replaced after the database, before the web app', () {
      before('database', 'server');
      before('server', 'web');
    });

    test('the proxy is checked, then certified, then restarted', () {
      before('stack', 'check-upstreams');
      before('check-upstreams', 'nginx-test');
      before('nginx-test', 'certificate');
      before('certificate', 'restart-proxy');
    });

    test('no storage step without MinIO, no certificate without TLS', () {
      final plain = _ids(
        DwDeployRunner(
          ssh: RecordingSsh(),
          stack: stackFrom(front: const DwPlainHttpFront(18080)),
        ),
      );
      expect(plain, isNot(contains('storage')));
      expect(plain, isNot(contains('certificate')));
    });
  });

  group('the commands a deployment sends', () {
    test('every Compose call names the project override', () async {
      final ssh = RecordingSsh();
      final runner = DwDeployRunner(ssh: ssh, stack: stackFrom());
      await runner.checkComposeConfig();
      await runner.build();
      await runner.startDatabase();
      await runner.replaceServer();
      await runner.startWeb();
      await runner.startStack();
      await runner.restartProxy();

      expect(ssh.issued, hasLength(7));
      for (final command in ssh.issued) {
        expect(command, contains("cd '/home/deployer/shop'"));
        expect(command, contains(DwComposeFiles.projectOverride));
      }
    });

    test('the certificate covers every served host under one name', () async {
      final ssh = RecordingSsh();
      await DwDeployRunner(
        ssh: ssh,
        stack: stackVariants()['minio and a site']!,
      ).issueCertificate();
      final command = ssh.issued.single;
      expect(command, contains("--cert-name 'api.example.com'"));
      for (final domain in [
        'api.example.com',
        'app.example.com',
        'example.com',
        'files.example.com',
      ]) {
        expect(command, contains("-d '$domain'"));
      }
      // A lineage certbot already manages is left alone; `-s` because a failed
      // attempt leaves the renewal file behind empty.
      expect(
        command,
        contains('test -s /etc/letsencrypt/renewal/api.example.com.conf'),
      );
    });

    group('replacing the server', () {
      late Directory temp;
      late File calls;

      setUp(() {
        temp = Directory.systemTemp.createTempSync('dw_replace_server_');
        calls = File(p.join(temp.path, 'calls'));
        Directory(p.join(temp.path, 'shop')).createSync();
      });
      tearDown(() => temp.deleteSync(recursive: true));

      /// Runs the step against a `docker` that answers as a server of
      /// [image] would, and answers the result and the docker calls made.
      Future<(DwSshResult, List<String>)> replace({
        bool running = true,
        bool migrationFails = false,
        bool healthy = true,
      }) async {
        final bin = Directory(p.join(temp.path, 'bin'))..createSync();
        final docker = File(p.join(bin.path, 'docker'))
          ..writeAsStringSync('''
#!/bin/sh
echo "\$*" | sed 's/-f [^ ]*//g; s/  */ /g' >> '${calls.path}'
case "\$*" in
  *" ps -aq server"*) ${running ? 'echo old-container' : 'true'} ;;
  *" ps -q server"*) echo new-container ;;
  *"{{.Config.Image}}"*) echo shop-server ;;
  "inspect -f {{.Image}}"*) echo sha256:previous ;;
  *" run --rm --no-deps -T -e DW_MIGRATE_ONLY=true server"*) ${migrationFails ? 'echo "migration 42 failed" >&2; exit 1' : 'echo migrated'} ;;
  *"{{.State.Status}}"*) echo "running ${healthy ? 'healthy' : 'unhealthy'} 0 0" ;;
esac
exit 0
''');
        Process.runSync('chmod', ['+x', docker.path]);
        final result = await DwDeployRunner(
          ssh: LocalShell(
            environment: {
              'PATH': '${bin.path}:${Platform.environment['PATH']}',
            },
          ),
          stack: stackFrom(),
          appDir: p.join(temp.path, 'shop'),
        ).replaceServer();
        final issued = calls.existsSync()
            ? calls.readAsLinesSync().map((line) => line.trim()).toList()
            : <String>[];
        return (result, issued);
      }

      int at(List<String> calls, String fragment) =>
          calls.indexWhere((call) => call.contains(fragment));

      test('stops the old one, migrates in a one-off run, then starts the new '
          'one — never two at once', () async {
        final (result, calls) = await replace();
        expect(result.ok, isTrue, reason: result.stderr);
        final stop = at(calls, 'stop -t 45 server');
        final migrate = at(calls, 'DW_MIGRATE_ONLY=true server');
        final start = at(calls, 'up -d --no-deps server');
        expect(stop, isNot(-1));
        expect(migrate, greaterThan(stop));
        expect(start, greaterThan(migrate));
        expect(at(calls, 'image tag'), -1, reason: 'nothing to roll back');
      });

      test('a failed migration starts the previous image again', () async {
        final (result, calls) = await replace(migrationFails: true);
        expect(result.ok, isFalse);
        expect(result.stderr, contains('migration 42 failed'));
        expect(result.stderr, contains('previous server is running again'));
        final tag = at(calls, 'image tag sha256:previous shop-server');
        expect(tag, greaterThan(at(calls, 'DW_MIGRATE_ONLY=true')));
        expect(at(calls.sublist(tag), 'up -d --no-deps server'), isNot(-1));
      });

      test('a new server that does not become healthy is replaced by the '
          'previous one, and the message names the schema', () async {
        final (result, calls) = await replace(healthy: false);
        expect(result.ok, isFalse);
        expect(result.stderr, contains('previous code runs on the new schema'));
        expect(at(calls, 'image tag sha256:previous shop-server'), isNot(-1));
      });

      test(
        'a first deployment has nothing to stop and nothing to go back to',
        () async {
          final (result, calls) = await replace(running: false);
          expect(result.ok, isTrue, reason: result.stderr);
          expect(at(calls, 'stop -t 45'), -1);
          expect(at(calls, 'DW_MIGRATE_ONLY=true server'), isNot(-1));
        },
      );
    });

    group('a certificate certbot already manages', () {
      late Directory temp;
      late File calls;

      setUp(() {
        temp = Directory.systemTemp.createTempSync('dw_certificate_');
        calls = File(p.join(temp.path, 'calls'));
        Directory(p.join(temp.path, 'shop')).createSync();
      });
      tearDown(() => temp.deleteSync(recursive: true));

      /// Runs the step against a `docker` that answers as certbot managing a
      /// lineage for [covered], and answers what it was asked to run.
      Future<(DwSshResult, List<String>)> issue(String covered) async {
        final bin = Directory(p.join(temp.path, 'bin'))..createSync();
        final docker = File(p.join(bin.path, 'docker'))
          ..writeAsStringSync('''
#!/bin/sh
last=""; for arg in "\$@"; do last="\$arg"; done
printf '%s\\n---\\n' "\$last" >> '${calls.path}'
case "\$last" in
  *"certbot certificates"*) printf 'Found the following certs:\\n  Certificate Name: api.example.com\\n    Domains: $covered\\n' ;;
esac
''');
        Process.runSync('chmod', ['+x', docker.path]);
        final runner = DwDeployRunner(
          ssh: LocalShell(
            environment: {
              'PATH': '${bin.path}:${Platform.environment['PATH']}',
            },
          ),
          stack: stackVariants()['minio and a site']!,
          appDir: p.join(temp.path, 'shop'),
        );
        final result = await runner.issueCertificate();
        return (
          result,
          calls
              .readAsStringSync()
              .split('\n---\n')
              .where((call) => call.trim().isNotEmpty)
              .toList(),
        );
      }

      test('covering every served host is left alone', () async {
        final (result, calls) = await issue(
          'api.example.com app.example.com example.com files.example.com',
        );
        expect(result.ok, isTrue, reason: result.stderr);
        expect(result.stdout, contains('already manages api.example.com'));
        expect(calls, hasLength(1));
      });

      test('is extended to a host added since, keeping its lineage', () async {
        final (result, calls) = await issue(
          'api.example.com app.example.com example.com',
        );
        expect(result.ok, isTrue, reason: result.stderr);
        expect(
          result.stdout,
          contains('extending api.example.com to: files.example.com'),
        );
        expect(calls, hasLength(2));
        expect(calls.last, contains('--expand'));
        expect(calls.last, contains("-d 'files.example.com'"));
        expect(calls.last, isNot(contains('rm -rf')));
      });
    });

    test('the environment is rendered with every required secret', () async {
      final ssh = RecordingSsh();
      await DwDeployRunner(
        ssh: ssh,
        stack: stackVariants()['external storage, external site, files']!,
      ).renderEnvironment();
      for (final key in [
        'DW_DATABASE_PASSWORD',
        'DW_STORAGE_ENDPOINT',
        'DW_STORAGE_SECRET_KEY',
        'SMS_API_TOKEN',
      ]) {
        expect(ssh.issued.single, contains(key));
      }
    });
  });

  group('the upstream guard before the proxy restart', () {
    test(
      'asks the server for the applied stack and the rendered config',
      () async {
        final ssh = RecordingSsh();
        await DwDeployRunner(ssh: ssh, stack: stackFrom()).checkUpstreams();
        expect(ssh.issued.single, contains('config --services'));
        expect(ssh.issued.single, contains('cat nginx.conf'));
      },
    );

    test('a stack answering every upstream is not a finding', () {
      expect(
        DwDeployRunner.upstreamVerdict(
          const DwSshResult(
            exitCode: 0,
            stdout:
                'server\nweb\n--dw-nginx-d--\nproxy_pass http://server:8080;\n'
                'proxy_pass http://web:80;\n',
            stderr: '',
          ),
        ),
        isNull,
      );
    });

    test('an upstream nothing declares stops the restart and says why', () {
      final verdict = DwDeployRunner.upstreamVerdict(
        const DwSshResult(
          exitCode: 0,
          stdout: 'server\n--dw-nginx-d--\nproxy_pass http://minio:9000;\n',
          stderr: '',
        ),
      );
      expect(verdict, contains('minio'));
      expect(verdict, contains('Nothing has been restarted'));
    });

    test('an answer missing its second half is a finding, not a pass', () {
      expect(
        DwDeployRunner.upstreamVerdict(
          const DwSshResult(exitCode: 0, stdout: 'server\n', stderr: ''),
        ),
        isNotNull,
      );
    });
  });

  // The waiter is shell run on the server; it is run here against a stub
  // `docker` that answers what a container in each state answers.
  group('waiting for a healthy container', () {
    late Directory bin;

    setUp(() {
      bin = Directory.systemTemp.createTempSync('dw_wait_');
    });
    tearDown(() => bin.deleteSync(recursive: true));

    Future<DwSshResult> waitFor(String inspect, {int timeout = 4}) {
      File(p.join(bin.path, 'docker'))
        ..writeAsStringSync('''
#!/bin/sh
case "\$1" in
  inspect) echo "$inspect" ;;
  logs) echo "Migration m20260914 failed: column already exists" ;;
esac
''')
        ..createSync();
      Process.runSync('chmod', ['+x', p.join(bin.path, 'docker')]);
      return LocalShell(
        environment: {'PATH': '${bin.path}:${Platform.environment['PATH']}'},
      ).run(
        '${DwDeployRunner.waitHealthyFunction(timeoutSeconds: timeout)}\n'
        "dw_wait_healthy abc 'the new server'",
      );
    }

    test('healthy is success', () async {
      final result = await waitFor('running healthy 0 0');
      expect(result.ok, isTrue, reason: result.stderr);
      expect(result.stdout, contains('the new server is healthy'));
    });

    test('an exit is a failure that prints the server\'s own log', () async {
      final result = await waitFor('exited unhealthy 0 1');
      expect(result.ok, isFalse);
      expect(result.stderr, contains('exited (code 1)'));
      expect(result.stderr, contains('column already exists'));
    });

    test('a restart loop is an exit too', () async {
      final result = await waitFor('running starting 2 1');
      expect(result.ok, isFalse);
      expect(result.stderr, contains('exited'));
    });

    test('no healthcheck means nothing can say it is serving', () async {
      final result = await waitFor('running none 0 0');
      expect(result.ok, isFalse);
      expect(result.stderr, contains('no healthcheck'));
    });

    test('still starting at the deadline is a failure with the log', () async {
      final result = await waitFor('running starting 0 0', timeout: 1);
      expect(result.ok, isFalse);
      expect(result.stderr, contains('not healthy within 1 s'));
      expect(result.stderr, contains('column already exists'));
    });
  });

  group('rendering the stack on every deploy', () {
    late Directory temp;
    late String appDir;
    late DwDeployRunner runner;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('dw_render_stack_');
      appDir = p.join(temp.path, 'shop');
      Directory(appDir).createSync(recursive: true);
      runner = DwDeployRunner(
        ssh: LocalShell(),
        stack: stackVariants()['minio and a site']!,
        appDir: appDir,
      );
    });
    tearDown(() => temp.deleteSync(recursive: true));

    File composeFile() => File(p.join(appDir, DwComposeFiles.rendered));
    File nginxFile() => File(p.join(appDir, 'nginx.conf'));

    test('writes both files where there were none, and says so', () async {
      final result = await runner.renderStack();
      expect(result.ok, isTrue, reason: result.stderr);
      expect(result.stdout, contains('docker-compose.yml: rendered again'));
      expect(result.stdout, contains('nginx.conf: rendered again'));
      expect(composeFile().readAsStringSync(), contains('services:'));
      expect(nginxFile().readAsStringSync(), contains('server {'));
      for (final name in ['http', 'api', 'app']) {
        expect(Directory(p.join(appDir, 'nginx.d', name)).existsSync(), isTrue);
      }
    });

    test('a second run changes nothing and says that too: a routine push must '
        'not read as an infrastructure change', () async {
      await runner.renderStack();
      final result = await runner.renderStack();
      expect(result.stdout, contains('docker-compose.yml: unchanged'));
      expect(result.stdout, contains('nginx.conf: unchanged'));
    });

    test('a file rendered by an older version is replaced — the defect this '
        'step exists for', () async {
      composeFile().writeAsStringSync('# rendered before the build arg existed\n');
      final result = await runner.renderStack();
      expect(result.stdout, contains('docker-compose.yml: rendered again'));
      expect(
        composeFile().readAsStringSync(),
        contains('services:'),
        reason: 'the stale file is gone, not appended to',
      );
    });

    test('keeps the file itself, not just its name: the proxy has its '
        'configuration bind-mounted', () async {
      await runner.renderStack();
      // `ls -i` prints the inode on every Unix; `stat` spells its flags
      // differently on macOS and on Linux.
      String inode() => (Process.runSync('ls', ['-i', nginxFile().path]).stdout
              as String)
          .trim()
          .split(RegExp(r'\s+'))
          .first;
      final before = inode();
      nginxFile().writeAsStringSync('# stale\n');
      await runner.renderStack();
      expect(inode(), before, reason: 'a mv would swap the inode');
    });

    test('leaves nothing behind in the checkout', () async {
      await runner.renderStack();
      expect(
        Directory(appDir)
            .listSync()
            .map((e) => p.basename(e.path))
            .where((name) => name.startsWith('.dw') || name.contains('tmp')),
        isEmpty,
      );
    });
  });

  group('bridging a bare docker compose to the project override', () {
    late Directory checkout;
    final ssh = LocalShell();

    setUp(() {
      checkout = Directory.systemTemp.createTempSync('dw_bridge_');
    });
    tearDown(() => checkout.deleteSync(recursive: true));

    File file(String relative) => File(p.join(checkout.path, relative));

    Future<DwSshResult> bridge() =>
        ssh.run(DwComposeFiles.bridgeIn(checkout.path));

    test('runs after the checkout update, not before it', () {
      final ids = _ids(DwDeployRunner(ssh: RecordingSsh(), stack: stackFrom()));
      expect(
        ids.indexOf('bridge-override'),
        greaterThan(ids.indexOf('update-checkout')),
      );
    });

    test(
      'writes the bridge, keeps a foreign file, and is idempotent',
      () async {
        file(DwComposeFiles.projectOverride)
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('services: {}\n');
        file(DwComposeFiles.autoLoaded).writeAsStringSync('stale copy\n');

        final first = await bridge();
        expect(first.ok, isTrue, reason: first.stderr);
        expect(
          file(DwComposeFiles.retiredCopy).readAsStringSync(),
          'stale copy\n',
        );
        final written = file(DwComposeFiles.autoLoaded).readAsStringSync();
        expect(written, contains(DwComposeFiles.bridgeMarker));
        expect(written, contains('- ${DwComposeFiles.projectOverride}'));

        final second = await bridge();
        expect(second.ok, isTrue);
        expect(second.stdout.trim(), isEmpty);
      },
    );

    test(
      'refuses when the override is gone and the file is not ours',
      () async {
        file(
          DwComposeFiles.autoLoaded,
        ).writeAsStringSync('services:\n  minio: {}\n');
        final result = await bridge();
        expect(result.ok, isFalse);
        expect(file(DwComposeFiles.autoLoaded).existsSync(), isTrue);
      },
    );

    test('removes its own bridge once the override is gone', () async {
      file(DwComposeFiles.projectOverride)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('services: {}\n');
      await bridge();
      file(DwComposeFiles.projectOverride).deleteSync();
      final result = await bridge();
      expect(result.ok, isTrue);
      expect(file(DwComposeFiles.autoLoaded).existsSync(), isFalse);
    });

    test('a checkout with neither file is left alone', () async {
      final result = await bridge();
      expect(result.ok, isTrue);
      expect(checkout.listSync(), isEmpty);
    });
  });
}
