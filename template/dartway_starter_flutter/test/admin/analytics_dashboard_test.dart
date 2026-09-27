import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_test_app.dart';

/// The analytics dashboards of the admin panel over a fake server: built,
/// changed and read without code.
void main() {
  /// An admin whose server keeps dashboards and answers reports.
  ({FakeApp fake, List<DwAnalyticsDashboard> dashboards}) analyticsAdmin() {
    final fake = FakeApp(role: UserRole.admin, firstName: 'Anna');
    final dashboards = <DwAnalyticsDashboard>[];
    var nextId = 1;
    fake.server
      ..onRequest<GetAdminCounters>(
        (request, call) => const DwCallOk(
          AdminCounters(members: 3, admins: 1, marketingOptIns: 0),
        ),
      )
      ..onRequest<DwListAnalyticsDashboards>(
        (request, call) => DwCallOk(List.of(dashboards)),
      )
      ..onRequest<DwGetAnalyticsCatalog>(
        (request, call) => const DwCallOk(
          DwAnalyticsCatalog(
            events: [
              DwAnalyticsCatalogEvent(
                name: 'homeClicked',
                count: 40,
                propertyKeys: ['block_name'],
              ),
              DwAnalyticsCatalogEvent(
                name: 'quizStepSeen',
                count: 90,
                propertyKeys: ['question_number', 'quiz'],
              ),
            ],
          ),
        ),
      )
      ..onRequest<DwGetAnalyticsReport>(
        (request, call) => DwCallOk(switch (request.spec.breakdown.property) {
          'block_name' => const DwAnalyticsReport(
            total: 40,
            points: [
              DwAnalyticsPoint(label: 'feed', value: 25),
              DwAnalyticsPoint(label: 'banner', value: 10),
            ],
            other: 5,
          ),
          'question_number' => const DwAnalyticsReport(
            total: 30,
            points: [
              DwAnalyticsPoint(label: '1', value: 30),
              DwAnalyticsPoint(label: '2', value: 21),
            ],
          ),
          _ => const DwAnalyticsReport(total: 120),
        }),
      )
      ..onCommand<DwSaveAnalyticsDashboard>((command, call) {
        final saved = DwAnalyticsDashboard(
          id: command.id ?? nextId++,
          title: command.title,
          widgets: command.widgets,
          updatedAt: DateTime.utc(2026, 9, 27),
        );
        dashboards
          ..removeWhere((d) => d.id == saved.id)
          ..add(saved)
          ..sort((a, b) => a.id.compareTo(b.id));
        return DwCallOk(saved);
      })
      ..onCommand<DwDeleteAnalyticsDashboard>((command, call) {
        dashboards.removeWhere((d) => d.id == command.id);
        return const DwCallOk<void>(null);
      });
    return (fake: fake, dashboards: dashboards);
  }

  Future<TestApp> openDashboard(WidgetTester tester, FakeApp fake) async {
    final app = await TestApp.start(tester, fake, size: const Size(390, 900));
    await app.tap(tester, find.text('Profile'));
    await app.tap(tester, find.text('Admin panel'));
    return app;
  }

  /// Picks [option] in the menu showing [current].
  Future<void> choose(
    TestApp app,
    WidgetTester tester,
    String current,
    String option,
  ) async {
    await app.tap(tester, find.text(current).last);
    await app.tap(tester, find.text(option).last);
  }

  testWidgets('a dashboard is created, and "home clicks by block name" is '
      'built as a pie without code', (tester) async {
    final (:fake, :dashboards) = analyticsAdmin();
    final app = await openDashboard(tester, fake);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.textContaining('No dashboards yet'), findsOneWidget);

    await app.tap(tester, find.byTooltip('New dashboard'));
    await app.enter(tester, find.byType(TextField).last, 'Home');
    await app.tap(tester, find.text('Save'));
    expect(dashboards.single.title, 'Home');
    expect(find.text('This dashboard has no widgets yet.'), findsOneWidget);

    await app.tap(tester, find.text('Add widget'));
    await app.tap(tester, find.text('Pie'));
    await app.enter(tester, find.byType(TextField).last, 'Home clicks');
    await choose(app, tester, 'Any event', 'homeClicked (40)');
    await choose(app, tester, 'Nothing', 'Property “block_name”');
    await app.tap(tester, find.text('Save').last);

    expect(
      dashboards.single.widgets.single,
      const DwAnalyticsWidgetSpec(
        type: DwAnalyticsWidgetType.pie,
        title: 'Home clicks',
        report: DwAnalyticsReportSpec(
          eventName: 'homeClicked',
          breakdown: DwAnalyticsBreakdown.byProperty('block_name'),
        ),
      ),
    );
    // The list was read again after each change: the module has no channel.
    expect(app.server.requestsOf<DwListAnalyticsDashboards>(), hasLength(3));
    expect(find.text('Home clicks'), findsOneWidget);
    expect(find.text('feed'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    final report = app.server.requestsOf<DwGetAnalyticsReport>().last;
    expect(report.period.to.difference(report.period.from).inDays, 30);

    await app.stop(tester);
  });

  testWidgets('a quiz funnel — distinct people by question number — and a '
      'number with its change are built, moved and removed', (tester) async {
    final (:fake, :dashboards) = analyticsAdmin();
    dashboards.add(
      DwAnalyticsDashboard(
        id: 7,
        title: 'Onboarding',
        updatedAt: DateTime.utc(2026, 9, 27),
        widgets: const [
          DwAnalyticsWidgetSpec(
            type: DwAnalyticsWidgetType.indicator,
            title: 'Active devices',
            report: DwAnalyticsReportSpec(metric: DwAnalyticsMetric.installs),
            comparePrevious: true,
          ),
        ],
      ),
    );
    final app = await openDashboard(tester, fake);
    expect(find.text('Active devices'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('vs the previous period'), findsOneWidget);
    final periods = {
      for (final r in app.server.requestsOf<DwGetAnalyticsReport>()) r.period,
    };
    expect(periods, hasLength(2), reason: 'this period and the previous one');

    await app.tap(tester, find.byTooltip('Edit dashboard'));
    await app.tap(tester, find.text('Add widget'));
    await app.tap(tester, find.text('Bars'));
    await app.enter(tester, find.byType(TextField).last, 'Quiz funnel');
    await choose(app, tester, 'Any event', 'quizStepSeen (90)');
    await choose(app, tester, 'Events', 'People (signed-in accounts)');
    await choose(app, tester, 'Nothing', 'Property “question_number”');
    await app.tap(tester, find.text('Save').last);

    expect(
      dashboards.single.widgets.last.report,
      const DwAnalyticsReportSpec(
        eventName: 'quizStepSeen',
        metric: DwAnalyticsMetric.accounts,
        breakdown: DwAnalyticsBreakdown.byProperty('question_number'),
      ),
    );
    expect(find.text('Quiz funnel'), findsOneWidget);

    await app.tap(tester, find.byTooltip('Move back').last);
    expect(dashboards.single.widgets.map((w) => w.title), [
      'Quiz funnel',
      'Active devices',
    ]);
    await app.tap(tester, find.byTooltip('Remove widget').last);
    expect(dashboards.single.widgets.map((w) => w.title), ['Quiz funnel']);

    await app.tap(tester, find.text('7 days'));
    expect(
      app.server.requestsOf<DwGetAnalyticsReport>().last.period.to.difference(
        app.server.requestsOf<DwGetAnalyticsReport>().last.period.from,
      ),
      const Duration(days: 7),
    );

    await app.stop(tester);
  });
}
