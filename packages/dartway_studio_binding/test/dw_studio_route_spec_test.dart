import 'package:dartway_router/dartway_router.dart';
import 'package:dartway_studio_binding/dartway_studio_binding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RouterState extends ChangeNotifier {}

class _Page extends StatelessWidget {
  const _Page();

  @override
  Widget build(BuildContext context) => const Text('page');
}

enum _Routes implements DwNavigationRoute<_RouterState> {
  club(DwNavigationRouteDescriptor.zoneRoot(pageWidget: _Page())),
  schedule(
    DwNavigationRouteDescriptor.simple(pageWidget: _Page(), parent: club),
  );

  const _Routes(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<_RouterState> descriptor;

  @override
  String get zoneRoot => '';

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;

  @override
  List<DwNavigationGuard<_RouterState>> get zoneGuards => [];
}

void main() {
  test('a screen passport derives its paths from the route, not from text', () {
    final spec = dwStudioSpecForRoute(
      _Routes.schedule,
      title: 'Schedule',
      purpose: 'What is on this week.',
      discussionQuestions: const ['Whose week is it?'],
    );

    // The point of taking the route rather than a string: rename a path and
    // the passport follows, instead of pointing at a screen that is gone.
    expect(spec.path, _Routes.schedule.fullPath);
    expect(spec.parentPath, _Routes.club.fullPath);
    expect(spec.title, 'Schedule');
    expect(spec.purpose, 'What is on this week.');
    expect(spec.discussionQuestions, ['Whose week is it?']);
  });

  test('a zone root reports no parent', () {
    expect(
      dwStudioSpecForRoute(
        _Routes.club,
        title: 'Club',
        purpose: 'The zone.',
      ).parentPath,
      isNull,
    );
  });

  test('a passport with nothing to discuss carries an empty list', () {
    expect(
      dwStudioSpecForRoute(
        _Routes.club,
        title: 'Club',
        purpose: 'The zone.',
      ).discussionQuestions,
      isEmpty,
    );
  });
}
