import 'dart:io';

import 'package:dartway_cli/src/commands/deploy_command.dart';
import 'package:dartway_cli/src/commands/deploy_setup.dart';
import 'package:dartway_cli/src/deploy/deploy_check.dart';
import 'package:dartway_cli/src/deploy/deploy_runner.dart';
import 'package:dartway_cli/src/deploy/deploy_target.dart';
import 'package:dartway_cli/src/deploy/output_mask.dart';
import 'package:dartway_cli/src/deploy/remote_checks.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

void main() {
  late Directory temp;
  late File store;
  late DwMaskedSshRunner ssh;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('dw_output_mask_');
    store = File(p.join(temp.path, 'secrets.env'));
    ssh = DwMaskedSshRunner(
      LocalShell(),
      deployUser: 'deployer',
      storeFile: store.path,
    );
  });
  tearDown(() => temp.deleteSync(recursive: true));

  test(
    'literal values, URL encodings and both streams keep surrounding bytes',
    () async {
      const secret = r'.*[]\/&$';
      store.writeAsStringSync("TOKEN='$secret'\nSHORT='true'\nPORT='5432'\n");
      final result = await ssh.runAs(
        'deployer',
        r"printf '%s\n' 'prefix .*[]\/&$ suffix true 5432 .*other' "
            "'url=.%2A%5B%5D%5C%2F%26%24' 'url=.*%5b%5d%5c%2f%26%24'\n"
            r"printf '%s' 'error .*[]\/&$ end' >&2"
            "\nexit 9",
      );
      expect(result.exitCode, 9);
      expect(
        result.stdout,
        'prefix *** suffix true 5432 .*other\nurl=***\nurl=***\n',
      );
      expect(result.stderr, 'error *** end');
    },
  );

  test(
    'the threshold counts characters while URL encoding uses UTF-8 bytes',
    () async {
      store.writeAsStringSync("LONG='éééééé'\nSHORT='ééééé'\nEDGE='123456'\n");
      final result = await ssh.runAs(
        'deployer',
        "printf '%s' 'éééééé ééééé 123456 %C3%A9%C3%A9%C3%A9%C3%A9%C3%A9%C3%A9'",
      );
      expect(result.stdout, '*** ééééé *** ***');
    },
  );

  test(
    'overlapping values use the longest match and never re-mask replacements',
    () async {
      store.writeAsStringSync("A='abcdef'\nB='abcdefgh'\nC='******'\n");
      final result = await ssh.runAs(
        'deployer',
        "printf '%s' 'abcdefgh abcdef ******'",
      );
      expect(result.stdout, '*** *** ***');
    },
  );

  test(
    'missing store passes empty streams and unterminated output unchanged',
    () async {
      final beforeUser = DwMaskedSshRunner(
        LocalShell(),
        deployUser: 'dw_mask_absent_437',
        storeFile: store.path,
      );
      for (final run in [
        () => ssh.runAs('deployer', "printf 'unchanged\\n\\nlast'\nexit 4"),
        () => beforeUser.run("printf 'unchanged\\n\\nlast'\nexit 4"),
      ]) {
        final result = await run();
        expect(result.exitCode, 4);
        expect(result.stdout, 'unchanged\n\nlast');
        expect(result.stderr, '');
      }
    },
  );

  test(
    'input delivery still reaches the command and its output is masked',
    () async {
      store.writeAsStringSync("TOKEN='stdin-secret'\n");
      final result = await ssh.runAsWithInput(
        'deployer',
        'cat; exit 3',
        'stdin-secret\nlast',
      );
      expect(result.exitCode, 3);
      expect(result.stdout, '***\nlast');
    },
  );

  test(
    'an unreadable store fails closed without releasing captured output',
    () async {
      // A directory cannot be read as a store, even by a root test process.
      Directory(store.path).createSync();
      final result = await ssh.runAs('deployer', "echo 'must stay on target'");
      expect(result.ok, isFalse);
      expect(result.stdout, isEmpty);
      expect(result.stderr, contains('Cannot read the secret store'));
    },
  );

  for (final path in ['direct compose', 'setup', 'check']) {
    test('$path returns only target-masked command output', () async {
      final user = (await Process.run('id', ['-un'])).stdout.toString().trim();
      final target = DwDeployTarget.parse(
        configYaml().replaceAll('deploy_user: deployer', 'deploy_user: $user'),
        environment: 'staging',
      );
      final stack = DwStack(
        target: target,
        projectRoot: temp,
        serverPackage: 'shop_server',
        flutterPackage: 'shop_flutter',
      );
      store.writeAsStringSync("TOKEN='stored-secret'\n");
      final bin = Directory(p.join(temp.path, 'bin'))..createSync();
      File(p.join(bin.path, 'docker')).writeAsStringSync(
        "#!/bin/sh\nprintf '%s' 'failure stored-secret end' >&2\nexit 8\n",
      );
      // Root provisioning is simulated by executables; the complete wrapper
      // and target filter still run in the real shell under this test's user.
      File(p.join(bin.path, 'id')).writeAsStringSync(
        '#!/bin/sh\nif [ "\$1" = -u ]; then echo 0; else /usr/bin/id "\$@"; fi\n',
      );
      File(
        p.join(bin.path, 'systemctl'),
      ).writeAsStringSync('#!/bin/sh\nexit 0\n');
      for (final file in bin.listSync()) {
        await Process.run('chmod', ['+x', file.path]);
      }
      final shell = _TargetShell(target.runtimeConfigDir, temp.path, {
        'PATH': '${bin.path}:${Platform.environment['PATH']}',
      });
      if (path == 'direct compose') {
        final result = await DwDeployRunner(
          ssh: shell,
          stack: stack,
          appDir: temp.path,
          storeDir: temp.path,
        ).checkComposeConfig();
        expect(result.exitCode, 8);
        expect(result.stderr, 'failure *** end');
      } else if (path == 'setup') {
        expect(
          await runSetup(
            stack,
            DeploySetupCommand().argParser.parse(['--env', 'staging']),
            connection: shell,
          ),
          1,
        );
        expect(shell.results.last.stderr, 'failure *** end');
      } else {
        final context = DwDeployContext(
          projectRoot: temp,
          stack: stack,
          ssh: shell,
        );
        final verdict = await dwRemoteDeployChecks
            .singleWhere((check) => check.id == 'docker-available')
            .evaluate(context);
        expect(verdict.passed, isFalse);
        expect(verdict.detail, 'failure *** end');
      }
    });
  }

  test(
    'the target filter and direct wrapper pass dash syntax validation',
    () async {
      final recording = RecordingSsh();
      final wrapped = DwMaskedSshRunner(
        recording,
        deployUser: 'deployer',
        storeFile: store.path,
      );
      await wrapped.run('echo setup');
      await wrapped.runPrivileged('echo root');
      await wrapped.runAs('deployer', 'echo direct');
      for (final command in [
        dwSecretMaskFunction(store.path),
        ...recording.issued,
      ]) {
        final script = File(p.join(temp.path, 'syntax.sh'))
          ..writeAsStringSync(command);
        final result = await Process.run('dash', ['-n', script.path]);
        expect(result.exitCode, 0, reason: result.stderr.toString());
      }
    },
  );
}

/// Relocates the target's runtime directory into the test sandbox without
/// changing its commands or implementing masking in the test transport.
class _TargetShell extends LocalShell {
  _TargetShell(
    this.remoteDirectory,
    this.localDirectory,
    Map<String, String> environment,
  ) : super(environment: environment);
  final String remoteDirectory;
  final String localDirectory;
  final results = <DwSshResult>[];

  @override
  Future<DwSshResult> run(String command) async {
    final result = await super.run(
      command.replaceAll(remoteDirectory, localDirectory),
    );
    results.add(result);
    return result;
  }
}
