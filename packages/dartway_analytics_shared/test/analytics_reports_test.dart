import 'dart:convert';

import 'package:dartway_analytics_shared/dartway_analytics_shared.dart';
import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:test/test.dart';

/// Through JSON text and back, as the wire carries it.
Map<String, Object?> _wire(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  final period = DwAnalyticsPeriod(
    from: DateTime.utc(2026, 9, 1),
    to: DateTime.utc(2026, 9, 8),
    utcOffsetMinutes: 180,
  );
  const quizFunnel = DwAnalyticsReportSpec(
    eventName: 'quizStepSeen',
    metric: DwAnalyticsMetric.accounts,
    filters: [DwAnalyticsFilter(property: 'quiz', value: 'onboarding')],
    breakdown: DwAnalyticsBreakdown.byProperty('question_number', top: 10),
  );

  List<String?> fields(DwSelfValidating call) => [
    for (final refusal in call.validate()) refusal.field,
  ];

  test(
    'every analytics call travels through JSON text and comes back equal',
    () {
      final protocol = DwWireProtocol(
        dwAnalyticsProtocolEntries,
        include: DwWireProtocol.core,
      );
      final updatedAt = DateTime.utc(2026, 9, 27, 12);
      final objects = <DwWireObject>[
        DwGetAnalyticsReport(spec: quizFunnel, period: period),
        DwGetAnalyticsReport(
          spec: const DwAnalyticsReportSpec(
            breakdown: DwAnalyticsBreakdown.byTime(DwAnalyticsTimeBucket.week),
          ),
          period: period,
        ),
        const DwAnalyticsReport(
          total: 12,
          points: [
            DwAnalyticsPoint(label: '1', value: 7),
            DwAnalyticsPoint(label: null, value: 2),
          ],
          other: 3,
        ),
        DwGetAnalyticsCatalog(period: period),
        const DwAnalyticsCatalog(
          events: [
            DwAnalyticsCatalogEvent(
              name: 'homeClicked',
              count: 40,
              propertyKeys: ['block_name'],
            ),
          ],
        ),
        const DwListAnalyticsDashboards(),
        DwAnalyticsDashboard(
          id: 4,
          title: 'Onboarding',
          updatedAt: updatedAt,
          widgets: const [
            DwAnalyticsWidgetSpec(
              type: DwAnalyticsWidgetType.indicator,
              title: 'Active installs',
              report: DwAnalyticsReportSpec(metric: DwAnalyticsMetric.installs),
              comparePrevious: true,
            ),
            DwAnalyticsWidgetSpec(
              type: DwAnalyticsWidgetType.bar,
              title: 'Quiz',
              report: quizFunnel,
            ),
          ],
        ),
        const DwSaveAnalyticsDashboard(title: 'New'),
        const DwDeleteAnalyticsDashboard(id: 4),
      ];
      for (final object in objects) {
        final back = protocol
            .entryNamed(object.dwTypeName)!
            .fromJson(_wire(object.toJson()));
        expect(back, object, reason: object.dwTypeName);
        expect(back.hashCode, object.hashCode, reason: object.dwTypeName);
      }
      expect(
        DwAnalyticsReportSpec.fromJson(
          _wire(const DwAnalyticsReportSpec().toJson()),
        ),
        const DwAnalyticsReportSpec(),
      );
    },
  );

  test('a spec naming what no event can carry is refused, field spec', () {
    DwGetAnalyticsReport report(DwAnalyticsReportSpec spec) =>
        DwGetAnalyticsReport(spec: spec, period: period);

    expect(fields(report(quizFunnel)), isEmpty);
    for (final bad in [
      const DwAnalyticsReportSpec(eventName: 'two words'),
      const DwAnalyticsReportSpec(
        filters: [DwAnalyticsFilter(property: 'a-b', value: '1')],
      ),
      DwAnalyticsReportSpec(
        filters: [
          for (var i = 0; i <= DwAnalyticsReportSpec.maxFilters; i++)
            DwAnalyticsFilter(property: 'k$i', value: '$i'),
        ],
      ),
      const DwAnalyticsReportSpec(
        breakdown: DwAnalyticsBreakdown.byProperty("x'); drop"),
      ),
      const DwAnalyticsReportSpec(
        breakdown: DwAnalyticsBreakdown.byProperty('x', top: 0),
      ),
      const DwAnalyticsReportSpec(
        breakdown: DwAnalyticsBreakdown.byProperty(
          'x',
          top: DwAnalyticsBreakdown.maxTop + 1,
        ),
      ),
    ]) {
      expect(fields(report(bad)), ['spec'], reason: '$bad');
    }
    expect(
      DwCallRefusal(DwAnalyticsRefusal.reportInvalid).code,
      'dw.analyticsReportInvalid',
    );
  });

  test('a period that ends first, or holds too many buckets, is refused', () {
    final backwards = DwAnalyticsPeriod(from: period.to, to: period.from);
    expect(fields(DwGetAnalyticsCatalog(period: backwards)), ['period']);
    expect(
      fields(
        DwGetAnalyticsReport(
          spec: const DwAnalyticsReportSpec(),
          period: DwAnalyticsPeriod(from: period.from, to: period.from),
        ),
      ),
      ['period'],
    );
    final twoYears = DwAnalyticsPeriod(
      from: DateTime.utc(2025, 1, 1),
      to: DateTime.utc(2027, 1, 1),
    );
    DwGetAnalyticsReport byTime(DwAnalyticsTimeBucket bucket) =>
        DwGetAnalyticsReport(
          spec: DwAnalyticsReportSpec(
            breakdown: DwAnalyticsBreakdown.byTime(bucket),
          ),
          period: twoYears,
        );
    expect(fields(byTime(DwAnalyticsTimeBucket.day)), ['period']);
    expect(fields(byTime(DwAnalyticsTimeBucket.week)), isEmpty);
    expect(
      fields(
        DwGetAnalyticsReport(
          spec: const DwAnalyticsReportSpec(),
          period: DwAnalyticsPeriod(
            from: period.from,
            to: period.to,
            utcOffsetMinutes: 15 * 60,
          ),
        ),
      ),
      ['period'],
    );
  });

  test('local days are whole days of this device, and the previous period '
      'is as long and ends where this one starts', () {
    final days = DwAnalyticsPeriod.localDays(
      DateTime(2026, 9, 1, 15),
      DateTime(2026, 9, 7),
    );
    expect(days.from, DateTime(2026, 9, 1).toUtc());
    expect(days.to, DateTime(2026, 9, 8).toUtc());
    expect(
      days.utcOffsetMinutes,
      DateTime(2026, 9, 1).timeZoneOffset.inMinutes,
    );
    expect(days.previous.to, days.from);
    expect(
      days.previous.to.difference(days.previous.from),
      days.to.difference(days.from),
    );
    expect(days.previous.utcOffsetMinutes, days.utcOffsetMinutes);
  });

  test('a dashboard with no title, too many widgets or a broken widget is '
      'refused', () {
    const widget = DwAnalyticsWidgetSpec(
      type: DwAnalyticsWidgetType.pie,
      title: 'Clicks',
      report: DwAnalyticsReportSpec(
        eventName: 'homeClicked',
        breakdown: DwAnalyticsBreakdown.byProperty('block_name'),
      ),
    );
    expect(
      fields(const DwSaveAnalyticsDashboard(title: 'Home', widgets: [widget])),
      isEmpty,
    );
    expect(fields(const DwSaveAnalyticsDashboard(title: '  ')), ['title']);
    expect(
      fields(
        DwSaveAnalyticsDashboard(
          title: 'Home',
          widgets: List.filled(DwAnalyticsDashboard.maxWidgets + 1, widget),
        ),
      ),
      ['widgets'],
    );
    expect(
      fields(
        const DwSaveAnalyticsDashboard(
          title: 'Home',
          widgets: [
            DwAnalyticsWidgetSpec(
              type: DwAnalyticsWidgetType.bar,
              title: '',
              report: DwAnalyticsReportSpec(),
            ),
          ],
        ),
      ),
      ['widgets'],
    );
  });
}
