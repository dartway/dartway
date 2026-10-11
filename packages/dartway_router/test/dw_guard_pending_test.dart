import 'dart:async';

import 'package:dartway_router/dartway_router.dart';
import 'package:dartway_router/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

typedef SessionState = ({bool? signedIn, bool? surveyDone});
final session = NotifierProvider<SessionStateController, SessionState>(
  SessionStateController.new,
);

class SessionStateController extends Notifier<SessionState> {
  @override
  SessionState build() => (signedIn: false, surveyDone: null);
  void update(SessionState next) => state = next;
}

int homeBuilds = 0;
int detailsBuilds = 0;
int shellBuilds = 0;
int pendingBuilds = 0;
int signInBuilds = 0;

final class RecordingObserver extends NavigatorObserver {
  PageRoute<dynamic>? shellRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute<dynamic> && route.fullscreenDialog) {
      shellRoute = route;
    }
  }
}

class CountedPage extends StatelessWidget {
  const CountedPage(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) {
    if (label == 'Home') homeBuilds++;
    if (label == 'Details') detailsBuilds++;
    if (label == 'Sign in') signInBuilds++;
    return Text(label);
  }
}

enum PendingRoutes implements DwNavigationRoute<SessionState> {
  home(DwNavigationRouteDescriptor.zoneRoot(pageWidget: CountedPage('Home'))),
  details(
    DwNavigationRouteDescriptor.simple(pageWidget: CountedPage('Details')),
  );

  const PendingRoutes(this.descriptor);
  @override
  final DwNavigationRouteDescriptor<SessionState> descriptor;
  @override
  String get zoneRoot => '';
  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => (context, state, child) {
    shellBuilds++;
    return MaterialPage(key: state.pageKey, child: child);
  };
  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;
  @override
  List<DwDecisionGuard<SessionState>> get zoneGuards => [
    (state, _) => switch (state.signedIn) {
      null => DwGuardDecision.pending,
      false => const DwGuardDecision.redirect('/signIn'),
      true => DwGuardDecision.allow,
    },
    (state, _) => switch (state.surveyDone) {
      null => DwGuardDecision.pending,
      false => const DwGuardDecision.redirect('/survey'),
      true => DwGuardDecision.allow,
    },
  ];
}

enum PublicRoutes implements DwNavigationRoute<SessionState> {
  signIn(
    DwNavigationRouteDescriptor.simple(pageWidget: CountedPage('Sign in')),
  ),
  survey(DwNavigationRouteDescriptor.simple(pageWidget: Text('Survey')));

  const PublicRoutes(this.descriptor);
  @override
  final DwNavigationRouteDescriptor<SessionState> descriptor;
  @override
  String get zoneRoot => '';
  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;
  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;
  @override
  List<DwDecisionGuard<SessionState>> get zoneGuards => [
    (state, _) => this != signIn
        ? DwGuardDecision.allow
        : switch (state.signedIn) {
            null => DwGuardDecision.pending,
            true => const DwGuardDecision.redirect('/'),
            false => DwGuardDecision.allow,
          },
  ];
}

Page<dynamic> semanticsPage(Widget child, LocalKey key) =>
    CustomTransitionPage<void>(
      key: key,
      child: child,
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black38,
      barrierLabel: 'Shell barrier',
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 137),
      reverseTransitionDuration: const Duration(milliseconds: 83),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );

enum ShellSemanticsRoutes implements DwNavigationRoute<SessionState> {
  shellSemantics(
    DwNavigationRouteDescriptor.zoneRoot(pageWidget: CountedPage('Home')),
  );

  const ShellSemanticsRoutes(this.descriptor);
  @override
  final DwNavigationRouteDescriptor<SessionState> descriptor;
  @override
  String get zoneRoot => '';
  @override
  DwShellRoutePageBuilder? get shellRouteBuilder =>
      (_, state, child) => semanticsPage(child, state.pageKey);
  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;
  @override
  List<DwDecisionGuard<SessionState>> get zoneGuards => [
    (_, _) => DwGuardDecision.allow,
  ];
}

enum StatefulShellSemanticsRoutes implements DwNavigationRoute<SessionState> {
  statefulShellSemantics(
    DwNavigationRouteDescriptor.zoneRoot(pageWidget: CountedPage('Home')),
  );

  const StatefulShellSemanticsRoutes(this.descriptor);
  @override
  final DwNavigationRouteDescriptor<SessionState> descriptor;
  @override
  String get zoneRoot => '';
  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;
  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder =>
      (_, state, shell) => semanticsPage(shell, state.pageKey);
  @override
  List<DwDecisionGuard<SessionState>> get zoneGuards => [
    (_, _) => DwGuardDecision.allow,
  ];
}

Widget pendingPage(BuildContext context, GoRouterState state) {
  pendingBuilds++;
  return const Text('Pending');
}

void main() {
  setUp(() {
    homeBuilds = 0;
    detailsBuilds = 0;
    shellBuilds = 0;
    pendingBuilds = 0;
    signInBuilds = 0;
  });

  Future<DwAppRouter<SessionState>> mount(
    WidgetTester tester,
    ProviderContainer container, {
    String location = '/',
    Widget Function(BuildContext, GoRouterState)? pendingBuilder = pendingPage,
  }) async {
    final app = buildRouter(
      (ref) => DwAppRouter<SessionState>(
        ref: ref,
        routerState: session,
        navigationZones: [PendingRoutes.values, PublicRoutes.values],
        pageBuilder: DwPageBuilder.material,
        options: DwGoRouterOptions(
          initialLocation: location,
          pendingBuilder: pendingBuilder,
        ),
      ),
      container: container,
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: app.router));
    await tester.pumpAndSettle();
    return app;
  }

  ProviderContainer scope(SessionState initial) {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(session.notifier).update(initial);
    return container;
  }

  testWidgets(
    'sign-in waits for profile, then survey without a home frame (#556)',
    (tester) async {
      final container = scope((signedIn: false, surveyDone: null));
      final app = await mount(tester, container);
      expect(find.text('Sign in'), findsOneWidget);
      container.read(session.notifier).update((
        signedIn: true,
        surveyDone: null,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Pending'), findsOneWidget);
      expect(app.router.routeInformationProvider.value.uri.toString(), '/');
      expect(app.router.canPop(), isFalse);
      expect(homeBuilds, 0);
      container.read(session.notifier).update((
        signedIn: true,
        surveyDone: false,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Survey'), findsOneWidget);
      expect(homeBuilds, 0);
    },
  );

  testWidgets('a completed survey opens home directly', (tester) async {
    final container = scope((signedIn: true, surveyDone: true));
    await mount(tester, container);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Pending'), findsNothing);
    expect(pendingBuilds, 0);
    expect(homeBuilds, greaterThan(0));
  });

  testWidgets('session restoration keeps a deep link pending, then opens it', (
    tester,
  ) async {
    final container = scope((signedIn: null, surveyDone: null));
    final app = await mount(tester, container, location: '/details?tab=notes');
    expect(find.text('Pending'), findsOneWidget);
    expect(
      app.router.routeInformationProvider.value.uri.toString(),
      '/details?tab=notes',
    );
    expect(detailsBuilds, 0);
    expect(homeBuilds, 0);
    container.read(session.notifier).update((signedIn: true, surveyDone: true));
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget);
    expect(homeBuilds, 0);
    expect(
      app.router.routeInformationProvider.value.uri.toString(),
      '/details?tab=notes',
    );
    expect(app.router.canPop(), isFalse);
  });

  testWidgets('an allowed page is removed when its facts become unknown', (
    tester,
  ) async {
    final container = scope((signedIn: true, surveyDone: true));
    await mount(tester, container);
    final builds = homeBuilds;
    container.read(session.notifier).update((signedIn: true, surveyDone: null));
    await tester.pumpAndSettle();
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(homeBuilds, builds);
    container.read(session.notifier).update((
      signedIn: true,
      surveyDone: false,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Survey'), findsOneWidget);
    expect(homeBuilds, builds);
  });

  testWidgets('system Back pops normally while a shell target is pending', (
    tester,
  ) async {
    final container = scope((signedIn: true, surveyDone: true));
    final app = await mount(tester, container);
    container.read(session.notifier).update((signedIn: true, surveyDone: null));
    unawaited(app.router.push('/details'));
    await tester.pumpAndSettle();
    expect(detailsBuilds, 0);

    await expectLater(tester.binding.handlePopRoute(), completes);
    await tester.pumpAndSettle();
    expect(detailsBuilds, 0);
    expect(app.router.routeInformationProvider.value.uri.toString(), '/');
  });

  testWidgets('system Back pops normally while a plain target is pending', (
    tester,
  ) async {
    final container = scope((signedIn: null, surveyDone: true));
    final app = await mount(tester, container, location: '/survey');
    unawaited(app.router.push('/signIn'));
    await tester.pumpAndSettle();
    expect(signInBuilds, 0);

    await expectLater(tester.binding.handlePopRoute(), completes);
    await tester.pumpAndSettle();
    expect(signInBuilds, 0);
    expect(app.router.routeInformationProvider.value.uri.toString(), '/survey');
  });

  testWidgets('system Back still pops after a pending decision lands', (
    tester,
  ) async {
    final container = scope((signedIn: true, surveyDone: null));
    final app = await mount(tester, container);
    unawaited(app.router.push('/details'));
    await tester.pumpAndSettle();
    expect(detailsBuilds, 0);

    container.read(session.notifier).update((signedIn: true, surveyDone: true));
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget);
    await expectLater(tester.binding.handlePopRoute(), completes);
    await tester.pumpAndSettle();
    expect(app.router.routeInformationProvider.value.uri.toString(), '/');
  });

  testWidgets('pending without a builder fails without building the target', (
    tester,
  ) async {
    final container = scope((signedIn: true, surveyDone: null));
    await mount(tester, container, pendingBuilder: null);
    expect(find.textContaining('pendingBuilder is required'), findsOneWidget);
    expect(homeBuilds, 0);
  });

  for (final zone in <List<DwNavigationRoute<SessionState>>>[
    ShellSemanticsRoutes.values,
    StatefulShellSemanticsRoutes.values,
  ]) {
    testWidgets('${zone.first.name} preserves its shell Page semantics', (
      tester,
    ) async {
      final container = scope((signedIn: true, surveyDone: true));
      final observer = RecordingObserver();
      final app = buildRouter(
        (ref) => DwAppRouter<SessionState>(
          ref: ref,
          routerState: session,
          navigationZones: [zone],
          pageBuilder: DwPageBuilder.material,
          options: DwGoRouterOptions(
            pendingBuilder: pendingPage,
            observers: [observer],
          ),
        ),
        container: container,
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: app.router));
      await tester.pumpAndSettle();

      final route = observer.shellRoute!;
      expect(route.fullscreenDialog, isTrue);
      expect(route.opaque, isFalse);
      expect(route.barrierDismissible, isTrue);
      expect(route.barrierColor, Colors.black38);
      expect(route.barrierLabel, 'Shell barrier');
      expect(route.transitionDuration, const Duration(milliseconds: 137));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 83),
      );
      expect(find.byType(FadeTransition), findsWidgets);
      expect(find.text('Home'), findsOneWidget);
    });
  }

  test(
    'unknown-field helper checks all zones and catches a null-through guard',
    () {
      const known = (signedIn: true, surveyDone: false);
      final fields = <String, SessionState Function(SessionState)>{
        'signedIn': (s) => (signedIn: null, surveyDone: s.surveyDone),
        'surveyDone': (s) => (signedIn: s.signedIn, surveyDone: null),
      };
      dwCheckPendingGuards<SessionState>(
        navigationZones: [PendingRoutes.values, PublicRoutes.values],
        knownStates: [known, (signedIn: false, surveyDone: true)],
        nullableFields: fields,
      );
      expect(
        () => dwCheckPendingGuards<SessionState>(
          navigationZones: [LegacyNullThroughRoutes.values],
          knownStates: [known],
          nullableFields: fields,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'diagnostic',
            contains('surveyDone'),
          ),
        ),
      );
    },
  );
}

enum LegacyNullThroughRoutes implements DwNavigationRoute<SessionState> {
  legacy(DwNavigationRouteDescriptor.zoneRoot(pageWidget: Text('Legacy')));

  const LegacyNullThroughRoutes(this.descriptor);
  @override
  final DwNavigationRouteDescriptor<SessionState> descriptor;
  @override
  String get zoneRoot => 'legacy';
  @override
  DwShellRoutePageBuilder? get shellRouteBuilder => null;
  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;
  @override
  List<DwDecisionGuard<SessionState>> get zoneGuards => [
    (state, _) => state.surveyDone == false
        ? const DwGuardDecision.redirect('/survey')
        : DwGuardDecision.allow,
  ];
}
