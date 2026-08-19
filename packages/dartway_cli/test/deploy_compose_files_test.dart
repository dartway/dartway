import 'dart:io';

import 'package:dartway_cli/src/deploy/compose_files.dart';
import 'package:dartway_cli/src/deploy/deploy_check.dart';
import 'package:dartway_cli/src/deploy/deploy_runner.dart';
import 'package:dartway_cli/src/deploy/deploy_target.dart';
import 'package:dartway_cli/src/deploy/remote_checks.dart';
import 'package:dartway_cli/src/deploy/renderer.dart';
import 'package:dartway_cli/src/deploy/serverpod_config.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// An SSH runner that answers from a script instead of a server.
///
/// Matched by substring, in declaration order: a deploy command is a shell
/// one-liner, and what a test cares about is the fragment it contains.
class _ScriptedSsh extends DwSshRunner {
  _ScriptedSsh(this.answers)
    : super(host: '203.0.113.10', user: 'root', identityFile: null);

  final List<(String, DwSshResult)> answers;
  final List<String> issued = [];

  @override
  Future<DwSshResult> run(String command) async {
    issued.add(command);
    for (final (fragment, result) in answers) {
      if (command.contains(fragment)) {
        return result;
      }
    }
    return const DwSshResult(exitCode: 0, stdout: '', stderr: '');
  }

  @override
  Future<DwSshResult> runAs(String deployUser, String command) => run(command);
}

DwSshResult _ok(String stdout) =>
    DwSshResult(exitCode: 0, stdout: stdout, stderr: '');

DwSshResult _failed(String stderr) =>
    DwSshResult(exitCode: 1, stdout: '', stderr: stderr);

DwDeployTarget _target({List<String> files = const []}) => DwDeployTarget(
  environment: 'staging',
  host: '203.0.113.10',
  sshUser: 'root',
  deployUser: 'deployer',
  os: 'ubuntu',
  repo: 'git@github.com:acme/shop.git',
  branch: 'master',
  sslEmail: 'ops@example.com',
  webAppDomain: 'app.example.com',
  requiredSecretFiles: files,
);

DwServerpodConfig _serverpod() => DwServerpodConfig(
  environment: 'staging',
  relativePath: 'shop_server/config/staging.yaml',
  apiServer: DwServerEndpoint(
    name: 'apiServer',
    port: 8080,
    publicHost: 'api.example.com',
    publicPort: 443,
    publicScheme: 'https',
  ),
  insightsServer: null,
  webServer: null,
  databaseHost: 'postgres',
  databasePort: 5432,
  databaseName: 'shop',
  databaseUser: 'shop',
  redisEnabled: false,
  redisHost: null,
);

/// The compose configuration a server answers with, given the mounts of the
/// backend service.
String _composeConfiguration(List<String> mounts) =>
    '''
name: shop
services:
  backend:
    volumes:
${mounts.map((mount) => '      - type: bind\n        source: ${mount.split(':').first}\n        target: ${mount.split(':')[1]}\n        read_only: true').join('\n')}
''';

void main() {
  const store = '/home/deployer/.config/shop';
  const appDir = '/home/deployer/shop';

  group('the compose command names the project override', () {
    test('every deploy step passes deploy/compose.override.yml', () async {
      final ssh = _ScriptedSsh(const []);
      final runner = DwDeployRunner(
        ssh: ssh,
        target: _target(),
        serverpod: _serverpod(),
        stdout: stdout,
      );

      await runner.build();
      await runner.applyMigrations();
      await runner.up();
      await runner.restartProxy();
      await runner.status();

      expect(ssh.issued, hasLength(5));
      for (final command in ssh.issued) {
        expect(command, contains("cd '$appDir'"));
        expect(command, contains('-f docker-compose.yml'));
        expect(command, contains('-f deploy/compose.override.yml'));
      }
    });

    test('the override is used only when the checkout carries one', () {
      // Naming a file that is not there makes Compose refuse to run at all,
      // so the flag is added by the server, not assumed here.
      expect(
        DwComposeFiles.commandIn(appDir, 'build'),
        contains("if [ -f 'deploy/compose.override.yml' ]"),
      );
    });

    test('migrations still read their stdin from nowhere', () async {
      final ssh = _ScriptedSsh(const []);
      await DwDeployRunner(
        ssh: ssh,
        target: _target(),
        serverpod: _serverpod(),
        stdout: stdout,
      ).applyMigrations();

      expect(ssh.issued.single, endsWith('</dev/null'));
    });
  });

  group('retiring the copy an older setup left behind', () {
    test('a deployment always offers to move it aside', () {
      final steps = DwDeployRunner(
        ssh: _ScriptedSsh(const []),
        target: _target(),
        serverpod: _serverpod(),
        stdout: stdout,
      ).steps(skipGitUpdate: true);

      expect(steps.first.id, 'retire-override-copy');
    });

    test('is idempotent, and a no-op where the copy never existed', () async {
      // Shell is the only place this can be judged: the whole point is what
      // happens on a server that has the file, and on one that never did.
      try {
        Process.runSync('sh', ['-c', 'true']);
      } on ProcessException {
        markTestSkipped('no POSIX shell on this machine');
        return;
      }

      final root = Directory.systemTemp.createTempSync('dw_override_');
      addTearDown(() => root.deleteSync(recursive: true));
      final dir = root.path.replaceAll(r'\', '/');
      final script = DwComposeFiles.retireLegacyCopyIn(dir);

      // A server that never had the copy.
      final clean = Process.runSync('sh', ['-c', script]);
      expect(clean.exitCode, 0);
      expect(clean.stdout.toString().trim(), isEmpty);

      // A server that has one, twice over.
      File(
        p.join(root.path, DwComposeFiles.legacyCopy),
      ).writeAsStringSync('services:\n  backend:\n    restart: always\n');

      final first = Process.runSync('sh', ['-c', script]);
      expect(first.exitCode, 0);
      expect(first.stdout.toString(), contains('Retired'));

      final second = Process.runSync('sh', ['-c', script]);
      expect(second.exitCode, 0);
      expect(second.stdout.toString().trim(), isEmpty);

      expect(
        File(p.join(root.path, DwComposeFiles.legacyCopy)).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(root.path, DwComposeFiles.retiredCopy)).readAsStringSync(),
        contains('restart: always'),
      );
    });
  });

  group('requires.files becomes a mount', () {
    String render({List<String> files = const []}) => DwInfraRenderer(
      projectRoot: Directory.systemTemp,
      target: _target(files: files),
      serverpod: _serverpod(),
      serverPackage: 'shop_server',
      flutterPackage: 'shop_flutter',
    ).composeFile;

    test('a declared file is mounted read-only beside passwords.yaml', () {
      final compose = render(files: ['firebase-service-account.json']);

      expect(
        compose,
        contains(
          '- $store/firebase-service-account.json:'
          '/app/config/firebase-service-account.json:ro',
        ),
      );
    });

    test('declaring nothing renders the compose file unchanged', () {
      expect(
        render(),
        contains(
          '- $store/passwords.yaml:/app/config/passwords.yaml:ro\n'
          '    depends_on:',
        ),
      );
    });

    test('a pattern is refused rather than mounted literally', () {
      expect(
        () => render(files: ['*.json']),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('is not a file name'),
          ),
        ),
      );
    });
  });

  group('the secret-files check asks whether the container sees the file', () {
    final check = dwRemoteDeployChecks.firstWhere(
      (c) => c.id == 'secret-files',
    );

    DwDeployContext contextWith(
      DwSshRunner ssh, {
      List<String> files = const [],
    }) => DwDeployContext(
      projectRoot: Directory.systemTemp,
      serverPackage: 'shop_server',
      flutterPackage: 'shop_flutter',
      target: _target(files: files),
      serverpod: _serverpod(),
      ssh: ssh,
    );

    test(
      'passes when the delivered file is mounted into the backend',
      () async {
        final ssh = _ScriptedSsh([
          ("ls -1 '$store'", _ok('passwords.yaml\nfirebase.json\n')),
          (
            'config --no-interpolate',
            _ok(
              _composeConfiguration([
                '$store/passwords.yaml:/app/config/passwords.yaml',
                '$store/firebase.json:/app/config/firebase.json',
              ]),
            ),
          ),
        ]);

        final verdict = await check.evaluate(
          contextWith(ssh, files: ['firebase.json']),
        );

        expect(verdict.passed, isTrue);
        expect(verdict.detail, contains('/app/config/firebase.json'));
      },
    );

    // The bug this check exists for: green on "the file is on the server",
    // red on "the application can find it".
    test('fails when the file is on the server but mounted nowhere', () async {
      final ssh = _ScriptedSsh([
        ("ls -1 '$store'", _ok('passwords.yaml\nfirebase.json\n')),
        (
          'config --no-interpolate',
          _ok(
            _composeConfiguration([
              '$store/passwords.yaml:/app/config/passwords.yaml',
            ]),
          ),
        ),
      ]);

      final verdict = await check.evaluate(
        contextWith(ssh, files: ['firebase.json']),
      );

      expect(verdict.passed, isFalse);
      expect(verdict.detail, contains('not mounted'));
      expect(verdict.fix, contains('dartway deploy setup'));
    });

    test(
      'asks Compose the question with the project override in hand',
      () async {
        final ssh = _ScriptedSsh([
          ("ls -1 '$store'", _ok('firebase.json\n')),
          ('config --no-interpolate', _ok(_composeConfiguration(const []))),
        ]);

        await check.evaluate(contextWith(ssh, files: ['firebase.json']));

        final configuration = ssh.issued.last;
        expect(configuration, contains('-f deploy/compose.override.yml'));
        expect(configuration, contains("cd '$appDir'"));
      },
    );

    test('reports an undelivered file before anything else', () async {
      final ssh = _ScriptedSsh([("ls -1 '$store'", _ok('passwords.yaml\n'))]);

      final verdict = await check.evaluate(
        contextWith(ssh, files: ['firebase.json']),
      );

      expect(verdict.passed, isFalse);
      expect(verdict.fix, contains('put-file'));
    });

    test('a configuration it cannot read is a failure, not a pass', () async {
      final ssh = _ScriptedSsh([
        ("ls -1 '$store'", _ok('firebase.json\n')),
        (
          'config --no-interpolate',
          _failed('no configuration file provided: not found'),
        ),
      ]);

      final verdict = await check.evaluate(
        contextWith(ssh, files: ['firebase.json']),
      );

      expect(verdict.passed, isFalse);
      expect(verdict.detail, contains('cannot read the compose configuration'));
    });

    test('declaring nothing is not a finding', () async {
      final verdict = await check.evaluate(contextWith(_ScriptedSsh(const [])));

      expect(verdict.passed, isTrue);
      expect(verdict.detail, 'none declared');
    });

    test('a pattern cannot be mounted, and says so', () async {
      final verdict = await check.evaluate(
        contextWith(_ScriptedSsh(const []), files: ['*.json']),
      );

      expect(verdict.passed, isFalse);
      expect(verdict.detail, contains('not file names'));
    });
  });
}
