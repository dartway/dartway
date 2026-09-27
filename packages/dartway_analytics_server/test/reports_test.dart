import 'package:dartway_analytics_server/dartway_analytics_server.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/analytics_harness.dart';

int _names = 0;

/// An event name no other test records.
String uniqueName(String base) => '$base${++_names}';

void main() {
  group('with the project rule', () {
    final harness = useAnalyticsHarness();

    /// Sends [events] from a fresh install, signed in as [as].
    Future<void> record(
      List<(String, DateTime, Map<String, Object?>)> events, {
      TestAccount? as,
      String? install,
    }) async {
      final answer = await harness().send(
        batch(install ?? newInstallId(), [
          for (final (index, (name, at, properties)) in events.indexed)
            event(name, index + 1, at, properties),
        ]),
        as: as,
      );
      expect(answer.status, 200, reason: answer.text);
    }

    Future<DwAnalyticsReport> report(
      DwAnalyticsReportSpec spec,
      DwAnalyticsPeriod period, {
      required TestAccount as,
    }) async {
      final call = DwGetAnalyticsReport(spec: spec, period: period);
      final answer = await harness().send(call, as: as);
      expect(answer.status, 200, reason: answer.text);
      return answer.value(call);
    }

    final september = DwAnalyticsPeriod(
      from: DateTime.utc(2026, 9),
      to: DateTime.utc(2026, 10),
    );
    final at = DateTime.utc(2026, 9, 10, 12);

    test('a quiz funnel: distinct accounts by question number, the top '
        'values and the rest, filtered by property', () async {
      final seen = uniqueName('quizStepSeen');
      final reader = await harness().reader();
      final a = await harness().account();
      final b = await harness().account();
      final c = await harness().account();
      (String, DateTime, Map<String, Object?>) step(
        int question, [
        String quiz = 'onboarding',
      ]) => (seen, at, {'quiz': quiz, 'question_number': question});

      await record([step(1), step(1), step(2), step(3)], as: a);
      await record([step(1), step(2)], as: b);
      await record([step(1), step(2, 'other')], as: c);
      // Signed out: an install, no account.
      await record([step(1)]);

      final spec = DwAnalyticsReportSpec(
        eventName: seen,
        metric: DwAnalyticsMetric.accounts,
        filters: const [
          DwAnalyticsFilter(property: 'quiz', value: 'onboarding'),
        ],
        breakdown: const DwAnalyticsBreakdown.byProperty(
          'question_number',
          top: 2,
        ),
      );
      final accounts = await report(spec, september, as: reader);
      expect(accounts.points, const [
        DwAnalyticsPoint(label: '1', value: 3),
        DwAnalyticsPoint(label: '2', value: 2),
      ]);
      expect(accounts.other, 1, reason: 'question 3, by account a');
      expect(accounts.total, 3);

      final installs = await report(
        DwAnalyticsReportSpec(
          eventName: seen,
          metric: DwAnalyticsMetric.installs,
          breakdown: const DwAnalyticsBreakdown.byProperty('question_number'),
        ),
        september,
        as: reader,
      );
      expect(installs.points, const [
        DwAnalyticsPoint(label: '1', value: 4),
        DwAnalyticsPoint(label: '2', value: 3),
        DwAnalyticsPoint(label: '3', value: 1),
      ]);
      expect(installs.other, isNull, reason: 'every value has a point');
      expect(installs.total, 4);

      final events = await report(
        DwAnalyticsReportSpec(
          eventName: seen,
          filters: const [
            DwAnalyticsFilter(property: 'question_number', value: '1'),
          ],
        ),
        september,
        as: reader,
      );
      expect(events.total, 5, reason: 'the number 1 matches the text "1"');
      expect(events.points, isEmpty);
    });

    test('home clicks by block name, events without the property apart, '
        'ties by label', () async {
      final clicked = uniqueName('homeClicked');
      final reader = await harness().reader();
      await record([
        (clicked, at, {'block_name': 'news'}),
        (clicked, at, {'block_name': 'banner'}),
        (clicked, at, {'block_name': 'news'}),
        (clicked, at, {'block_name': 'schedule'}),
        (clicked, at, {'block_name': 'banner'}),
        (clicked, at, const {}),
        (clicked, at, {'block_name': "o'brien; --"}),
      ]);
      final clicks = await report(
        DwAnalyticsReportSpec(
          eventName: clicked,
          breakdown: const DwAnalyticsBreakdown.byProperty(
            'block_name',
            top: 3,
          ),
        ),
        september,
        as: reader,
      );
      expect(clicks.points, const [
        DwAnalyticsPoint(label: 'banner', value: 2),
        DwAnalyticsPoint(label: 'news', value: 2),
        DwAnalyticsPoint(label: "o'brien; --", value: 1),
      ]);
      expect(clicks.other, 2, reason: 'schedule, and the click without one');
      expect(clicks.total, 7);
    });

    test('day buckets are the viewer\'s days: an event just before the '
        'period, at its last moment and at its end', () async {
      final opened = uniqueName('screenOpened');
      final reader = await harness().reader();
      final member = await harness().account();
      // Moscow, UTC+3: the period is 1–7 September on its calendar.
      final week = DwAnalyticsPeriod(
        from: DateTime.utc(2026, 8, 31, 21),
        to: DateTime.utc(2026, 9, 7, 21),
        utcOffsetMinutes: 180,
      );
      await record([
        // 31 August, 23:30 in Moscow: before the period.
        (opened, DateTime.utc(2026, 8, 31, 20, 30), const {}),
        // 1 September, 00:30 in Moscow — still 31 August in UTC.
        (opened, DateTime.utc(2026, 8, 31, 21, 30), const {}),
        (opened, DateTime.utc(2026, 9, 3, 9), const {}),
        (opened, DateTime.utc(2026, 9, 3, 10), const {}),
        // 7 September, 23:59 in Moscow: the last moment in.
        (opened, DateTime.utc(2026, 9, 7, 20, 59), const {}),
        // 8 September, 00:00 in Moscow: the end, not in.
        (opened, DateTime.utc(2026, 9, 7, 21), const {}),
      ], as: member);

      final byDay = await report(
        DwAnalyticsReportSpec(
          eventName: opened,
          breakdown: const DwAnalyticsBreakdown.byTime(
            DwAnalyticsTimeBucket.day,
          ),
        ),
        week,
        as: reader,
      );
      expect(byDay.points, const [
        DwAnalyticsPoint(label: '2026-09-01', value: 1),
        DwAnalyticsPoint(label: '2026-09-02', value: 0),
        DwAnalyticsPoint(label: '2026-09-03', value: 2),
        DwAnalyticsPoint(label: '2026-09-04', value: 0),
        DwAnalyticsPoint(label: '2026-09-05', value: 0),
        DwAnalyticsPoint(label: '2026-09-06', value: 0),
        DwAnalyticsPoint(label: '2026-09-07', value: 1),
      ]);
      expect(byDay.total, 4);

      // A distinct count: one account on three days is one in the total.
      final people = await report(
        DwAnalyticsReportSpec(
          eventName: opened,
          metric: DwAnalyticsMetric.accounts,
          breakdown: const DwAnalyticsBreakdown.byTime(
            DwAnalyticsTimeBucket.day,
          ),
        ),
        week,
        as: reader,
      );
      expect(people.points.map((p) => p.value), [1, 0, 1, 0, 0, 0, 1]);
      expect(people.total, 1);

      // 1 September 2026 is a Tuesday: the first week bucket starts on the
      // Monday before the period, and the last on the period's last day.
      final byWeek = await report(
        DwAnalyticsReportSpec(
          eventName: opened,
          breakdown: const DwAnalyticsBreakdown.byTime(
            DwAnalyticsTimeBucket.week,
          ),
        ),
        week,
        as: reader,
      );
      expect(byWeek.points, const [
        DwAnalyticsPoint(label: '2026-08-31', value: 3),
        DwAnalyticsPoint(label: '2026-09-07', value: 1),
      ]);

      // Across a month boundary, in UTC.
      final byMonth = await report(
        DwAnalyticsReportSpec(
          eventName: opened,
          breakdown: const DwAnalyticsBreakdown.byTime(
            DwAnalyticsTimeBucket.month,
          ),
        ),
        DwAnalyticsPeriod(
          from: DateTime.utc(2026, 8, 25),
          to: DateTime.utc(2026, 9, 10),
        ),
        as: reader,
      );
      expect(byMonth.points, const [
        DwAnalyticsPoint(label: '2026-08-01', value: 2),
        DwAnalyticsPoint(label: '2026-09-01', value: 4),
      ]);
      expect(byMonth.total, 6);
    });

    test('active installs count every event, the server\'s included for '
        'events and never for installs', () async {
      final reader = await harness().reader();
      final install = newInstallId();
      final quiet = DwAnalyticsPeriod(
        from: DateTime.utc(2031, 1, 1),
        to: DateTime.utc(2031, 1, 2),
      );
      await record([
        (uniqueName('a'), DateTime.utc(2031, 1, 1, 1), const {}),
        (uniqueName('b'), DateTime.utc(2031, 1, 1, 2), const {}),
      ], install: install);
      await harness().db.execute(
        "INSERT INTO dw_analytics_event (name, source, occurred_at) "
        "VALUES ('paid', 'server', '2031-01-01T03:00:00Z')",
      );
      final installs = await report(
        const DwAnalyticsReportSpec(metric: DwAnalyticsMetric.installs),
        quiet,
        as: reader,
      );
      expect(installs, const DwAnalyticsReport(total: 1));
      final events = await report(
        const DwAnalyticsReportSpec(),
        quiet,
        as: reader,
      );
      expect(events.total, 3);
    });

    test(
      'the catalog lists the names and keys recorded in the period',
      () async {
        final reader = await harness().reader();
        final period = DwAnalyticsPeriod(
          from: DateTime.utc(2030, 5, 1),
          to: DateTime.utc(2030, 5, 2),
        );
        await record([
          ('quizStepSeen', DateTime.utc(2030, 5, 1, 9), {'question_number': 1}),
          ('quizStepSeen', DateTime.utc(2030, 5, 1, 9), {'quiz': 'x'}),
          ('homeClicked', DateTime.utc(2030, 5, 1, 10), const {}),
          ('lateEvent', DateTime.utc(2030, 5, 2), {'late': true}),
        ]);
        final call = DwGetAnalyticsCatalog(period: period);
        final answer = await harness().send(call, as: reader);
        expect(answer.status, 200, reason: answer.text);
        expect(answer.value(call).events, const [
          DwAnalyticsCatalogEvent(name: 'homeClicked', count: 1),
          DwAnalyticsCatalogEvent(
            name: 'quizStepSeen',
            count: 2,
            propertyKeys: ['question_number', 'quiz'],
          ),
        ]);
      },
    );

    test(
      'a report the store cannot answer is refused before it runs',
      () async {
        final reader = await harness().reader();
        final answer = await harness().send(
          DwGetAnalyticsReport(
            spec: const DwAnalyticsReportSpec(
              breakdown: DwAnalyticsBreakdown.byProperty('no such key!'),
            ),
            period: september,
          ),
          as: reader,
        );
        expect(answer.status, 422, reason: answer.text);
        expect(answer.refusal.isCode(DwAnalyticsRefusal.reportInvalid), isTrue);
        expect(answer.refusal.field, 'spec');
      },
    );

    test(
      'dashboards are created, listed in order, replaced and deleted',
      () async {
        final reader = await harness().reader();
        const clicks = DwAnalyticsWidgetSpec(
          type: DwAnalyticsWidgetType.pie,
          title: 'Home clicks',
          report: DwAnalyticsReportSpec(
            eventName: 'homeClicked',
            breakdown: DwAnalyticsBreakdown.byProperty('block_name'),
          ),
        );
        const active = DwAnalyticsWidgetSpec(
          type: DwAnalyticsWidgetType.indicator,
          title: 'Active installs',
          report: DwAnalyticsReportSpec(metric: DwAnalyticsMetric.installs),
          comparePrevious: true,
        );

        Future<DwAnalyticsDashboard> save(
          DwSaveAnalyticsDashboard command,
        ) async {
          final answer = await harness().send(command, as: reader);
          expect(answer.status, 200, reason: answer.text);
          return answer.value(command);
        }

        Future<List<DwAnalyticsDashboard>> list() async {
          const call = DwListAnalyticsDashboards();
          final answer = await harness().send(call, as: reader);
          expect(answer.status, 200, reason: answer.text);
          return answer.value(call);
        }

        final before = (await list()).length;
        final home = await save(
          const DwSaveAnalyticsDashboard(title: ' Home ', widgets: [clicks]),
        );
        expect(home.title, 'Home');
        expect(home.widgets, [clicks]);
        final growth = await save(
          const DwSaveAnalyticsDashboard(title: 'Growth'),
        );
        expect((await list()).skip(before).map((d) => d.title), [
          'Home',
          'Growth',
        ]);

        // Reordered, one added: the widgets are stored in the order sent.
        final edited = await save(
          DwSaveAnalyticsDashboard(
            id: home.id,
            title: 'Home screen',
            widgets: const [active, clicks],
          ),
        );
        expect(edited.id, home.id);
        expect(edited.widgets, [active, clicks]);
        expect(edited.updatedAt.isAfter(home.updatedAt), isTrue);
        expect((await list()).firstWhere((d) => d.id == home.id), edited);

        final deleted = await harness().send(
          DwDeleteAnalyticsDashboard(id: growth.id),
          as: reader,
        );
        expect(deleted.status, 200, reason: deleted.text);
        expect((await list()).map((d) => d.id), isNot(contains(growth.id)));

        for (final missing in <DwServerCall<Object?>>[
          DwDeleteAnalyticsDashboard(id: growth.id),
          DwSaveAnalyticsDashboard(id: growth.id, title: 'Gone'),
        ]) {
          final answer = await harness().send(missing, as: reader);
          expect(answer.status, 404, reason: '$missing: ${answer.text}');
        }
        final invalid = await harness().send(
          const DwSaveAnalyticsDashboard(title: ''),
          as: reader,
        );
        expect(
          invalid.refusal.isCode(DwAnalyticsRefusal.dashboardInvalid),
          isTrue,
        );
      },
    );

    test(
      'an account the rule does not allow is refused dw.forbidden on every '
      'analytics read and change; a signed-out caller is asked to sign in',
      () async {
        final member = await harness().account();
        final period = DwAnalyticsPeriod(
          from: DateTime.utc(2026, 9),
          to: DateTime.utc(2026, 10),
        );
        final calls = <DwServerCall<Object?>>[
          DwGetAnalyticsReport(
            spec: const DwAnalyticsReportSpec(),
            period: period,
          ),
          DwGetAnalyticsCatalog(period: period),
          const DwListAnalyticsDashboards(),
          const DwSaveAnalyticsDashboard(title: 'Mine'),
          const DwDeleteAnalyticsDashboard(id: 1),
        ];
        for (final call in calls) {
          final answer = await harness().send(call, as: member);
          expect(answer.status, 403, reason: '$call: ${answer.text}');
          expect(answer.refusal.isCode(DwCoreRefusal.forbidden), isTrue);
          final signedOut = await harness().send(call);
          expect(signedOut.status, 401, reason: '$call: ${signedOut.text}');
        }
      },
    );
  });

  group('without readAccess', () {
    final harness = useAnalyticsHarness(withReaders: false);

    test('every read is refused dw.forbidden, whoever asks', () async {
      final member = await harness().account();
      final period = DwAnalyticsPeriod(
        from: DateTime.utc(2026, 9),
        to: DateTime.utc(2026, 10),
      );
      for (final call in <DwServerCall<Object?>>[
        DwGetAnalyticsReport(
          spec: const DwAnalyticsReportSpec(),
          period: period,
        ),
        DwGetAnalyticsCatalog(period: period),
        const DwListAnalyticsDashboards(),
        const DwSaveAnalyticsDashboard(title: 'Mine'),
      ]) {
        final answer = await harness().send(call, as: member);
        expect(answer.status, 403, reason: '$call: ${answer.text}');
        expect(answer.refusal.isCode(DwCoreRefusal.forbidden), isTrue);
      }
    });
  });

  test('analytics open to everyone refuses to start', () {
    final protocol = DwWireProtocol(
      dwAnalyticsProtocolEntries,
      include: DwWireProtocol.core,
    );
    expect(
      DwAnalyticsModule(readAccess: DwAccessRule.signedIn).problems(protocol),
      isEmpty,
    );
    expect(
      DwAnalyticsModule(readAccess: DwAccessRule.anonymous).problems(protocol),
      [contains('readAccess'), contains('editAccess')],
    );
    expect(
      DwAnalyticsModule(
        readAccess: DwAccessRule.signedIn,
        editAccess: DwAccessRule.anonymous,
      ).problems(protocol),
      [contains('editAccess')],
    );
  });
}
