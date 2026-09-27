import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/example_test_app.dart';

/// Scrolls [finder] into view and taps it: the dashboards sit under the
/// counters, below the fold of a phone.
Future<void> tapShown(
  ExampleTestApp app,
  WidgetTester tester,
  Finder finder,
) async {
  await tester.ensureVisible(finder);
  await app.tap(tester, finder);
}

/// The analytics dashboards of the admin panel over a fake server: built,
/// changed and read without code.
void main() {
  /// An admin whose server keeps dashboards and answers reports.
  ({FakeClub fake, List<DwAnalyticsDashboard> dashboards}) analyticsAdmin() {
    final fake = FakeClub(role: UserRole.admin, firstName: 'Anna');
    final dashboards = <DwAnalyticsDashboard>[];
    var nextId = 1;
    fake.server
      ..onRequest<GetAdminCounters>(
        (request, call) => const DwCallOk(
          AdminCounters(members: 3, upcomingSessions: 0, newsPosts: 0),
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
              DwAnalyticsPoint(label: 'news', value: 25),
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

  Future<ExampleTestApp> openDashboard(
    WidgetTester tester,
    FakeClub fake,
  ) async {
    final app = await ExampleTestApp.start(
      tester,
      fake,
      size: const Size(390, 900),
    );
    await tapShown(app, tester, find.text('Profile'));
    await tapShown(app, tester, find.text('Admin panel'));
    return app;
  }

  /// Picks [option] in the menu showing [current].
  Future<void> choose(
    ExampleTestApp app,
    WidgetTester tester,
    String current,
    String option,
  ) async {
    await tapShown(app, tester, find.text(current).last);
    await tapShown(app, tester, find.text(option).last);
  }

  testWidgets('a dashboard is created, and "home clicks by block name" is '
      'built as a pie without code', (tester) async {
    final (:fake, :dashboards) = analyticsAdmin();
    final app = await openDashboard(tester, fake);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.textContaining('No dashboards yet'), findsOneWidget);

    await tapShown(app, tester, find.byTooltip('New dashboard'));
    await tester.enterText(find.byType(TextField).last, 'Home');
    await app.settle(tester);
    await tapShown(app, tester, find.text('Save'));
    expect(dashboards.single.title, 'Home');
    expect(find.text('This dashboard has no widgets yet.'), findsOneWidget);

    await tapShown(app, tester, find.text('Add widget'));
    await tapShown(app, tester, find.text('Pie'));
    await tester.enterText(find.byType(TextField).last, 'Home clicks');
    await app.settle(tester);
    await choose(app, tester, 'Any event', 'homeClicked (40)');
    await choose(app, tester, 'Nothing', 'Property “block_name”');
    await tapShown(app, tester, find.text('Save').last);

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
    expect(find.text('news'), findsOneWidget);
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

    await tapShown(app, tester, find.byTooltip('Edit dashboard'));
    await tapShown(app, tester, find.text('Add widget'));
    await tapShown(app, tester, find.text('Bars'));
    await tester.enterText(find.byType(TextField).last, 'Quiz funnel');
    await app.settle(tester);
    await choose(app, tester, 'Any event', 'quizStepSeen (90)');
    await choose(app, tester, 'Events', 'People (signed-in accounts)');
    await choose(app, tester, 'Nothing', 'Property “question_number”');
    await tapShown(app, tester, find.text('Save').last);

    expect(
      dashboards.single.widgets.last.report,
      const DwAnalyticsReportSpec(
        eventName: 'quizStepSeen',
        metric: DwAnalyticsMetric.accounts,
        breakdown: DwAnalyticsBreakdown.byProperty('question_number'),
      ),
    );
    expect(find.text('Quiz funnel'), findsOneWidget);

    await tapShown(app, tester, find.byTooltip('Move back').last);
    expect(dashboards.single.widgets.map((w) => w.title), [
      'Quiz funnel',
      'Active devices',
    ]);
    await tapShown(app, tester, find.byTooltip('Remove widget').last);
    expect(dashboards.single.widgets.map((w) => w.title), ['Quiz funnel']);

    await tapShown(app, tester, find.text('7 days'));
    expect(
      app.server.requestsOf<DwGetAnalyticsReport>().last.period.to.difference(
        app.server.requestsOf<DwGetAnalyticsReport>().last.period.from,
      ),
      const Duration(days: 7),
    );

    await app.stop(tester);
  });
}
