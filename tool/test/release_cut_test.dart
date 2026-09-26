import 'package:dartway_repo_tools/dartway_repo_tools.dart';
import 'package:test/test.dart';

/// The mechanical half of cutting a release (#337): the family's own version,
/// and every caret on it, moving from a between-releases prerelease to the
/// plain version pub.dev receives. Exercised against fixture pubspec text —
/// small strings standing in for a workspace's `packages/`, `template/` and
/// `example/` — rather than real files: `release.dart` is the thin layer that
/// finds those files and writes the result back.
void main() {
  group('familyLockstepProblem', () {
    test('six matching versions agree', () {
      final versions = {for (final name in familyPackageNames) name: '0.21.0-dev.6'};
      expect(familyLockstepProblem(versions), isNull);
    });

    test('a missing family member is named', () {
      final versions = {for (final name in familyPackageNames) name: '0.21.0-dev.6'}
        ..remove('dartway_orm');
      expect(familyLockstepProblem(versions), contains('dartway_orm'));
    });

    test('a family member out of step with the rest is refused', () {
      final versions = {for (final name in familyPackageNames) name: '0.21.0-dev.6'};
      versions['dartway_client'] = '0.21.0-dev.5';
      final problem = familyLockstepProblem(versions);
      expect(problem, isNotNull);
      expect(problem, contains('not in lockstep'));
      expect(problem, contains('dartway_client 0.21.0-dev.5'));
    });
  });

  group('plainOf', () {
    test('strips a -dev.N prerelease', () {
      expect(plainOf('0.21.0-dev.6'), '0.21.0');
    });

    test('a plain version has nothing to strip', () {
      expect(plainOf('0.21.0'), isNull);
    });
  });

  test('cutFirstMessage names the prerelease', () {
    expect(
      cutFirstMessage('0.21.0-dev.6'),
      'cut the release first: family at 0.21.0-dev.6',
    );
  });

  group('cutOwnVersion', () {
    test('cuts a family package\'s own top-level version', () {
      const pubspec = 'name: dartway_core_shared\nversion: 0.21.0-dev.6\n';
      expect(
        cutOwnVersion(pubspec, from: '0.21.0-dev.6', to: '0.21.0'),
        'name: dartway_core_shared\nversion: 0.21.0\n',
      );
    });

    test('leaves a trailing comment on the version line untouched', () {
      const pubspec = 'version: 0.21.0-dev.6 # cut by release.dart\n';
      expect(
        cutOwnVersion(pubspec, from: '0.21.0-dev.6', to: '0.21.0'),
        'version: 0.21.0 # cut by release.dart\n',
      );
    });

    test('null when the file states a different version', () {
      const pubspec = 'name: dartway_router\nversion: 2.0.0\n';
      expect(cutOwnVersion(pubspec, from: '0.21.0-dev.6', to: '0.21.0'), isNull);
    });

    test(
      'never touches an indented version: under dependency_overrides — only '
      'a top-level version: is a package\'s own',
      () {
        const pubspec =
            'name: dartway_client\n'
            'dependency_overrides:\n'
            '  dartway_core_shared:\n'
            '    version: 0.21.0-dev.6\n';
        expect(cutOwnVersion(pubspec, from: '0.21.0-dev.6', to: '0.21.0'), isNull);
      },
    );
  });

  group('cutDependencyCarets', () {
    test('cuts a bare caret dependency on a family package', () {
      const pubspec =
          'dependencies:\n  dartway_core_flutter: ^0.21.0-dev.6\n';
      expect(
        cutDependencyCarets(pubspec, from: '0.21.0-dev.6', to: '0.21.0'),
        'dependencies:\n  dartway_core_flutter: ^0.21.0\n',
      );
    });

    test('cuts every family caret in the same file, leaving others alone', () {
      const pubspec =
          'dependencies:\n'
          '  dartway_core_server: ^0.21.0-dev.6\n'
          '  dartway_generator: ^0.21.0-dev.6\n'
          '  dartway_shared_preferences: ^0.6.0\n';
      expect(
        cutDependencyCarets(pubspec, from: '0.21.0-dev.6', to: '0.21.0'),
        'dependencies:\n'
        '  dartway_core_server: ^0.21.0\n'
        '  dartway_generator: ^0.21.0\n'
        '  dartway_shared_preferences: ^0.6.0\n',
      );
    });

    test('a path form under dependency_overrides has no caret to cut', () {
      const pubspec =
          'dependency_overrides:\n  dartway_core_shared:\n    path: ../dartway_core_shared\n';
      expect(
        cutDependencyCarets(pubspec, from: '0.21.0-dev.6', to: '0.21.0'),
        isNull,
      );
    });

    test('null when the file states no family caret at all', () {
      const pubspec = 'dependencies:\n  dartway_router: ^2.0.0\n';
      expect(
        cutDependencyCarets(pubspec, from: '0.21.0-dev.6', to: '0.21.0'),
        isNull,
      );
    });
  });

  group('cutPubspecContents', () {
    test('a family package\'s own pubspec: its version and its own family '
        'carets both move', () {
      const pubspec =
          'name: dartway_core_server\n'
          'version: 0.21.0-dev.6\n'
          'dependencies:\n'
          '  dartway_client: ^0.21.0-dev.6\n'
          '  dartway_core_shared: ^0.21.0-dev.6\n'
          '  dartway_orm: ^0.21.0-dev.6\n';
      expect(
        cutPubspecContents(pubspec, from: '0.21.0-dev.6', to: '0.21.0'),
        'name: dartway_core_server\n'
        'version: 0.21.0\n'
        'dependencies:\n'
        '  dartway_client: ^0.21.0\n'
        '  dartway_core_shared: ^0.21.0\n'
        '  dartway_orm: ^0.21.0\n',
      );
    });

    test('a satellite in template/ or example/: only its family caret moves, '
        'never its own version', () {
      const pubspec =
          'name: dartway_starter_flutter\n'
          "publish_to: 'none'\n"
          'version: 1.0.0+1\n'
          'dependencies:\n'
          '  dartway_core_flutter: ^0.21.0-dev.6\n'
          '  dartway_shared_preferences: ^0.6.0\n';
      expect(
        cutPubspecContents(pubspec, from: '0.21.0-dev.6', to: '0.21.0'),
        'name: dartway_starter_flutter\n'
        "publish_to: 'none'\n"
        'version: 1.0.0+1\n'
        'dependencies:\n'
        '  dartway_core_flutter: ^0.21.0\n'
        '  dartway_shared_preferences: ^0.6.0\n',
      );
    });

    test('a pubspec with no mention of the family at all is left alone', () {
      const pubspec = 'name: dartway_router\nversion: 2.0.0\n';
      expect(
        cutPubspecContents(pubspec, from: '0.21.0-dev.6', to: '0.21.0'),
        isNull,
      );
    });
  });
}
