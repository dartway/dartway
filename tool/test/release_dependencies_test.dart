import 'package:dartway_repo_tools/dartway_repo_tools.dart';
import 'package:test/test.dart';

/// Whether a plan's own dependencies resolve — the check `release.dart` was
/// missing when it proposed publishing `dartway_core_flutter` on top of two
/// `publish_to: none` packages.
class _Unit implements PlannedRelease {
  _Unit(
    this.name, [
    Map<String, String> dependencyConstraints = const {},
    this.version = '1.0.0',
  ]) : dependencyConstraints = dependencyConstraints;

  @override
  final String name;
  @override
  final String version;
  @override
  final Map<String, String> dependencyConstraints;
}

void main() {
  test('a dependency earlier in the plan, published at a version its caret '
      'allows, resolves', () {
    final problems = unresolvableDependenciesOf(
      [
        _Unit('dartway_core_shared', const {}, '0.20.0'),
        _Unit('dartway_client', {'dartway_core_shared': '^0.20.0'}, '0.20.0'),
      ],
      localPackages: {},
      pubDevVersions: {},
    );
    expect(problems, isEmpty);
  });

  test('a dependency ordered after it in the plan is refused', () {
    final problems = unresolvableDependenciesOf(
      [
        _Unit('dartway_client', {'dartway_core_shared': '^0.20.0'}, '0.20.0'),
        _Unit('dartway_core_shared', const {}, '0.20.0'),
      ],
      localPackages: {},
      pubDevVersions: {},
    );
    expect(problems, hasLength(1));
    expect(problems.single.toString(), contains('dartway_core_shared'));
  });

  test('a dependency earlier in the plan, but published at a version its own '
      'caret does not allow, is refused — being ordered first is not being '
      'satisfied: `^0.9.0` on a package this same plan publishes as `0.10.0` '
      'resolves on pub.dev exactly as badly as a dependency left out of the '
      'plan entirely', () {
    final problems = unresolvableDependenciesOf(
      [
        _Unit('dartway_studio_bridge', const {}, '0.10.0'),
        _Unit('dartway_studio_binding', {
          'dartway_studio_bridge': '^0.9.0',
        }, '0.2.0'),
      ],
      localPackages: {},
      pubDevVersions: {},
    );
    expect(problems, hasLength(1));
    expect(problems.single.toString(), contains('dartway_studio_bridge'));
    expect(problems.single.toString(), contains('0.10.0'));
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

  test('publish_to: none refuses even when pub.dev already lists a version '
      'satisfying the caret — the two errors read differently ("publish_to: '
      'none" vs. "pub.dev has no version"), and without this case the '
      'earlier test alone could not tell the two branches apart: an empty '
      'pubDevVersions map fails the ordinary "not satisfied" check on its '
      'own, so mutating the publishToNone branch to never fire (`if (false '
      '&& ...)`) left every test here green', () {
    final problems = unresolvableDependenciesOf(
      [
        _Unit('dartway_studio_binding', {'dartway_client': '^0.20.0'}),
      ],
      localPackages: {
        'dartway_client': const LocalPackageShape(
          name: 'dartway_client',
          publishToNone: true,
        ),
      },
      pubDevVersions: {
        // A version that would satisfy the caret if this package were
        // actually resolvable from pub.dev — it is not, and that is the
        // one fact this test exists to prove is checked first.
        'dartway_client': {'0.20.0'},
      },
    );
    expect(problems, hasLength(1));
    expect(problems.single.toString(), contains('publish_to: none'));
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
