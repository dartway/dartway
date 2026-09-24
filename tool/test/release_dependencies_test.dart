import 'package:dartway_repo_tools/dartway_repo_tools.dart';
import 'package:test/test.dart';

/// Whether a plan's own dependencies resolve — the check `release.dart` was
/// missing when it proposed publishing `dartway_core_flutter` on top of two
/// `publish_to: none` packages.
class _Unit implements PlannedRelease {
  _Unit(this.name, [Map<String, String> dependencyConstraints = const {}])
    : dependencyConstraints = dependencyConstraints;

  @override
  final String name;
  @override
  final Map<String, String> dependencyConstraints;
}

void main() {
  test('a dependency earlier in the plan resolves', () {
    final problems = unresolvableDependenciesOf(
      [
        _Unit('dartway_core_shared'),
        _Unit('dartway_client', {'dartway_core_shared': '^0.20.0'}),
      ],
      localPackages: {},
      pubDevVersions: {},
    );
    expect(problems, isEmpty);
  });

  test('a dependency ordered after it in the plan is refused', () {
    final problems = unresolvableDependenciesOf(
      [
        _Unit('dartway_client', {'dartway_core_shared': '^0.20.0'}),
        _Unit('dartway_core_shared'),
      ],
      localPackages: {},
      pubDevVersions: {},
    );
    expect(problems, hasLength(1));
    expect(problems.single.toString(), contains('dartway_core_shared'));
  });

  test(
    'a dependency outside the plan resolves when pub.dev satisfies its caret',
    () {
      final problems = unresolvableDependenciesOf(
        [
          _Unit('dartway_push_server', {'dartway_core_server': '^0.20.0'}),
        ],
        localPackages: {},
        pubDevVersions: {
          'dartway_core_server': {'0.20.0'},
        },
      );
      expect(problems, isEmpty);
    },
  );

  test('a dependency outside the plan is refused when pub.dev has no version '
      'the caret allows — the zero-major trap: 0.19.0 does not satisfy ^0.20.0, '
      'and neither does 0.21.0', () {
    final problems = unresolvableDependenciesOf(
      [
        _Unit('dartway_push_server', {'dartway_core_server': '^0.20.0'}),
      ],
      localPackages: {},
      pubDevVersions: {
        'dartway_core_server': {'0.19.0', '0.21.0'},
      },
    );
    expect(problems, hasLength(1));
    expect(problems.single.toString(), contains('dartway_core_server'));
  });

  test('a dependency that is publish_to: none and not in the plan is always '
      'refused, whatever pub.dev says — this is the bug that shipped: '
      'dartway_core_flutter depending on dartway_client and '
      'dartway_core_shared while both were publish_to: none', () {
    final problems = unresolvableDependenciesOf(
      [
        _Unit('dartway_core_flutter', {
          'dartway_client': '^0.20.0',
          'dartway_core_shared': '^0.20.0',
        }),
      ],
      localPackages: {
        'dartway_client': const LocalPackageShape(
          name: 'dartway_client',
          publishToNone: true,
        ),
        'dartway_core_shared': const LocalPackageShape(
          name: 'dartway_core_shared',
          publishToNone: true,
        ),
      },
      pubDevVersions: {},
    );
    expect(problems, hasLength(2));
    expect(
      problems.map((p) => p.toString()).join(),
      allOf(contains('dartway_client'), contains('dartway_core_shared')),
    );
  });

  test('a non-caret constraint is checked by exact match', () {
    expect(
      unresolvableDependenciesOf(
        [
          _Unit('a', {'dartway_router': '2.0.0'}),
        ],
        localPackages: {},
        pubDevVersions: {
          'dartway_router': {'2.0.0'},
        },
      ),
      isEmpty,
    );
    expect(
      unresolvableDependenciesOf(
        [
          _Unit('a', {'dartway_router': '2.0.0'}),
        ],
        localPackages: {},
        pubDevVersions: {
          'dartway_router': {'1.9.0'},
        },
      ),
      hasLength(1),
    );
  });
}
