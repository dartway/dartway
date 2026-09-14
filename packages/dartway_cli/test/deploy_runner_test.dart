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
        'render-env',
        'compose-config',
        'build',
        'storage',
        'database',
        'server-candidate',
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

    // The previous server keeps serving while a candidate that cannot migrate
    // or start says why.
    test('the new server proves itself before it replaces the old one', () {
      before('database', 'server-candidate');
      before('server-candidate', 'server');
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
      await runner.startCandidate();
      await runner.replaceServer();
      await runner.startWeb();
      await runner.startStack();
      await runner.restartProxy();

      expect(ssh.issued, hasLength(8));
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
