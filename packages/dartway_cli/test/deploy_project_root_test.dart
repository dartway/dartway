import 'dart:io';

import 'package:dartway_cli/src/commands/deploy_command.dart';
import 'package:dartway_cli/src/commands/deploy_run.dart';
import 'package:dartway_cli/src/commands/deploy_setup.dart';
import 'package:dartway_cli/src/deploy/stack.dart';
import 'package:dartway_cli/src/vendor_framework.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/deploy_fixtures.dart';

/// Minimal fakes so a test can read what a dry run printed, the same way
/// `deploy_secret_push_test.dart` does for `runSecretPush` — through
/// `dart:io`'s `stdout`, never by changing the function's own signature.
class _CapturingSink implements IOSink {
  final StringBuffer buffer = StringBuffer();

  @override
  void writeln([Object? object = '']) => buffer.writeln(object);

  @override
  void write(Object? object) => buffer.write(object);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CapturingStdout implements Stdout {
  final _CapturingSink sink = _CapturingSink();

  @override
  void writeln([Object? object = '']) => sink.writeln(object);

  @override
  void write(Object? object) => sink.write(object);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

base class _CapturingIOOverrides extends IOOverrides {
  final _CapturingStdout out = _CapturingStdout();

  @override
  Stdout get stdout => out;
}

/// `runDeploy` and `runSetup` used to read `Directory.current` for the
/// project root a second time (`deploy_run.dart:19`, `deploy_setup.dart:26`),
/// disagreeing with the root `deployProjectRoot()` already found and built
/// the stack from in `deploy_command.dart`. Invisible unless the CLI runs
/// from somewhere other than that root — exactly how a project pinned to its
/// Flutter package runs it (`cd u90_flutter && … dartway deploy run`,
/// dartway/dartway#343).
///
/// Neither test below gives `Directory.current` (this package's own root,
/// wherever `dart test` happens to run from) any reason to agree with the
/// stack's project: the stack names a vendored copy of `example/` in a
/// sandbox elsewhere entirely, built the same way
/// `deploy_checks_test.dart`'s "the example passes every local check a
/// deployment runs" builds one. So only reading the project root *from the
/// stack*, not from the working directory, can make either command pass.
void main() {
  final repository = () {
    var dir = Directory.current.absolute;
    while (!Directory(p.join(dir.path, 'template')).existsSync()) {
      if (dir.parent.path == dir.path) return null;
      dir = dir.parent;
    }
    return dir;
  }();

  group('the project root travels with the stack', () {
    late Directory sandbox;
    late Directory root;
    late DwStack stack;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('dw_project_root_');
      root = Directory(p.join(sandbox.path, 'example'));
      copyProject(Directory(p.join(repository!.path, 'example')), root);
      vendorFramework(project: root, monorepo: repository);
      stack = DwStack(
        target: targetFrom(),
        projectRoot: root,
        serverPackage: 'dartway_example_server',
        flutterPackage: 'dartway_example_flutter',
      );
    });

    tearDown(() => sandbox.deleteSync(recursive: true));

    test(
      "deploy run's working-copy checks see the project's Dockerfiles and "
      '.dockerignore exactly like deploy check does',
      () async {
        final args = DeployRunCommand().argParser.parse([
          '--env',
          'staging',
          '--dry-run',
        ]);
        expect(await runDeploy(stack, args), 0);
      },
    );

    test(
      "deploy setup --dry-run renders the project's own deploy/nginx.d and "
      "compose.override.yml, not this package's working directory",
      () async {
        File(p.join(root.path, 'deploy', 'nginx.d', 'http', 'custom.conf'))
          ..createSync(recursive: true)
          ..writeAsStringSync('# custom snippet\n');
        File(
          p.join(root.path, 'deploy', 'compose.override.yml'),
        ).writeAsStringSync('services: {}\n');

        final args = DeploySetupCommand().argParser.parse([
          '--env',
          'staging',
          '--dry-run',
        ]);
        final overrides = _CapturingIOOverrides();
        final code = await IOOverrides.runWithIOOverrides(
          () => runSetup(stack, args),
          overrides,
        );
        expect(code, 0);
        final out = overrides.out.sink.buffer.toString();
        expect(
          out,
          contains('Would upload 1 nginx snippet(s): http/custom.conf'),
        );
        expect(
          out,
          contains(
            'deploy/compose.override.yml is merged straight from the checkout',
          ),
        );
      },
    );
  }, skip: repository == null ? 'not inside the monorepo' : null);
}
