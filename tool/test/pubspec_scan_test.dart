import 'package:dartway_repo_tools/dartway_repo_tools.dart';
import 'package:test/test.dart';

/// Reading a `pubspec.yaml` for the release scripts through real YAML — the
/// forms a line-based regex used to read as "nothing here", the same answer
/// as a package that genuinely has none of it.
void main() {
  group('pubspecValue', () {
    test('reads a top-level scalar', () {
      final doc = parsePubspec('name: dartway_client\nversion: 0.20.0\n');
      expect(pubspecValue(doc, 'name'), 'dartway_client');
      expect(pubspecValue(doc, 'version'), '0.20.0');
    });

    test('is absent when the key is not there', () {
      expect(
        pubspecValue(parsePubspec('name: dartway_client\n'), 'publish_to'),
        isNull,
      );
    });

    test('does not match the key nested under another section', () {
      // `publish_to` inside a mapping must not read as the top-level key.
      expect(
        pubspecValue(
          parsePubspec('dependencies:\n  publish_to_something: 1\n'),
          'publish_to',
        ),
        isNull,
      );
    });

    test('a trailing comment does not become part of the value', () {
      expect(
        pubspecValue(
          parsePubspec('version: 0.20.0 # bumped for the rewrite\n'),
          'version',
        ),
        '0.20.0',
      );
    });

    test('publish_to: none survives a trailing comment', () {
      expect(
        pubspecValue(
          parsePubspec('publish_to: none # see #142\n'),
          'publish_to',
        ),
        isNotNull,
      );
    });
  });

  group('dartwayDependencyConstraints', () {
    String pubspec(String dependenciesBlock) =>
        'name: p\ndependencies:\n$dependenciesBlock';

    test('reads every dartway_* dependency and its caret', () {
      final deps = dartwayDependencyConstraints(
        parsePubspec(
          'name: dartway_core_server\n'
          'dependencies:\n'
          '  crypto: ^3.0.6\n'
          '  dartway_client: ^0.20.0\n'
          '  dartway_core_shared: ^0.20.0\n'
          '  dartway_orm: ^0.20.0\n'
          '  meta: ^1.16.0\n'
          'dev_dependencies:\n'
          '  lints: ^6.0.0\n',
        ),
      );
      expect(deps, {
        'dartway_client': '^0.20.0',
        'dartway_core_shared': '^0.20.0',
        'dartway_orm': '^0.20.0',
      });
    });

    test('ignores dev_dependencies and dependency_overrides — neither travels '
        'to a stranger resolving the package from pub.dev', () {
      final deps = dartwayDependencyConstraints(
        parsePubspec(
          'name: p\n'
          'dependencies:\n'
          '  dartway_core_shared: ^0.20.0\n'
          'dev_dependencies:\n'
          '  dartway_core_server: ^0.20.0\n'
          'dependency_overrides:\n'
          '  dartway_core_shared:\n'
          '    path: ../dartway_core_shared\n',
        ),
      );
      expect(deps, {'dartway_core_shared': '^0.20.0'});
    });

    test('a package with no dartway_* dependency reads as empty', () {
      expect(
        dartwayDependencyConstraints(
          parsePubspec('name: p\ndependencies:\n  meta: ^1.16.0\n'),
        ),
        isEmpty,
      );
    });

    test('a package with a dartway_* dependency is never read as having none — '
        'the regression a line-based regex ending `\\\$` inside a raw string '
        'left behind: an escaped literal dollar sign, not the end-of-line '
        'anchor, matched nothing at all', () {
      expect(
        dartwayDependencyConstraints(
          parsePubspec(pubspec('  dartway_client: ^0.20.0\n')),
        ),
        isNotEmpty,
      );
    });

    test(
      'a trailing comment on a dependency line is not part of its caret',
      () {
        final deps = dartwayDependencyConstraints(
          parsePubspec(pubspec('  dartway_client: ^0.20.0 # local dev only\n')),
        );
        expect(deps, {'dartway_client': '^0.20.0'});
      },
    );

    test('a dependency pinned as a map (hosted:/version: on their own lines) '
        'reads its version the same as the bare-string form', () {
      final deps = dartwayDependencyConstraints(
        parsePubspec(
          pubspec(
            '  dartway_client:\n'
            '    hosted: https://pub.dev\n'
            '    version: ^0.20.0\n',
          ),
        ),
      );
      expect(deps, {'dartway_client': '^0.20.0'});
    });

    test('a dartway_* dependency in a form this cannot read as a version '
        'throws rather than silently reading as "depends on nothing" — '
        'dart pub publish itself refuses a path or git dependency under '
        'dependencies:, so a dartway_* entry shaped like one here is a bug '
        'in this monorepo, not a form to shrug at', () {
      expect(
        () => dartwayDependencyConstraints(
          parsePubspec(
            pubspec('  dartway_client:\n    path: ../dartway_client\n'),
          ),
        ),
        throwsFormatException,
      );
    });

    test('dependencies: that is not a mapping throws', () {
      expect(
        () => dartwayDependencyConstraints(
          parsePubspec('name: p\ndependencies: not_a_map\n'),
        ),
        throwsFormatException,
      );
    });
  });

  group('parsePubspec', () {
    test('a document that is not a mapping throws', () {
      expect(
        () => parsePubspec('- just\n- a\n- list\n'),
        throwsFormatException,
      );
    });

    test('invalid YAML throws', () {
      expect(
        () => parsePubspec('name: ["unterminated\n'),
        throwsFormatException,
      );
    });
  });
}
