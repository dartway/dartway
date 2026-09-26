import 'dart:convert';
import 'dart:io';

import 'package:dartway_cli/src/deploy/deploy_target.dart';
import 'package:dartway_cli/src/deploy/ssh_runner.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:path/path.dart' as p;

/// A complete environment, as `deploy/config.yaml` would state it.
String configYaml({String extra = '', String environment = 'staging'}) =>
    '''
$environment:
  host: 203.0.113.10
  ssh_user: root
  deploy_user: deployer
  os: ubuntu
  repo: git@github.com:acme/shop.git
  branch: master
  ssl_email: ops@example.com
  api_domain: api.example.com
  app_domain: app.example.com
$extra''';

DwDeployTarget targetFrom({String extra = ''}) =>
    DwDeployTarget.parse(configYaml(extra: extra), environment: 'staging');

DwStack stackFrom({
  String extra = '',
  DwFrontMode front = const DwTlsFront(),
}) => DwStack(
  target: targetFrom(extra: extra),
  serverPackage: 'shop_server',
  flutterPackage: 'shop_flutter',
  front: front,
);

/// The variants of a stack every rendering rule has to hold for.
Map<String, DwStack> stackVariants({DwFrontMode front = const DwTlsFront()}) =>
    {
      'minimal': stackFrom(front: front),
      'bundled storage and a site': stackFrom(
        front: front,
        extra:
            '  site:\n    domain: example.com\n    source: app_site/build\n'
            '  storage: bundled\n  storage_domain: files.example.com\n',
      ),
      'external storage, external site, files': stackFrom(
        front: front,
        extra:
            '  site:\n    domain: example.com\n    source: none\n'
            '  storage: external\n'
            '  requires:\n    secrets: [SMS_API_TOKEN]\n'
            '    files: [fcm.json]\n',
      ),
    };

/// Records what it was asked to run, and answers from a script: matched by
/// substring, in order, success with no output otherwise.
class RecordingSsh extends DwSshRunner {
  RecordingSsh([this.answers = const []])
    : super(host: '203.0.113.10', user: 'root');

  final List<(String, DwSshResult)> answers;
  final List<String> issued = [];

  @override
  Future<DwSshResult> run(String command) async {
    issued.add(command);
    for (final (fragment, result) in answers) {
      if (command.contains(fragment)) return result;
    }
    return const DwSshResult(exitCode: 0, stdout: '', stderr: '');
  }

  @override
  Future<DwSshResult> runAs(String deployUser, String command) => run(command);

  @override
  Future<DwSshResult> runAsWithInput(
    String deployUser,
    String command,
    String input,
  ) => run(command);
}

/// Runs the commands a deploy would send to a server in a local shell instead,
/// so the scripts themselves — not a description of them — are what a test
/// exercises. POSIX `sh`, as on the server.
class LocalShell extends DwSshRunner {
  LocalShell({this.environment}) : super(host: 'localhost', user: 'local');

  final Map<String, String>? environment;

  @override
  Future<DwSshResult> run(String command) async {
    final result = await Process.run(
      'sh',
      ['-c', command],
      environment: environment,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    return DwSshResult(
      exitCode: result.exitCode,
      stdout: result.stdout as String,
      stderr: result.stderr as String,
    );
  }

  @override
  Future<DwSshResult> runAs(String deployUser, String command) => run(command);

  @override
  Future<DwSshResult> runAsWithInput(
    String deployUser,
    String command,
    String input,
  ) async {
    final process = await Process.start('sh', [
      '-c',
      command,
    ], environment: environment);
    process.stdin.write(input);
    await process.stdin.close();
    final out = utf8.decodeStream(process.stdout);
    final err = utf8.decodeStream(process.stderr);
    return DwSshResult(
      exitCode: await process.exitCode,
      stdout: await out,
      stderr: await err,
    );
  }
}

/// Copies a project tree without what a build leaves behind — the shape a
/// deployment's checkout has.
void copyProject(Directory source, Directory destination) {
  const skipped = {'.dart_tool', 'build', '.fvm', 'ephemeral', 'node_modules'};
  destination.createSync(recursive: true);
  for (final entity in source.listSync(followLinks: false)) {
    final name = p.basename(entity.path);
    if (skipped.contains(name)) continue;
    final target = p.join(destination.path, name);
    if (entity is Directory) {
      copyProject(entity, Directory(target));
    } else if (entity is File) {
      entity.copySync(target);
    }
  }
}
