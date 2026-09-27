import 'package:dartway_analytics_server/dartway_analytics_server.dart';
import 'package:dartway_core_server/testing.dart';
import 'package:test/test.dart';

import 'support/app_harness.dart';

/// Analytics on real clients: what the app records, an admin reads as a
/// report and keeps as a dashboard; a member reads none of it.
void main() {
  late AppHarness app;

  setUpAll(() async => app = await AppHarness.start());
  tearDownAll(() => app.stop());

  test('an admin reads what the app recorded and keeps a dashboard; a member '
      'is refused every analytics read', () async {
    final anna = await app.admin('79990007001', 'Anna');
    final vera = await app.signUp('79990007002', firstName: 'Vera');
    final now = DateTime.now().toUtc();

    (await vera.client.command(
      DwTrackEvents(
        installId: 'starter-analytics-install-1',
        platform: DwAnalyticsPlatform.web,
        appVersion: '1.0.0+1',
        events: [
          for (final (i, block) in ['feed', 'feed', 'banner'].indexed)
            DwTrackedEvent(
              name: 'homeClicked',
              occurredAt: now,
              sequence: i + 1,
              properties: {'block_name': block},
            ),
        ],
      ),
    )).valueOrThrow;

    final today = DwAnalyticsPeriod.localDays(DateTime.now(), DateTime.now());
    const clicks = DwAnalyticsReportSpec(
      eventName: 'homeClicked',
      breakdown: DwAnalyticsBreakdown.byProperty('block_name'),
    );
    final report = (await anna.client.fetch(
      DwGetAnalyticsReport(spec: clicks, period: today),
    )).valueOrThrow;
    expect(report.total, 3);
    expect(report.points, const [
      DwAnalyticsPoint(label: 'feed', value: 2),
      DwAnalyticsPoint(label: 'banner', value: 1),
    ]);

    final saved = (await anna.client.command(
      const DwSaveAnalyticsDashboard(
        title: 'Home',
        widgets: [
          DwAnalyticsWidgetSpec(
            type: DwAnalyticsWidgetType.pie,
            title: 'Home clicks',
            report: clicks,
          ),
        ],
      ),
    )).valueOrThrow;
    final listed = (await anna.client.fetch(
      const DwListAnalyticsDashboards(),
    )).valueOrThrow;
    expect(listed.map((d) => d.id), contains(saved.id));

    for (final call in <DwDataRequest<Object?>>[
      DwGetAnalyticsReport(spec: clicks, period: today),
      DwGetAnalyticsCatalog(period: today),
      const DwListAnalyticsDashboards(),
    ]) {
      expect(
        await vera.client.fetch(call),
        refusedWith(DwCoreRefusal.forbidden),
        reason: '$call',
      );
    }
    expect(
      await vera.client.command(DwDeleteAnalyticsDashboard(id: saved.id)),
      refusedWith(DwCoreRefusal.forbidden),
    );
  });
}
