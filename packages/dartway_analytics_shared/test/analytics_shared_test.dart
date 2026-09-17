import 'dart:convert';

import 'package:dartway_analytics_shared/dartway_analytics_shared.dart';
import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:test/test.dart';

enum ShopEvent with DwAnalyticsEvent { productViewed }

void main() {
  final at = DateTime.utc(2026, 9, 17, 10, 30);

  test('a batch travels through JSON text and comes back equal', () {
    final batch = DwTrackEvents(
      installId: 'a1b2c3d4e5f6a7b8',
      platform: DwAnalyticsPlatform.web,
      appVersion: '1.0.0+3',
      events: [
        DwTrackedEvent(
          name: ShopEvent.productViewed.eventName,
          occurredAt: at,
          sequence: 4,
          properties: const {
            'id': 12,
            'price': 9.5,
            'new': true,
            'from': 'x',
            'none': null,
          },
        ),
        DwTrackedEvent(
          name: DwAppEvent.appOpened.eventName,
          occurredAt: at,
          sequence: 5,
        ),
      ],
    );
    final json = jsonDecode(jsonEncode(batch.toJson())) as Map<String, Object?>;
    expect(DwTrackEvents.fromJson(json), batch);
    expect(batch.validate(), isEmpty);
  });

  test(
    'framework events are named under dw., project events by their name',
    () {
      expect(DwAppEvent.appBackgrounded.eventName, 'dw.appBackgrounded');
      expect(ShopEvent.productViewed.eventName, 'productViewed');
    },
  );

  test('what the store does not take is named', () {
    DwTrackedEvent withProps(
      Map<String, Object?> properties, {
      String name = 'ok',
    }) => DwTrackedEvent(
      name: name,
      occurredAt: at,
      sequence: 1,
      properties: properties,
    );

    expect(withProps(const {}, name: 'two words').problem, contains('name'));
    expect(withProps(const {'bad key': 1}).problem, contains('bad key'));
    expect(
      withProps(const {
        'list': [1],
      }).problem,
      contains('list'),
    );
    expect(withProps({'long': 'x' * 1001}).problem, contains('long'));
    expect(withProps(const {'nan': double.nan}).problem, contains('nan'));
    expect(
      withProps({for (var i = 0; i < 31; i++) 'k$i': i}).problem,
      contains('31 properties'),
    );
    expect(withProps(const {'fine': 'yes'}).problem, isNull);
  });

  test(
    'a batch refuses a malformed install id, and events it cannot store',
    () {
      List<String?> fields(DwTrackEvents batch) => [
        for (final refusal in batch.validate()) refusal.field,
      ];
      DwTrackEvents batchOf(String installId, List<DwTrackedEvent> events) =>
          DwTrackEvents(
            installId: installId,
            platform: DwAnalyticsPlatform.android,
            appVersion: '1.0.0+1',
            events: events,
          );
      final fine = DwTrackedEvent(name: 'ok', occurredAt: at, sequence: 1);
      expect(fields(batchOf('short', [fine])), ['installId']);
      expect(fields(batchOf('a1b2c3d4e5f6a7b8', const [])), ['events']);
      expect(
        fields(
          batchOf(
            'a1b2c3d4e5f6a7b8',
            List.filled(DwTrackEvents.maxEvents + 1, fine),
          ),
        ),
        ['events'],
      );
      expect(
        DwCallRefusal(DwAnalyticsRefusal.batchInvalid).code,
        'dw.analyticsBatchInvalid',
      );
    },
  );
}
