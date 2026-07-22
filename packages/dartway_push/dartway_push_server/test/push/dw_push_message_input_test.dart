import 'package:dartway_push_server/dartway_push_server.dart';
import 'package:test/test.dart';

void main() {
  group('DwPushMessageInput', () {
    final scheduledAt = DateTime.utc(2026, 7, 20, 10);
    final expiresAt = scheduledAt.add(const Duration(days: 1));

    test('normalizes identifiers and text', () {
      final input = DwPushMessageInput(
        deduplicationKey: ' campaign:42 ',
        category: ' news ',
        title: ' New lesson ',
        body: ' Open it now ',
        scheduledAt: scheduledAt,
        expiresAt: expiresAt,
      );

      expect(input.deduplicationKey, 'campaign:42');
      expect(input.category, 'news');
      expect(input.title, 'New lesson');
      expect(input.body, 'Open it now');
    });

    test('normalizes schedule timestamps to UTC', () {
      final localSchedule = DateTime.parse('2026-07-20T15:00:00+05:00');
      final input = DwPushMessageInput(
        deduplicationKey: 'campaign:42',
        category: 'news',
        title: 'New lesson',
        scheduledAt: localSchedule,
        expiresAt: localSchedule.add(const Duration(hours: 1)),
      );

      expect(input.scheduledAt, DateTime.utc(2026, 7, 20, 10));
      expect(input.scheduledAt.isUtc, isTrue);
      expect(input.expiresAt.isUtc, isTrue);
    });

    test('requires expiration to be after scheduling', () {
      expect(
        () => DwPushMessageInput(
          deduplicationKey: 'campaign:42',
          category: 'news',
          title: 'New lesson',
          scheduledAt: scheduledAt,
          expiresAt: scheduledAt,
        ),
        throwsArgumentError,
      );
    });

    test('bounds provider data so a queue row cannot grow without limit', () {
      expect(
        () => DwPushMessageInput(
          deduplicationKey: 'campaign:42',
          category: 'news',
          title: 'New lesson',
          data: {
            for (var index = 0; index < 51; index++) 'key-$index': 'value',
          },
          scheduledAt: scheduledAt,
          expiresAt: expiresAt,
        ),
        throwsArgumentError,
      );
      expect(
        () => DwPushMessageInput(
          deduplicationKey: 'campaign:42',
          category: 'news',
          title: 'New lesson',
          data: {
            for (var index = 0; index < 5; index++)
              '$index': ''.padLeft(4096, 'x'),
          },
          scheduledAt: scheduledAt,
          expiresAt: expiresAt,
        ),
        throwsArgumentError,
      );
    });
  });
}
