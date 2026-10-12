import 'dart:async';

import 'package:dartway_router/dartway_router.dart';
import 'package:dartway_router/testing.dart';
import 'package:flutter/cupertino.dart';
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
final guardedTargets = <DwNavigationTarget>[];

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
    (state, target) {
      guardedTargets.add(target);
      return switch (state.signedIn) {
        null => DwGuardDecision.pending,
        false => const DwGuardDecision.redirect('/signIn'),
        true => DwGuardDecision.allow,
      };
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

bool useCupertinoShell = false;

Widget shellChrome(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Column(
    children: [
      const Text('Shell chrome'),
      Expanded(child: child),
    ],
  ),
);

Page<dynamic> shellPage(Widget child, LocalKey key) => useCupertinoShell
    ? CupertinoPage<void>(key: key, child: shellChrome(child))
    : MaterialPage<void>(key: key, child: shellChrome(child));

enum ShellSemanticsRoutes implements DwNavigationRoute<SessionState> {
  shellSemantics(
    DwNavigationRouteDescriptor.zoneRoot(pageWidget: CountedPage('Home')),
  ),
  shellDetails(
    DwNavigationRouteDescriptor.simple(pageWidget: CountedPage('Details')),
  );

  const ShellSemanticsRoutes(this.descriptor);
  @override
  final DwNavigationRouteDescriptor<SessionState> descriptor;
  @override
  String get zoneRoot => '';
  @override
  DwShellRoutePageBuilder? get shellRouteBuilder =>
      (_, state, child) => shellPage(child, state.pageKey);
  @override
  DwStatefulShellRouteBuilder? get statefulShellRouteBuilder => null;
  @override
  List<DwDecisionGuard<SessionState>> get zoneGuards => [
    (state, _) => state.signedIn == null
        ? DwGuardDecision.pending
        : DwGuardDecision.allow,
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
      (_, state, shell) => shellPage(shell, state.pageKey);
  @override
  List<DwDecisionGuard<SessionState>> get zoneGuards => [
    (state, _) => state.signedIn == null
        ? DwGuardDecision.pending
        : DwGuardDecision.allow,
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
    guardedTargets.clear();
    useCupertinoShell = false;
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

  testWidgets('a MaterialPage shell keeps its installed route', (tester) async {
    final container = scope((signedIn: true, surveyDone: true));
    final app = await mount(tester, container);
    expect(find.text('Home'), findsOneWidget);

    app.router.go('/details');
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('a completed survey opens home directly', (tester) async {
    final container = scope((signedIn: true, surveyDone: true));
    await mount(tester, container);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Pending'), findsNothing);
    expect(pendingBuilds, 0);
    expect(homeBuilds, greaterThan(0));
  });

  testWidgets('a retained pending home stays guarded after a public push', (
    tester,
  ) async {
    final container = scope((signedIn: true, surveyDone: null));
    final app = await mount(tester, container, location: '/?tab=notes');
    expect(find.text('Pending'), findsOneWidget);
    expect(homeBuilds, 0);

    guardedTargets.clear();
    unawaited(app.router.push('/survey?tab=public'));
    await tester.pumpAndSettle();
    expect(find.text('Survey'), findsOneWidget);
    expect(app.router.canPop(), isTrue);
    expect(homeBuilds, 0);
    expect(guardedTargets, isNotEmpty);
    for (final target in guardedTargets) {
      expect(target.routeName, 'home');
      expect(target.location, '/?tab=notes');
    }

    app.router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Pending'), findsOneWidget);
    expect(homeBuilds, 0);
  });

  testWidgets('a pushed pending destination executes its resolved redirect', (
    tester,
  ) async {
    final container = scope((signedIn: true, surveyDone: null));
    final app = await mount(tester, container, location: '/survey');
    expect(find.text('Survey'), findsOneWidget);

    unawaited(app.router.push('/details?tab=notes'));
    await tester.pumpAndSettle();
    expect(find.text('Pending'), findsOneWidget);
    expect(detailsBuilds, 0);
    expect(app.router.canPop(), isTrue);

    container.read(session.notifier).update((
      signedIn: false,
      surveyDone: null,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Pending'), findsNothing);
    expect(app.router.state.uri.toString(), '/signIn');
    expect(detailsBuilds, 0);
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
    for (final cupertino in [false, true]) {
      testWidgets(
        '${zone.first.name} keeps ${cupertino ? 'Cupertino' : 'Material'} '
        'shell chrome around allowed and pending targets',
        (tester) async {
          useCupertinoShell = cupertino;
          final container = scope((signedIn: true, surveyDone: true));
          final app = buildRouter(
            (ref) => DwAppRouter<SessionState>(
              ref: ref,
              routerState: session,
              navigationZones: [zone],
              pageBuilder: DwPageBuilder.material,
              options: const DwGoRouterOptions(pendingBuilder: pendingPage),
            ),
            container: container,
          );
          await tester.pumpWidget(MaterialApp.router(routerConfig: app.router));
          await tester.pumpAndSettle();

          expect(find.text('Shell chrome'), findsOneWidget);
          expect(find.text('Home'), findsOneWidget);
          expect(find.text('Pending'), findsNothing);

          container.read(session.notifier).update((
            signedIn: null,
            surveyDone: true,
          ));
          await tester.pumpAndSettle();
          expect(find.text('Shell chrome'), findsOneWidget);
          expect(find.text('Pending'), findsOneWidget);
          expect(find.text('Home'), findsNothing);
        },
      );
    }
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
