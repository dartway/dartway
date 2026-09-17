import 'package:dartway_repo_tools/dartway_repo_tools.dart';
import 'package:test/test.dart';

/// The order `release.dart` publishes in: the one answer a mistake in cannot be
/// taken back from, because half a release is already on pub.dev.
class _Unit implements ReleaseUnit {
  _Unit(this.name, [List<String> dependencies = const []])
    : dependencies = dependencies.toSet();

  @override
  final String name;
  @override
  final Set<String> dependencies;
}

void main() {
  List<String> order(List<_Unit> plan) =>
      ReleaseOrder.of(plan).map((unit) => unit.name).toList();

  test('publishes nothing before what it depends on', () {
    final names = order([
      _Unit('dartway_core_flutter', ['dartway_client', 'dartway_router']),
      _Unit('dartway_client', ['dartway_core_shared']),
      _Unit('dartway_router'),
      _Unit('dartway_core_shared'),
    ]);
    int at(String name) => names.indexOf(name);
    expect(at('dartway_core_shared'), lessThan(at('dartway_client')));
    expect(at('dartway_client'), lessThan(at('dartway_core_flutter')));
    expect(at('dartway_router'), lessThan(at('dartway_core_flutter')));
    expect(names, hasLength(4));
  });

  test('a dependency outside the plan is already published and waits for '
      'nothing', () {
    expect(
      order([
        _Unit('dartway_push_server', ['dartway_core_server']),
      ]),
      ['dartway_push_server'],
    );
  });

  test('a cycle is refused rather than looped over', () {
    expect(
      () => ReleaseOrder.of([
        _Unit('a', ['b']),
        _Unit('b', ['a']),
      ]),
      throwsA(isA<StateError>()),
    );
  });

  test('verify refuses an order that publishes a dependent first', () {
    expect(
      () => ReleaseOrder.verify([
        _Unit('dartway_client', ['dartway_core_shared']),
        _Unit('dartway_core_shared'),
      ]),
      throwsA(isA<StateError>()),
    );
    ReleaseOrder.verify([
      _Unit('dartway_core_shared'),
      _Unit('dartway_client', ['dartway_core_shared']),
    ]);
  });
}
