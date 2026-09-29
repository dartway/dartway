import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_app.dart';

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
    // A pie counts events, split by a property: until one is chosen it
    // cannot be saved, and the count cannot be switched to people.
    expect(find.textContaining('A pie shows events split'), findsOneWidget);
    await app.tap(tester, find.text('Save').last);
    expect(dashboards.single.widgets, isEmpty);
    expect(
      tester
          .widget<DropdownButtonFormField<DwAnalyticsMetric>>(
            find.byType(DropdownButtonFormField<DwAnalyticsMetric>),
          )
          .onChanged,
      isNull,
    );
    await choose(app, tester, 'Nothing', 'Property “block_name”');
    expect(find.textContaining('A pie shows events split'), findsNothing);
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
    // The last 30 days: from midnight 29 days ago up to now, not midnight.
    final report = app.server.requestsOf<DwGetAnalyticsReport>().last;
    final today = DateTime.now();
    expect(
      report.period.from,
      DateTime(today.year, today.month, today.day - 29).toUtc(),
    );
    expect(report.period.to.isAfter(today.toUtc()), isFalse);

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
    // The same shape 30 days earlier: the same partial today, not 30 whole
    // days against 29 and a morning.
    final shown = periods.firstWhere(
      (p) => p.to.isAfter(p.from) && periods.every((q) => !q.to.isAfter(p.to)),
    );
    final previous = periods.firstWhere((p) => p != shown);
    expect(previous, shown.previous);
    expect(previous.to, shown.to.subtract(const Duration(days: 30)));

    await app.tap(tester, find.byTooltip('Edit dashboard'));
    await app.tap(tester, find.text('Add widget'));
    await app.tap(tester, find.text('Bars'));
    await app.enter(tester, find.byType(TextField).last, 'Quiz funnel');
    await choose(app, tester, 'Any event', 'quizStepSeen (90)');
    await choose(app, tester, 'Events', 'People (signed-in accounts)');
    await choose(app, tester, 'Nothing', 'Property “question_number”');
    await choose(app, tester, 'Largest first', 'By value: 1, 2, … 10');
    await app.tap(tester, find.text('Save').last);

    // A funnel: steps in their order, and room for a 15-question quiz.
    expect(
      dashboards.single.widgets.last.report,
      const DwAnalyticsReportSpec(
        eventName: 'quizStepSeen',
        metric: DwAnalyticsMetric.accounts,
        breakdown: DwAnalyticsBreakdown.byProperty(
          'question_number',
          top: DwAnalyticsBreakdown.labelOrderTop,
          order: DwAnalyticsBreakdownOrder.byLabel,
        ),
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
    final today = DateTime.now();
    expect(
      app.server.requestsOf<DwGetAnalyticsReport>().last.period.from,
      DateTime(today.year, today.month, today.day - 6).toUtc(),
    );

    await app.stop(tester);
  });

  testWidgets('two removals tapped in a row do not undo each other: the '
      'second waits for the first', (tester) async {
    final (:fake, :dashboards) = analyticsAdmin();
    DwAnalyticsWidgetSpec number(String title) => DwAnalyticsWidgetSpec(
      type: DwAnalyticsWidgetType.indicator,
      title: title,
      report: const DwAnalyticsReportSpec(),
    );
    dashboards.add(
      DwAnalyticsDashboard(
        id: 7,
        title: 'Numbers',
        updatedAt: DateTime.utc(2026, 9, 27),
        widgets: [number('First'), number('Second'), number('Third')],
      ),
    );
    final app = await openDashboard(tester, fake);
    await app.tap(tester, find.byTooltip('Edit dashboard'));

    final remove = find.byTooltip('Remove widget');
    await tester.ensureVisible(remove.first);
    await tester.tap(remove.first);
    await tester.pump();
    // Before the first save has answered: built from the old list, this tap
    // would send First back.
    await tester.tap(remove.at(1), warnIfMissed: false);
    await app.settle(tester);

    expect(app.server.callsOf<DwSaveAnalyticsDashboard>(), hasLength(1));
    expect(dashboards.single.widgets.map((w) => w.title), ['Second', 'Third']);

    // Once it has, the next removal starts from what was saved.
    await app.tap(tester, find.byTooltip('Remove widget').first);
    expect(dashboards.single.widgets.map((w) => w.title), ['Third']);

    await app.stop(tester);
  });

  testWidgets('switching dashboards while a save is under way keeps each '
      "dashboard's widgets its own", (tester) async {
    final (:fake, :dashboards) = analyticsAdmin();
    DwAnalyticsWidgetSpec number(String title) => DwAnalyticsWidgetSpec(
      type: DwAnalyticsWidgetType.indicator,
      title: title,
      report: const DwAnalyticsReportSpec(),
    );
    dashboards.addAll([
      DwAnalyticsDashboard(
        id: 1,
        title: 'Alpha',
        updatedAt: DateTime.utc(2026, 9, 27),
        widgets: [number('A one'), number('A two')],
      ),
      DwAnalyticsDashboard(
        id: 2,
        title: 'Beta',
        updatedAt: DateTime.utc(2026, 9, 26),
        widgets: [number('B one')],
      ),
    ]);
    // The first save is held until the test releases it; every save stores
    // a new updatedAt, as the server does.
    final held = Completer<void>();
    var saves = 0;
    fake.server.onCommand<DwSaveAnalyticsDashboard>((command, call) async {
      if (saves++ == 0) await held.future;
      final saved = DwAnalyticsDashboard(
        id: command.id!,
        title: command.title,
        widgets: command.widgets,
        updatedAt: DateTime.utc(2026, 9, 28).add(Duration(minutes: saves)),
      );
      dashboards[dashboards.indexWhere((d) => d.id == saved.id)] = saved;
      return DwCallOk(saved);
    });
    final app = await openDashboard(tester, fake);
    await app.tap(tester, find.byTooltip('Edit dashboard'));

    // Alpha loses its first widget; the save has not answered yet.
    await tester.ensureVisible(find.byTooltip('Remove widget').first);
    await tester.tap(find.byTooltip('Remove widget').first);
    await app.settle(tester);
    expect(dashboards.first.widgets.map((w) => w.title), ['A one', 'A two']);

    await app.tap(tester, find.byType(DropdownButton<int>));
    await app.tap(tester, find.text('Beta').last);
    expect(find.text('B one'), findsOneWidget);
    expect(find.text('A two'), findsNothing);

    held.complete();
    await app.settle(tester);
    expect(dashboards.first.widgets.map((w) => w.title), ['A two']);
    expect(find.text('B one'), findsOneWidget, reason: "Beta's own widgets");
    expect(
      find.text('A two'),
      findsNothing,
      reason: "Alpha's answer stays Alpha's",
    );

    // The next change is Beta's, built on Beta's list.
    await app.tap(tester, find.byTooltip('Remove widget').first);
    final last =
        app.server.callsOf<DwSaveAnalyticsDashboard>().last.call!
            as DwSaveAnalyticsDashboard;
    expect(last.id, 2);
    expect(last.widgets, isEmpty);
    expect(dashboards.first.widgets.map((w) => w.title), ['A two']);
    expect(dashboards.last.widgets, isEmpty);

    await app.stop(tester);
  });
}
