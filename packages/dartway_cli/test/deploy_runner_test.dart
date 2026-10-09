import 'dart:async';
import 'dart:io';

import 'package:dartway_cli/src/commands/deploy_command.dart';
import 'package:dartway_cli/src/commands/deploy_run.dart';
import 'package:dartway_cli/src/deploy/compose_files.dart';
import 'package:dartway_cli/src/deploy/data_volumes.dart';
import 'package:dartway_cli/src/deploy/deploy_progress.dart';
import 'package:dartway_cli/src/deploy/deploy_runner.dart';
import 'package:dartway_cli/src/deploy/deploy_target.dart';
import 'package:dartway_cli/src/deploy/remote_steps.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

List<String> _ids(DwDeployRunner runner) =>
    runner.steps(skipGitUpdate: false).map((step) => step.id).toList();

void main() {
  test(
    'a pinned checkout stops when its deployment directory is unavailable',
    () async {
      final ssh = RecordingSsh();
      final runner = DwDeployRunner(ssh: ssh, stack: stackFrom());

      await runner.updateCheckout('abcdef1');

      expect(
        ssh.issued.single,
        contains("cd '\\''/home/deployer/shop'\\'' || exit \$?\n"),
      );
    },
  );

  group('the order of a deployment', () {
    final runner = DwDeployRunner(
      ssh: RecordingSsh(),
      stack: stackVariants()['bundled storage and a site']!,
    );
    final ids = _ids(runner);

    void before(String first, String second) => expect(
      ids.indexOf(first),
      lessThan(ids.indexOf(second)),
      reason: '$first must run before $second: $ids',
    );

    test('is the whole sequence, in order', () {
      expect(ids, [
        'stack-identity',
        'update-checkout',
        'bridge-override',
        'render-stack',
        'render-env',
        'compose-config',
        'data-volumes',
        'certificate',
        'build',
        'storage',
        'database',
        'server',
        'web',
        'stack',
        'check-upstreams',
        'nginx-test',
        'certificate-started-proxy',
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

    // Catches an expected volume missing beside real data before the build,
    // not after the stack is already up and the outside checks are green on
    // an empty one (#331: storage: minio → storage: bundled).
    test(
      'the data volumes are checked before anything is built or started',
      () {
        before('compose-config', 'data-volumes');
        before('data-volumes', 'build');
        before('data-volumes', 'database');
      },
    );

    // Migrations need the database, and the proxy is pointed at the server
    // only once it is the new one.
    test('the server is replaced after the database, before the web app', () {
      before('database', 'server');
      before('server', 'web');
    });

    // Let's Encrypt fails for reasons of its own. Asked after the server was
    // replaced, a failure stopped the deploy before the proxy restart, and
    // nginx kept the address of a server container that was gone (#433).
    test(
      'the certificate is asked for before anything is built or replaced',
      () {
        before('compose-config', 'certificate');
        for (final replacing in [
          'build',
          'storage',
          'database',
          'server',
          'web',
          'stack',
        ]) {
          before('certificate', replacing);
        }
      },
    );

    test('the proxy is checked, then certified, then restarted', () {
      before('stack', 'check-upstreams');
      before('check-upstreams', 'nginx-test');
      before('nginx-test', 'certificate-started-proxy');
      before('certificate-started-proxy', 'restart-proxy');
    });

    test('a certificate that fails leaves every service as it was', () async {
      final ssh = RecordingSsh([
        (
          'ps -q --status running nginx',
          const DwSshResult(
            exitCode: 1,
            stdout: 'extending api.example.com to: files.example.com',
            stderr: 'ConnectionResetError(104)',
          ),
        ),
      ]);
      final steps = DwDeployRunner(
        ssh: ssh,
        stack: stackVariants()['bundled storage and a site']!,
      ).steps(skipGitUpdate: false);
      final quiet = IOSink(StreamController<List<int>>()..stream.drain<void>());

      final failed = await executeDeploySteps(
        steps,
        progress: DwDeployProgress.into(human: quiet, events: quiet),
      );

      expect(failed, 'certificate');
      final composeCalls = ssh.issued.where(
        (command) => command.contains('docker compose'),
      );
      for (final changing in [' build', ' up ', ' stop ', ' restart ']) {
        expect(
          composeCalls.where((command) => command.contains(changing)),
          isEmpty,
          reason: 'nothing may be built, started or replaced: $changing',
        );
      }
    });

    test(
      'no storage step without bundled storage, no certificate without TLS',
      () {
        final plain = _ids(
          DwDeployRunner(
            ssh: RecordingSsh(),
            stack: stackFrom(front: const DwPlainHttpFront(18080)),
          ),
        );
        expect(plain, isNot(contains('storage')));
        expect(plain, isNot(contains('certificate')));
        expect(plain, isNot(contains('certificate-started-proxy')));
      },
    );

    // Left in, every external `deploy run` would try to start a `postgres`
    // service the rendered compose file no longer declares, and fail there.
    test('no database step with database: external', () {
      final external = _ids(
        DwDeployRunner(
          ssh: RecordingSsh(),
          stack: stackFrom(extra: '  database: external\n'),
        ),
      );
      expect(external, isNot(contains('database')));
      // Everything else keeps its place — this is the one step that leaves.
      expect(external, contains('server'));
      expect(external, contains('build'));
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
        expect(
          command.replaceAll("'\\''", "'"),
          contains("cd '/home/deployer/shop'"),
        );
        expect(command, contains(DwComposeFiles.projectOverride));
      }
    });

    test('the certificate covers every served host under one name', () async {
      final ssh = RecordingSsh();
      await DwDeployRunner(
        ssh: ssh,
        stack: stackVariants()['bundled storage and a site']!,
      ).issueCertificate();
      final command = ssh.issued.single.replaceAll("'\\''", "'");
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
        contains('[ -s /etc/letsencrypt/renewal/api.example.com.conf ]'),
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

    group('the certificate step', () {
      late Directory temp;
      late File calls;

      setUp(() {
        temp = Directory.systemTemp.createTempSync('dw_certificate_');
        calls = File(p.join(temp.path, 'calls'));
        Directory(p.join(temp.path, 'shop')).createSync();
      });
      tearDown(() => temp.deleteSync(recursive: true));

      /// What `openssl x509 -noout -ext subjectAltName` prints in the pinned
      /// certbot image (`certbot/certbot:v5.8.0`, OpenSSL 3.5) for a
      /// certificate naming [hosts] — copied from a run, not written from
      /// memory: the previous fake answered in a format certbot had stopped
      /// printing, and stayed green while every real deploy misread it.
      String subjectAltName(List<String> hosts) =>
          'X509v3 Subject Alternative Name: \n'
          '    ${hosts.map((host) => 'DNS:$host').join(', ')}\n';

      /// A runner whose `docker` answers as a server where certbot manages a
      /// certificate for [covered] (none when null), with a proxy running or
      /// not, and records what it was asked to run.
      DwDeployRunner runner({List<String>? covered, bool proxy = true}) {
        final bin = Directory(p.join(temp.path, 'bin'))..createSync();
        final answer = covered == null
            ? 'unmanaged\n'
            : subjectAltName(covered);
        File(p.join(temp.path, 'answer')).writeAsStringSync(answer);
        final docker = File(p.join(bin.path, 'docker'))
          ..writeAsStringSync('''
#!/bin/sh
printf '%s\\n---\\n' "\$*" >> '${calls.path}'
case "\$*" in
  *"ps -q --status running nginx"*) ${proxy ? "echo 4f1c2a9e" : ":"} ;;
  *"openssl x509"*) cat '${p.join(temp.path, 'answer')}' ;;
esac
''');
        Process.runSync('chmod', ['+x', docker.path]);
        return DwDeployRunner(
          ssh: LocalShell(
            environment: {
              'PATH': '${bin.path}:${Platform.environment['PATH']}',
            },
          ),
          stack: stackVariants()['bundled storage and a site']!,
          appDir: p.join(temp.path, 'shop'),
        );
      }

      List<String> issued() => calls.existsSync()
          ? calls
                .readAsStringSync()
                .split('\n---\n')
                .where((call) => call.trim().isNotEmpty)
                .toList()
          : [];

      const every = [
        'api.example.com',
        'app.example.com',
        'example.com',
        'files.example.com',
      ];

      test('leaves a certificate covering every host alone', () async {
        final result = await runner(covered: every).issueCertificate();
        expect(result.ok, isTrue, reason: result.stderr);
        expect(result.stdout, contains('already manages api.example.com'));
        expect(
          issued().where((call) => call.contains('certbot certonly')),
          isEmpty,
        );
      });

      test('extends it to exactly the hosts it does not name, keeping its '
          'lineage', () async {
        final result = await runner(
          covered: ['app.example.com', 'api.example.com'],
        ).issueCertificate();
        expect(result.ok, isTrue, reason: result.stderr);
        expect(
          result.stdout,
          contains(
            'extending api.example.com to: example.com files.example.com\n',
          ),
        );
        final request = issued().last;
        expect(request, contains('--expand'));
        for (final host in every) {
          expect(request, contains("-d '$host'"));
        }
        expect(request, isNot(contains('rm -rf')));
      });

      // A host is a whole name: `example.com` is not covered by a certificate
      // for `api.example.com`.
      test(
        'does not take a host for covered by a name that contains it',
        () async {
          final result = await runner(
            covered: [
              'api.example.com',
              'app.example.com',
              'files.example.com',
            ],
          ).issueCertificate();
          expect(
            result.stdout,
            contains('extending api.example.com to: example.com\n'),
          );
        },
      );

      test('replaces the bootstrap certificate with an issued one', () async {
        final result = await runner().issueCertificate();
        expect(result.ok, isTrue, reason: result.stderr);
        expect(result.stdout, isNot(contains('extending')));
        expect(result.stdout, isNot(contains('already manages')));
        final request = issued().last;
        expect(
          request,
          contains('rm -rf /etc/letsencrypt/live/api.example.com'),
        );
        expect(request, contains('certbot certonly'));
        expect(request, isNot(contains('--expand')));
      });

      test('a coverage it cannot read fails rather than asks', () async {
        final broken = runner(covered: every);
        File(
          p.join(temp.path, 'bin', 'docker'),
        ).writeAsStringSync('#!/bin/sh\necho "no such service" >&2\nexit 1\n');
        final result = await broken.issueCertificate();
        expect(result.ok, isFalse);
      });

      group('through the proxy still serving', () {
        test('asks nothing of certbot when no proxy is running', () async {
          final result = await runner(
            covered: ['api.example.com'],
            proxy: false,
          ).issueCertificate(throughServingProxy: true);
          expect(result.ok, isTrue, reason: result.stderr);
          expect(result.stdout, contains('no proxy is running'));
          expect(issued(), hasLength(1));
          expect(issued().single, contains('ps -q --status running nginx'));
        });

        test('fails when Compose cannot say whether a proxy runs', () async {
          final unanswered = runner(covered: every);
          File(p.join(temp.path, 'bin', 'docker')).writeAsStringSync(
            '#!/bin/sh\necho "cannot connect to the Docker daemon" >&2\nexit 1\n',
          );
          final result = await unanswered.issueCertificate(
            throughServingProxy: true,
          );
          expect(result.ok, isFalse);
          expect(result.stdout, isNot(contains('no proxy is running')));
        });

        test('extends the certificate while a proxy serves', () async {
          final result = await runner(
            covered: ['api.example.com', 'app.example.com', 'example.com'],
          ).issueCertificate(throughServingProxy: true);
          expect(result.ok, isTrue, reason: result.stderr);
          expect(issued().last, contains('--expand'));
        });

        test('asks nothing when every host is covered', () async {
          final result = await runner(
            covered: every,
          ).issueCertificate(throughServingProxy: true);
          expect(result.stdout, contains('already manages api.example.com'));
          expect(issued().where((call) => call.contains('certonly')), isEmpty);
        });
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

  group('the stack-identity step', () {
    final quiet = IOSink(StreamController<List<int>>()..stream.drain<void>());
    DwDeployProgress progress() =>
        DwDeployProgress.into(human: quiet, events: quiet);

    // The repository moved from acme/molodey to dealwithitdwi/moloday; the
    // server still runs the stack named after the old one.
    DwStack moved({String extra = ''}) => DwStack(
      target: DwDeployTarget.parse(
        configYaml(
          extra: extra,
        ).replaceFirst('acme/shop.git', 'dealwithitdwi/moloday.git'),
        environment: 'staging',
      ),
      projectRoot: Directory.systemTemp,
      serverPackage: 'shop_server',
      flutterPackage: 'shop_flutter',
      front: const DwTlsFront(),
    );

    RecordingSsh serverRunningMolodey() => RecordingSsh([
      (
        'docker volume ls',
        const DwSshResult(
          exitCode: 0,
          stdout:
              'molodey_postgres_data\n'
              '/home/deployer/.config/molodey/secrets.env\n',
          stderr: '',
        ),
      ),
    ]);

    test('is the first step, with or without the checkout update', () {
      final runner = DwDeployRunner(ssh: RecordingSsh(), stack: moved());
      expect(runner.steps(skipGitUpdate: false).first.id, 'stack-identity');
      expect(runner.steps(skipGitUpdate: true).first.id, 'stack-identity');
    });

    test('on a server running only another stack, the deploy stops there and '
        'sends nothing else', () async {
      final ssh = serverRunningMolodey();
      final failed = await executeDeploySteps(
        DwDeployRunner(ssh: ssh, stack: moved()).steps(skipGitUpdate: false),
        progress: progress(),
      );

      expect(failed, 'stack-identity');
      expect(ssh.issued, hasLength(1));
      expect(ssh.issued.single, isNot(contains('git ')));
      expect(ssh.issued.single, isNot(contains("cd '")));
      expect(ssh.issued.single, isNot(contains('docker compose')));
    });

    test('says what to set when it refuses', () async {
      final runner = DwDeployRunner(
        ssh: serverRunningMolodey(),
        stack: moved(),
      );
      final listed = await runner.listStacks();

      expect(listed.ok, isTrue);
      expect(
        runner.stackIdentityVerdict(listed),
        contains('set "project: molodey" under staging'),
      );
    });

    // The refusal is the step's verdict, so it is recorded on the server: the
    // listing itself exits 0, and a resume that took that exit code's word
    // would pass over the guard and update a checkout on a foreign server.
    group('through the detached step runner', () {
      late Directory temp;
      late LocalShell shell;
      late DwRemoteSteps remote;

      setUp(() {
        temp = Directory.systemTemp.createTempSync('dw_identity_resume_');
        // A `docker` that answers the listing of a server running molodey.
        final bin = Directory(p.join(temp.path, 'bin'))..createSync();
        File(
          p.join(bin.path, 'docker'),
        ).writeAsStringSync('#!/bin/sh\necho molodey_postgres_data\n');
        Process.runSync('chmod', ['+x', p.join(bin.path, 'docker')]);
        shell = LocalShell(
          environment: {'PATH': '${bin.path}:${Platform.environment['PATH']}'},
        );
        remote = DwRemoteSteps(
          ssh: shell,
          deployUser: 'deployer',
          directory: p.join(temp.path, 'deploy-run'),
          pollInterval: const Duration(milliseconds: 50),
        );
      });
      tearDown(() => temp.deleteSync(recursive: true));

      List<DwDeployStep> steps() => DwDeployRunner(
        ssh: shell,
        stack: moved(),
        remote: remote,
      ).steps(skipGitUpdate: false);

      test('a refusal stays a refusal on --resume, and with --retry-failed '
          'is judged again', () async {
        expect(
          await executeDeploySteps(
            steps(),
            remote: remote,
            progress: progress(),
          ),
          'stack-identity',
        );
        final record = (await remote.read())!;
        expect(record['stack-identity']!.state, DwRemoteStepState.rejected);
        expect(record['update-checkout']!.state, DwRemoteStepState.pending);

        for (final retryFailed in [false, true]) {
          final resumed = (await remote.read())!;
          final planned = [
            for (final id in resumed.keys)
              ...steps().where((step) => step.id == id),
          ];
          expect(
            await executeDeploySteps(
              planned,
              remote: remote,
              resumeFrom: resumed,
              retryFailed: retryFailed,
              progress: progress(),
            ),
            'stack-identity',
            reason: 'retryFailed: $retryFailed',
          );
          final after = (await remote.read())!;
          expect(after['update-checkout']!.state, DwRemoteStepState.pending);
        }
      });
    });

    // Judging the recorded identity again must not make the steps the resumed
    // run already finished start over.
    test('a passed identity on --resume still passes over the finished steps',
        () async {
      final ran = <String>[];
      DwDeployStep step(String id, {String? Function(DwSshResult)? verdict}) =>
          DwDeployStep(
            id: id,
            title: id,
            verdict: verdict,
            run: () async {
              ran.add(id);
              return const DwSshResult(exitCode: 0, stdout: '', stderr: '');
            },
          );
      const done = DwRemoteStepRecord(DwRemoteStepState.exited, 0);
      final failed = await executeDeploySteps(
        [
          step('stack-identity', verdict: (_) => null),
          step('update-checkout'),
          step('build'),
          step('start'),
        ],
        resumeFrom: {
          'stack-identity': done,
          'update-checkout': done,
          'build': const DwRemoteStepRecord(DwRemoteStepState.pending),
          'start': const DwRemoteStepRecord(DwRemoteStepState.pending),
        },
        progress: progress(),
      );

      expect(failed, isNull);
      expect(ran, ['stack-identity', 'build', 'start']);
    });

    // The whole command, with the checkout update skipped: the revision is
    // read from the checkout, and on a foreign server that is not read
    // either until the identity has passed.
    test('deploy run --skip-git-update sends no cd and no git to a foreign '
        'server', () async {
      final ssh = _ServerAnsweringEveryStep(
        'molodey_postgres_data\n/home/deployer/.config/molodey/secrets.env\n',
      );
      final code = await runDeploy(
        moved(),
        DeployRunCommand().argParser.parse([
          '--env',
          'staging',
          '--skip-git-update',
        ]),
        connection: ssh,
        progress: progress(),
        localChecks: const [],
      );

      expect(code, 1);
      expect(ssh.issued.where((command) => command.contains('git ')), isEmpty);
      expect(
        ssh.issued.where(
          (command) => command.contains('/home/deployer/moloday'),
        ),
        isEmpty,
      );
      expect(ssh.issued.last, contains('stack-identity.rejected'));
    });

    test('with project: pinning the old name, it passes and the checkout '
        'is updated where the stack lives', () async {
      final ssh = serverRunningMolodey();
      final failed = await executeDeploySteps(
        DwDeployRunner(
          ssh: ssh,
          stack: moved(extra: '  project: molodey\n'),
        ).steps(skipGitUpdate: false).take(2).toList(),
        progress: progress(),
      );

      expect(failed, isNull);
      expect(ssh.issued.first, contains('docker volume ls'));
      // The checkout update, in the directory the live stack runs from.
      expect(ssh.issued[1], contains('/home/deployer/molodey'));
      expect(ssh.issued[1], contains('git fetch origin'));
    });

    // The script itself, in a shell: the store listing is a glob that matches
    // nothing on a fresh server, and that must not fail the step.
    test('lists the secret stores, and nothing is not an error', () async {
      final home = Directory.systemTemp.createTempSync('dw_identity_');
      addTearDown(() => home.deleteSync(recursive: true));
      final script = dwStackIdentityScript(moved().target)
          .replaceAll('/home/deployer', home.path)
          .replaceFirst(
            "docker volume ls --format '{{.Name}}'",
            'echo molodey_postgres_data',
          );

      final empty = await LocalShell().run(script);
      expect(empty.ok, isTrue, reason: empty.stderr);
      expect(empty.stdout.trim(), 'molodey_postgres_data');

      File(p.join(home.path, '.config', 'molodey', 'secrets.env'))
        ..createSync(recursive: true)
        ..writeAsStringSync('KEY=value\n');
      Directory(p.join(home.path, '.config', 'unrelated')).createSync();
      final listed = await LocalShell().run(script);
      expect(listed.ok, isTrue, reason: listed.stderr);
      expect(listed.stdout.trim().split('\n'), [
        'molodey_postgres_data',
        p.join(home.path, '.config', 'molodey', 'secrets.env'),
      ]);
      expect(listed.stdout, isNot(contains('KEY=value')));
    });
  });

  group('checkDataVolumes', () {
    DwDeployRunner runnerWith(RecordingSsh ssh) => DwDeployRunner(
      ssh: ssh,
      stack: stackVariants()['bundled storage and a site']!,
    );

    test('exits 0 and says so when nothing is missing', () async {
      final ssh = RecordingSsh([
        (
          'docker volume ls',
          const DwSshResult(
            exitCode: 0,
            stdout: 'shop_postgres_data\nshop_storage_data\n',
            stderr: '',
          ),
        ),
      ]);
      final result = await runnerWith(ssh).checkDataVolumes();
      expect(result.ok, isTrue);
      expect(result.stdout, contains('shop_storage_data'));
    });

    // The regression this exists for: `run` used to have no volume guard at
    // all, so a server carrying the old `shop_minio_data` (a stranger to the
    // renamed stack) with no `shop_storage_data` yet would start the latter
    // empty. This must exit non-zero, and say why, or every check above it
    // could be quietly removed without a test noticing.
    test(
      'exits non-zero and names both volumes when a rename is unsafe',
      () async {
        final ssh = RecordingSsh([
          (
            'docker volume ls',
            const DwSshResult(
              exitCode: 0,
              stdout: 'shop_postgres_data\nshop_minio_data\n',
              stderr: '',
            ),
          ),
        ]);
        final result = await runnerWith(ssh).checkDataVolumes();
        expect(result.ok, isFalse);
        expect(result.stderr, contains('shop_minio_data'));
        expect(result.stderr, contains('shop_storage_data'));
      },
    );

    test('exits non-zero when the server cannot even be asked', () async {
      final ssh = RecordingSsh([
        (
          'docker volume ls',
          const DwSshResult(
            exitCode: 1,
            stdout: '',
            stderr: 'permission denied',
          ),
        ),
      ]);
      final result = await runnerWith(ssh).checkDataVolumes();
      expect(result.ok, isFalse);
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
          stdout: 'server\n--dw-nginx-d--\nproxy_pass http://storage:9000;\n',
          stderr: '',
        ),
      );
      expect(verdict, contains('storage'));
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
        stack: stackVariants()['bundled storage and a site']!,
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
      composeFile().writeAsStringSync(
        '# rendered before the build arg existed\n',
      );
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
      String inode() =>
          (Process.runSync('ls', ['-i', nginxFile().path]).stdout as String)
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
        ).writeAsStringSync('services:\n  storage: {}\n');
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

  group('revision-pinned checkout', () {
    late Directory temp;
    late Directory remote;
    late Directory source;
    late Directory checkout;
    late DwDeployRunner runner;
    late String sha1;
    late String sha2;

    String git(Directory directory, List<String> arguments) {
      final result = Process.runSync(
        'git',
        arguments,
        workingDirectory: directory.path,
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      return (result.stdout as String).trim();
    }

    setUp(() {
      temp = Directory.systemTemp.createTempSync('dw_revision_');
      remote = Directory(p.join(temp.path, 'remote.git'))..createSync();
      git(remote, ['init', '--bare']);
      source = Directory(p.join(temp.path, 'source'))..createSync();
      git(source, ['init', '-b', 'master']);
      git(source, ['config', 'user.name', 'DartWay test']);
      git(source, ['config', 'user.email', 'test@example.com']);
      File(p.join(source.path, 'value')).writeAsStringSync('one');
      git(source, ['add', 'value']);
      git(source, ['commit', '-m', 'one']);
      sha1 = git(source, ['rev-parse', 'HEAD']);
      git(source, ['remote', 'add', 'origin', remote.path]);
      git(source, ['push', '-u', 'origin', 'master']);
      checkout = Directory(p.join(temp.path, 'checkout'));
      final clone = Process.runSync('git', [
        'clone',
        remote.path,
        checkout.path,
      ]);
      expect(clone.exitCode, 0, reason: clone.stderr);
      File(p.join(source.path, 'value')).writeAsStringSync('two');
      git(source, ['commit', '-am', 'two']);
      sha2 = git(source, ['rev-parse', 'HEAD']);
      git(source, ['push']);
      runner = DwDeployRunner(
        ssh: LocalShell(),
        stack: stackFrom(),
        appDir: checkout.path,
      );
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test('deploys the requested ancestor after the remote tip moves', () async {
      final result = await runner.updateCheckout(sha1);
      expect(result.ok, isTrue, reason: result.stderr);
      expect(git(checkout, ['rev-parse', 'HEAD']), sha1);
    });

    test('refuses a commit that is not on the remote branch', () async {
      git(source, ['checkout', '--orphan', 'other']);
      git(source, ['rm', '-rf', '.']);
      File(p.join(source.path, 'other')).writeAsStringSync('other');
      git(source, ['add', 'other']);
      git(source, ['commit', '-m', 'other']);
      final other = git(source, ['rev-parse', 'HEAD']);
      git(source, ['push', 'origin', 'other']);
      git(checkout, ['fetch', 'origin', 'other']);
      final before = git(checkout, ['rev-parse', 'HEAD']);
      final result = await runner.updateCheckout(other);
      expect(result.ok, isFalse);
      expect(result.stderr, contains('revision-not-on-branch'));
      expect(git(checkout, ['rev-parse', 'HEAD']), before);
    });

    test('refuses an unknown revision', () async {
      final before = git(checkout, ['rev-parse', 'HEAD']);
      final result = await runner.updateCheckout(List.filled(40, 'f').join());
      expect(result.ok, isFalse);
      expect(result.stderr, contains('revision-not-found'));
      expect(git(checkout, ['rev-parse', 'HEAD']), before);
    });

    test('refuses to move backwards from a deployed descendant', () async {
      expect((await runner.updateCheckout(sha2)).ok, isTrue);
      final result = await runner.updateCheckout(sha1);
      expect(result.ok, isFalse);
      expect(result.stderr, contains('superseded'));
      expect(git(checkout, ['rev-parse', 'HEAD']), sha2);
    });

    test('allows redeploying the current revision', () async {
      expect((await runner.updateCheckout(sha2)).ok, isTrue);
      final result = await runner.updateCheckout(sha2);
      expect(result.ok, isTrue, reason: result.stderr);
      expect(git(checkout, ['rev-parse', 'HEAD']), sha2);
    });
  });
}

/// Answers the BBR question, and every detached step the way the server's
/// step runner reports one that exited 0 having printed [stdout].
class _ServerAnsweringEveryStep extends RecordingSsh {
  _ServerAnsweringEveryStep(this.stdout);

  final String stdout;

  static final _nonce = RegExp(r'--dw-step-[0-9a-f]{8}--');

  @override
  Future<DwSshResult> run(String command) async {
    issued.add(command);
    if (command.contains('tcp_allowed_congestion_control')) {
      return const DwSshResult(exitCode: 0, stdout: 'cubic bbr\n', stderr: '');
    }
    final nonce = _nonce.firstMatch(command)?.group(0);
    if (nonce == null) {
      return const DwSshResult(exitCode: 0, stdout: '', stderr: '');
    }
    return DwSshResult(
      exitCode: 0,
      stdout: '$nonce exited 0\n$stdout\n$nonce stderr\n\n$nonce end 0\n',
      stderr: '',
    );
  }
}
