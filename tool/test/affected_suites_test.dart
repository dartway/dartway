import 'dart:io';

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
    package(
      'packages/dartway_telegram',
      'dependencies:\n  dartway_core_shared: ^0.1.0\n',
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
    package(
      'example/dartway_example_server',
      'dependencies:\n  dartway_core_server: ^0.1.0\n',
    ),
    package('tool', 'dependencies:\n  dartway_cli: ^0.1.0\n'),
    const RepoPackage('js/studio-bridge', 'js/studio-bridge/package.json', {}),
  ];
  final all = {for (final package in packages) package.path};

  const contract =
      'packages/dartway_generator/test/contract_behavior_test.dart';
  const update = 'packages/dartway_cli/test/update_command_test.dart';
  const deploy = 'packages/dartway_cli/test/deploy_test.dart';
  const entity = 'packages/dartway_generator/test/entity_test.dart';
  const generate =
      'packages/dartway_cli/lib/src/commands/generate_command.dart';
  final testFiles = [...narrowTests.keys, deploy, entity];

  Set<String> suites(List<String> changed) => affectedChecks(
    packages,
    changed,
    closures: {
      contract: {contract, generate},
    },
    testFiles: testFiles,
  ).suites;

  // By package: a package some of whose files run counts as affected.
  Set<String> affected(List<String> changed) => {
    for (final entry in suites(changed))
      entry.endsWith('_test.dart')
          ? entry.substring(0, entry.indexOf('/test/'))
          : entry,
  };

  test('a package and everything that depends on it, through every '
      'dependency section', () {
    expect(affected(['packages/dartway_core_server/lib/a.dart']), {
      'packages/dartway_core_server',
      'packages/dartway_generator', // dev_dependencies
      'packages/dartway_cli', // dev_dependencies
      'example/dartway_example_flutter', // dependency_overrides
      'example/dartway_example_server',
      'tool',
    });
  });

  test('a client package leaves the generator and the CLI alone', () {
    expect(affected(['packages/dartway_core_flutter/lib/a.dart']), {
      'packages/dartway_core_flutter',
      'example/dartway_example_flutter',
      'tool', // reads every package
    });
  });

  test('a package the example and the generator do not use leaves the CLI '
      'alone', () {
    expect(affected(['packages/dartway_telegram/lib/a.dart']), {
      'packages/dartway_telegram',
      'tool',
    });
  });

  test('readers do not pass on what they read', () {
    // The CLI's suites read the docs; the tool depends on the CLI's code.
    expect(affected(['docs/a.md']), {'packages/dartway_cli', 'tool'});
    expect(affectedChecks(packages, ['docs/a.md']).code, isEmpty);
  });

  test('a file belongs to the innermost package holding it', () {
    expect(affected(['packages/dartway_lints/example/lib/bad.dart']), {
      'packages/dartway_lints/example',
      'packages/dartway_lints', // reads its example
      'packages/dartway_cli', // reads packages/dartway_lints/
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
    // One segment for `*`, not a prefix.
    expect(
      affected(['packages/dartway_telegram/pubspec.yaml']),
      contains('packages/dartway_cli'),
    );
    expect(
      affected(['packages/dartway_telegram/lib/pubspec.yaml']),
      isNot(contains('packages/dartway_cli')),
    );
  });

  test('a js package stands alone', () {
    expect(affected(['js/studio-bridge/src/a.ts']), {'js/studio-bridge'});
  });

  test('what pins or picks the suites runs everything', () {
    for (final file in runsEverything) {
      expect(affected([file]), all, reason: file);
      expect(affectedChecks(packages, [file]).code, all, reason: file);
    }
  });

  test('a file nothing places runs everything', () {
    expect(affected(['newdir/thing.txt']), all);
    expect(affected(['Makefile']), all);
  });

  test('a file no suite reads runs nothing', () {
    expect(affected(['LICENSE', '.github/workflows/images.yml']), isEmpty);
  });

  test('a heavy test runs on what it runs, not with its package', () {
    // A command the heavy tests do not run: the rest of the CLI's files.
    expect(suites(['packages/dartway_cli/lib/src/deploy/a.dart']), {
      deploy,
      'example/dartway_example_flutter',
      'tool',
    });
    // A file in the closure: that test alone, its package's others stay.
    expect(suites([generate]), containsAll([contract, deploy]));
    expect(suites([generate]), isNot(contains(entity)));
    expect(suites([generate]), isNot(contains('packages/dartway_generator')));
    // Its own file, and its package's fixtures and support code.
    expect(suites([contract]), contains('packages/dartway_generator'));
    expect(
      suites(['packages/dartway_generator/test/support/project.dart']),
      contains('packages/dartway_generator'),
    );
    expect(suites([entity]), isNot(contains(contract)));
    // What it reads.
    expect(suites(['docs/migrations/a.md']), contains(update));
    expect(suites(['docs/a.md']), isNot(contains(update)));
  });

  test('a heavy test follows the runtime code of what it runs', () {
    // The generator's own dependency reaches the program it runs.
    expect(
      suites(['packages/dartway_core_shared/lib/a.dart']),
      contains('packages/dartway_generator'),
    );
    // Its dev dependency reaches its other suites only.
    final server = suites(['packages/dartway_core_server/lib/a.dart']);
    expect(server, contains(entity));
    expect(server, isNot(contains(contract)));
    // A package's tests are not its runtime code.
    final sharedTest = suites([
      'packages/dartway_core_shared/test/a_test.dart',
    ]);
    expect(sharedTest, contains(entity));
    expect(sharedTest, isNot(contains(contract)));
  });

  test('every heavy test and what it names exists', () {
    var root = Directory.current.absolute;
    while (!File('${root.path}/tool/checks.sh').existsSync()) {
      root = root.parent;
    }
    bool exists(String path) =>
        FileSystemEntity.typeSync('${root.path}/$path') !=
        FileSystemEntityType.notFound;
    for (final MapEntry(key: test, value: narrow) in narrowTests.entries) {
      expect(exists(test), isTrue, reason: test);
      for (final path in [...narrow.closureOf, ...narrow.runtime]) {
        expect(exists(path), isTrue, reason: '$test names $path');
      }
    }
  });

  test('an import closure follows relative and local package imports', () {
    final files = {
      'packages/a/lib/a.dart':
          "import 'dart:io';\n"
          "import 'package:b/b.dart' if (dart.library.js) 'web.dart';\n"
          "import 'package:path/path.dart';\n"
          "part 'a.g.dart';\n",
      'packages/a/lib/web.dart': '',
      'packages/a/lib/a.g.dart': "part of 'a.dart';\n",
      'packages/b/lib/b.dart': "export 'src/missing.dart';\n",
    };
    expect(
      importClosure(
        ['packages/a/lib/a.dart'],
        [
          const RepoPackage('packages/a', 'a', {}),
          const RepoPackage('packages/b', 'b', {}),
        ],
        (path) => files[path],
      ),
      {
        'packages/a/lib/a.dart',
        'packages/a/lib/web.dart',
        'packages/a/lib/a.g.dart',
        'packages/a/pubspec.yaml',
        'packages/b/lib/b.dart',
        'packages/b/lib/src/missing.dart',
        'packages/b/pubspec.yaml',
      },
    );
  });

  test('directives are read from the top of the file only', () {
    expect(
      directiveUris(
        '#!/usr/bin/env dart\n'
        '// A comment.\n'
        '/* A block\n   comment. */\n'
        "@Tags([\n  'slow',\n])\n"
        'library;\n'
        '\n'
        "import 'a.dart'\n    show A;\n"
        'export "b.dart";\n'
        '\n'
        'void main() {}\n'
        "const fixture = '''\n"
        "import 'c.dart';\n"
        "''';\n",
      ),
      ['a.dart', 'b.dart'],
    );
  });

  test('a pubspec without a name is refused, not skipped', () {
    expect(
      () => RepoPackage.fromPubspec('packages/x', 'version: 1.0.0\n'),
      throwsFormatException,
    );
  });
}
