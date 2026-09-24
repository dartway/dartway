import 'package:dartway_repo_tools/dartway_repo_tools.dart';
import 'package:test/test.dart';

/// Reading a `pubspec.yaml` for the release scripts — no YAML parser, just
/// the handful of scalar lines they act on.
void main() {
  group('pubspecValue', () {
    test('reads a top-level scalar', () {
      expect(
        pubspecValue(['name: dartway_client', 'version: 0.20.0'], 'name'),
        'dartway_client',
      );
      expect(
        pubspecValue(['name: dartway_client', 'version: 0.20.0'], 'version'),
        '0.20.0',
      );
    });

    test('is absent when the key is not there', () {
      expect(pubspecValue(['name: dartway_client'], 'publish_to'), isNull);
    });

    test('does not match the key nested under another section', () {
      // `publish_to` inside a comment or an unrelated indented value must not
      // read as the top-level key.
      expect(
        pubspecValue([
          'dependencies:',
          '  publish_to_something: 1',
        ], 'publish_to'),
        isNull,
      );
    });
  });

  group('dartwayDependencyConstraints', () {
    test('reads every dartway_* dependency and its caret', () {
      final deps = dartwayDependencyConstraints([
        'name: dartway_core_server',
        'dependencies:',
        '  crypto: ^3.0.6',
        '  dartway_client: ^0.20.0',
        '  dartway_core_shared: ^0.20.0',
        '  dartway_orm: ^0.20.0',
        '  meta: ^1.16.0',
        'dev_dependencies:',
        '  lints: ^6.0.0',
      ]);
      expect(deps, {
        'dartway_client': '^0.20.0',
        'dartway_core_shared': '^0.20.0',
        'dartway_orm': '^0.20.0',
      });
    });

    test('ignores dev_dependencies and dependency_overrides — neither travels '
        'to a stranger resolving the package from pub.dev', () {
      final deps = dartwayDependencyConstraints([
        'dependencies:',
        '  dartway_core_shared: ^0.20.0',
        'dev_dependencies:',
        '  dartway_core_server: ^0.20.0',
        'dependency_overrides:',
        '  dartway_core_shared:',
        '    path: ../dartway_core_shared',
      ]);
      expect(deps, {'dartway_core_shared': '^0.20.0'});
    });

    test('a package with no dartway_* dependency reads as empty, not as every '
        'line silently dropped — the regression this test exists for: a '
        'pattern ending `\\\$` inside a raw string is an escaped literal dollar '
        'sign, not the end-of-line anchor, and matched nothing at all', () {
      expect(
        dartwayDependencyConstraints([
          'dependencies:',
          '  dartway_client: ^0.20.0',
        ]),
        isNotEmpty,
      );
    });
  });
}
