import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:test/test.dart';

import 'support/protocol.dart';

void main() {
  final b7 = bookingWith(7);
  final b8 = bookingWith(8);
  const n1 = CoachNote(1);

  group('DwChannelUpdates', () {
    test('groups objects by wire name, keeping order within a group', () {
      final deleted = DwDeletedObject.of<ClubBooking>(9, protocol);
      final updates = DwChannelUpdates([b8, n1, deleted, b7]);
      expect(updates.toJson(), {
        'ClubBooking': [b8.toJson(), b7.toJson()],
        'CoachNote': [n1.toJson()],
        'DwDeletedObject': [
          {'type': 'ClubBooking', 'id': 9},
        ],
      });
      expect(updates.objects, [b8, b7, n1, deleted]);
    });

    test('round-trips to typed objects through JSON text', () {
      final deleted = DwDeletedObject.of<ClubBooking>(9, protocol);
      final updates = DwChannelUpdates([b8, n1, deleted, b7]);
      final back = DwChannelUpdates.fromJson(
        roundTrip(updates.toJson()),
        protocol,
      );
      expect(back, updates);
      expect(back.objects.first, isA<ClubBooking>());
      expect(back.objects[2], isA<CoachNote>());
      expect(back.objects.last, isA<DwDeletedObject>());
    });

    test('duplicates by type and id collapse to the last one', () {
      final renamed = b7.copyWith(note: const DwFieldPatch.set('moved'));
      final updates = DwChannelUpdates([b7, b8, renamed]);
      expect(updates.objects, [b8, renamed]);
    });

    test('the same id of another type is another object', () {
      final updates = DwChannelUpdates([b7, const CoachNote(7)]);
      expect(updates.objects, hasLength(2));
    });

    test('an update then a deletion of one row travels as the deletion', () {
      final deleted = DwDeletedObject.of<ClubBooking>(7, protocol);
      expect(DwChannelUpdates([b7, deleted, b8]).objects, [deleted, b8]);
      // And a row re-published after its deletion notice travels as the row.
      expect(DwChannelUpdates([deleted, b7]).objects, [b7]);
    });

    test('only data objects and deletions travel', () {
      expect(
        () => DwChannelUpdates([const RenameBooking(bookingId: 1)]),
        throwsArgumentError,
      );
    });

    test('empty', () {
      expect(DwChannelUpdates.empty.isEmpty, isTrue);
      expect(DwChannelUpdates(const []), DwChannelUpdates.empty);
      expect(DwChannelUpdates.empty.toJson(), isEmpty);
      expect(
        DwChannelUpdates.fromJson(<String, Object?>{}, protocol),
        DwChannelUpdates.empty,
      );
    });

    test('malformed updates are a FormatException', () {
      for (final json in <Object?>[
        null,
        [],
        {'Unknown': []},
        {
          'ListMyBookings': [<String, Object?>{}],
        },
        {'ClubBooking': []},
        {'ClubBooking': 'x'},
        {
          'CoachNote': [1],
        },
        {
          'CoachNote': [
            {'id': 1},
            {'id': 1},
          ],
        },
        {
          'CoachNote': [
            {'id': 1},
          ],
          'DwDeletedObject': [
            {'type': 'CoachNote', 'id': 1},
          ],
        },
        {
          'DwDeletedObject': [
            {'type': 'RenameBooking', 'id': 1},
          ],
        },
      ]) {
        expect(
          () => DwChannelUpdates.fromJson(roundTrip(json), protocol),
          throwsFormatException,
          reason: '$json',
        );
      }
    });
  });

  group('DwUpdateTransport (D-036)', () {
    test('groups by channel, then by type; every object keeps its channel', () {
      final deleted = DwDeletedObject.of<ClubBooking>(9, protocol);
      final transport = DwUpdateTransport([
        ('bookings:7', b8),
        ('schedule', n1),
        ('bookings:7', deleted),
        ('bookings:8', b7),
      ]);
      expect(transport.toJson(), {
        'bookings:7': {
          'ClubBooking': [b8.toJson()],
          'DwDeletedObject': [
            {'type': 'ClubBooking', 'id': 9},
          ],
        },
        'schedule': {
          'CoachNote': [n1.toJson()],
        },
        'bookings:8': {
          'ClubBooking': [b7.toJson()],
        },
      });
      expect(transport.channels.keys, ['bookings:7', 'schedule', 'bookings:8']);
      expect(transport.objectsOn('bookings:7'), [b8, deleted]);
      expect(transport.objectsOn('bookings:8'), [b7]);
      expect(transport.objectsOn('news'), isEmpty);
    });

    test('round-trips to typed objects through JSON text', () {
      final transport = DwUpdateTransport([
        ('bookings:7', b8),
        ('schedule', n1),
        ('bookings:7', DwDeletedObject.of<ClubBooking>(9, protocol)),
      ]);
      final back = DwUpdateTransport.fromJson(
        roundTrip(transport.toJson()),
        protocol,
      );
      expect(back, transport);
      expect(back.objectsOn('bookings:7').first, isA<ClubBooking>());
      expect(back.objectsOn('bookings:7').last, isA<DwDeletedObject>());
      expect(back.objectsOn('schedule').single, isA<CoachNote>());
    });

    test('collapses by channel, type and id: one object on two channels '
        'travels under both', () {
      final renamed = b7.copyWith(note: const DwFieldPatch.set('moved'));
      final transport = DwUpdateTransport([
        ('profile:7', b7),
        ('admin', b7),
        ('profile:7', renamed),
      ]);
      expect(transport.objectsOn('profile:7'), [renamed]);
      expect(transport.objectsOn('admin'), [b7]);
    });

    test('equality ignores the order between channels', () {
      final a = DwUpdateTransport([('x', b7), ('y', b8)]);
      final b = DwUpdateTransport([('y', b8), ('x', b7)]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(DwUpdateTransport([('x', b8), ('y', b7)])));
    });

    test('an empty channel name and a non-object are refused', () {
      expect(() => DwUpdateTransport([('', b7)]), throwsArgumentError);
      expect(
        () => DwUpdateTransport([('x', const RenameBooking(bookingId: 1))]),
        throwsArgumentError,
      );
    });

    test('empty', () {
      expect(DwUpdateTransport.empty.isEmpty, isTrue);
      expect(DwUpdateTransport(const []), DwUpdateTransport.empty);
      expect(DwUpdateTransport.empty.toJson(), isEmpty);
      expect(
        DwUpdateTransport.fromJson(<String, Object?>{}, protocol),
        DwUpdateTransport.empty,
      );
    });

    test('a malformed transport is a FormatException', () {
      for (final json in <Object?>[
        null,
        [],
        // The type-only shape of before D-036: a channel named "ClubBooking"
        // whose groups are not a map.
        {
          'ClubBooking': [b7.toJson()],
        },
        {'x': <String, Object?>{}},
        {
          '': {
            'CoachNote': [
              {'id': 1},
            ],
          },
        },
        {
          'x': {'Unknown': []},
        },
        {
          'x': {
            'CoachNote': [
              {'id': 1},
              {'id': 1},
            ],
          },
        },
      ]) {
        expect(
          () => DwUpdateTransport.fromJson(roundTrip(json), protocol),
          throwsFormatException,
          reason: '$json',
        );
      }
    });
  });
}
