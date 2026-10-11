import 'package:dartway_router/dartway_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

typedef ExitRouterState = ({bool unused});

enum ExitParams<T> with DwNavigationParamsMixin<T> {
  courseId<int>(),
  lessonId<int>(),
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => const Text('Home');
}

class CoursePage extends StatelessWidget {
  const CoursePage({super.key});

  @override
  Widget build(BuildContext context) => const Text('Course');
}

class LessonPage extends StatelessWidget {
  const LessonPage({super.key});

  @override
  Widget build(BuildContext context) => const Text('Lesson');
}

/// Every location the course's exit hook was asked about.
final leavingCourse = <DwNavigationTarget>[];

/// The course's exit hook: a top-level function, the shape a `const`
/// descriptor allows. It asks in a sheet opened from the navigator's context.
Future<bool> askBeforeLeavingCourse(
  BuildContext context,
  DwNavigationTarget leaving,
) async {
  leavingCourse.add(leaving);
  final answer = await showModalBottomSheet<bool>(
    context: context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Rate the lesson before leaving?'),
        TextButton(
          onPressed: () => Navigator.of(sheetContext).pop(false),
          child: const Text('Stay'),
        ),
        TextButton(
          onPressed: () => Navigator.of(sheetContext).pop(true),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
  return answer ?? false;
}

enum ExitRoutes implements DwNavigationRoute<ExitRouterState> {
  home(DwNavigationRouteDescriptor.simple(pageWidget: HomePage())),
  course(
    DwNavigationRouteDescriptor.parameterized(
      pageWidget: CoursePage(),
      parameter: ExitParams.courseId,
      parent: null,
      extraPathSegment: 'course',
      onExit: askBeforeLeavingCourse,
    ),
  ),
  lesson(
    DwNavigationRouteDescriptor.parameterized(
      pageWidget: LessonPage(),
      parameter: ExitParams.lessonId,
      parent: course,
      extraPathSegment: 'lesson',
    ),
  );

  const ExitRoutes(this.descriptor);

  @override
  final DwNavigationRouteDescriptor<ExitRouterState> descriptor;

  @override
  String get zoneRoot => '';

  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;

  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;

  @override
  List<DwNavigationGuard<ExitRouterState>> get zoneGuards => [];
}

/// Opens the app at [location] and returns its router.
Future<GoRouter> openAt(WidgetTester tester, String location) async {
  final router = buildRouter<ExitRouterState>(
    (ref) => DwAppRouter<ExitRouterState>(
      ref: ref,
      navigationZones: [ExitRoutes.values],
      pageBuilder: DwPageBuilder.material,
      options: DwGoRouterOptions(initialLocation: location),
    ),
  ).router;
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

/// What the engine sends when the browser's address changes — back,
/// forward, a typed URL: a new location, not a pop.
Future<void> browserMovesTo(WidgetTester tester, String location) async {
  final message = const JSONMethodCodec().encodeMethodCall(
    MethodCall('pushRouteInformation', {'location': location, 'state': null}),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    message,
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(leavingCourse.clear);

  group('A route\'s onExit', () {
    testWidgets('asks on a change of address, and lets the move go on', (
      tester,
    ) async {
      await openAt(tester, '/course/7');
      expect(find.text('Course'), findsOneWidget);

      await browserMovesTo(tester, '/home');

      expect(find.text('Rate the lesson before leaving?'), findsOneWidget);
      expect(find.text('Course'), findsOneWidget);
      expect(find.text('Home'), findsNothing);

      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Course'), findsNothing);
      expect(leavingCourse, hasLength(1));
    });

    testWidgets('keeps the person on the route when it answers false', (
      tester,
    ) async {
      final router = await openAt(tester, '/course/7');

      await browserMovesTo(tester, '/home');
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();

      expect(find.text('Course'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/course/7');
    });

    testWidgets('is asked once, as the leaving route, when a nested child '
        'leaves with it', (tester) async {
      await openAt(tester, '/course/7/lesson/3');
      expect(find.text('Lesson'), findsOneWidget);

      await browserMovesTo(tester, '/home');
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(leavingCourse, hasLength(1));
      expect(leavingCourse.single.routeName, 'course');
      expect(leavingCourse.single.pathParameters['courseId'], '7');
    });

    testWidgets('asks on go the same way', (tester) async {
      final router = await openAt(tester, '/course/7');

      router.go('/home');
      await tester.pumpAndSettle();

      expect(find.text('Rate the lesson before leaving?'), findsOneWidget);
      expect(find.text('Course'), findsOneWidget);

      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(leavingCourse.single.uri.path, '/course/7');
    });

    testWidgets('is not asked when navigation goes deeper, into a child', (
      tester,
    ) async {
      final router = await openAt(tester, '/course/7');

      router.go('/course/7/lesson/3');
      await tester.pumpAndSettle();

      expect(find.text('Lesson'), findsOneWidget);
      expect(leavingCourse, isEmpty);
    });
  });
}
