import 'package:dartway_repo_tools/dartway_repo_tools.dart';
import 'package:test/test.dart';

void main() {
  RepoPackage package(String path, [String dependencies = '']) =>
      RepoPackage.fromPubspec(
        path,
        'name: ${path.split('/').last}\n$dependencies',
      );

  final packages = [
    package('packages/dartway_core_shared'),
    package(
      'packages/dartway_core_server',
      'dependencies:\n  dartway_core_shared: ^0.1.0\n  path: ^1.9.0\n',
    ),
    package(
      'packages/dartway_core_flutter',
      'dependencies:\n  dartway_core_shared: ^0.1.0\n',
    ),
    package(
      'packages/dartway_generator',
      'dependencies:\n  dartway_core_shared: ^0.1.0\n'
          'dev_dependencies:\n  dartway_core_server:\n'
          '    path: ../dartway_core_server\n',
    ),
    package(
      'packages/dartway_cli',
      'dev_dependencies:\n  dartway_core_server: ^0.1.0\n',
    ),
    package('packages/dartway_lints'),
    package('packages/dartway_lints/example'),
    package(
      'example/dartway_example_flutter',
      'dependencies:\n  dartway_core_flutter: ^0.1.0\n'
          'dependency_overrides:\n  dartway_cli:\n'
          '    path: ../../packages/dartway_cli\n',
    ),
    package('example/dartway_example_shared'),
    package('tool', 'dependencies:\n  dartway_cli: ^0.1.0\n'),
    const RepoPackage('js/studio-bridge', 'js/studio-bridge/package.json', {}),
  ];
  final all = {for (final package in packages) package.path};

  Set<String> affected(List<String> changed) =>
      affectedSuites(packages, changed);

  test('a package and everything that depends on it, through every '
      'dependency section', () {
    expect(affected(['packages/dartway_core_server/lib/a.dart']), {
      'packages/dartway_core_server',
      'packages/dartway_generator', // dev_dependencies
      'packages/dartway_cli', // dev_dependencies
      'example/dartway_example_flutter', // dependency_overrides
      'tool',
    });
  });

  test('a client package leaves the generator alone', () {
    expect(affected(['packages/dartway_core_flutter/lib/a.dart']), {
      'packages/dartway_core_flutter',
      'example/dartway_example_flutter',
      'packages/dartway_cli', // reads every package's sources
      'tool',
    });
  });

  test('a file belongs to the innermost package holding it', () {
    expect(affected(['packages/dartway_lints/example/lib/bad.dart']), {
      'packages/dartway_lints/example',
      'packages/dartway_lints', // reads its example
      'packages/dartway_cli', // reads packages/dartway_lints/
      'example/dartway_example_flutter',
      'tool',
    });
    expect(
      affected(['packages/dartway_lints/lib/rule.dart']),
      contains('packages/dartway_lints'),
    );
    expect(
      affected(['packages/dartway_lints/lib/rule.dart']),
      isNot(contains('packages/dartway_lints/example')),
    );
  });

  test('paths a suite reads outside its package reach it', () {
    expect(affected(['docs/3-flutter/media.md']), {
      'packages/dartway_cli',
      'example/dartway_example_flutter',
      'tool',
    });
    expect(
      affected(['example/dartway_example_shared/lib/a.dart']),
      containsAll(['packages/dartway_generator', 'packages/dartway_cli']),
    );
    expect(
      affected(['example/dartway_example_flutter/lib/a.dart']),
      isNot(contains('packages/dartway_generator')),
    );
    // The CLI scans every test/ for protocol literals; the generator runs
    // the CLI.
    expect(
      affected(['tool/test/a_test.dart']),
      contains('packages/dartway_cli'),
    );
    expect(
      affected(['packages/dartway_cli/lib/a.dart']),
      contains('packages/dartway_generator'),
    );
  });

  test('a js package stands alone', () {
    expect(affected(['js/studio-bridge/src/a.ts']), {'js/studio-bridge'});
  });

  test('what pins or picks the suites runs everything', () {
    for (final file in runsEverything) {
      expect(affected([file]), all, reason: file);
    }
  });

  test('a file nothing places runs everything', () {
    expect(affected(['newdir/thing.txt']), all);
    expect(affected(['Makefile']), all);
  });

  test('a file no suite reads runs nothing', () {
    expect(affected(['LICENSE', '.github/workflows/images.yml']), isEmpty);
  });

  test('a pubspec without a name is refused, not skipped', () {
    expect(
      () => RepoPackage.fromPubspec('packages/x', 'version: 1.0.0\n'),
      throwsFormatException,
    );
  });
}
