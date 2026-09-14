import 'package:dartway_core/dartway_core.dart';
import 'package:test/test.dart';

import 'support/protocol.dart';

void main() {
  final b7 = bookingWith(7);
  final b8 = bookingWith(8);
  const n1 = CoachNote(1);

  group('DwTransport', () {
    test('groups objects by wire name, keeping order within a group', () {
      final deleted = DwDeleted.of<ClubBooking>(9, protocol);
      final transport = DwTransport([b8, n1, deleted, b7]);
      expect(transport.toJson(), {
        'ClubBooking': [b8.toJson(), b7.toJson()],
        'CoachNote': [n1.toJson()],
        'DwDeleted': [
          {'type': 'ClubBooking', 'id': 9},
        ],
      });
      expect(transport.objects, [b8, b7, n1, deleted]);
    });

    test('round-trips to typed objects through JSON text', () {
      final deleted = DwDeleted.of<ClubBooking>(9, protocol);
      final transport = DwTransport([b8, n1, deleted, b7]);
      final back = DwTransport.fromJson(
        roundTrip(transport.toJson()),
        protocol,
      );
      expect(back, transport);
      expect(back.objects.first, isA<ClubBooking>());
      expect(back.objects[2], isA<CoachNote>());
      expect(back.objects.last, isA<DwDeleted>());
    });

    test('duplicates by type and id collapse to the last one', () {
      final renamed = b7.copyWith(note: const DwPatch.set('moved'));
      final transport = DwTransport([b7, b8, renamed]);
      expect(transport.objects, [b8, renamed]);
    });

    test('the same id of another type is another object', () {
      final transport = DwTransport([b7, const CoachNote(7)]);
      expect(transport.objects, hasLength(2));
    });

    test('an update then a deletion of one row travels as the deletion', () {
      final deleted = DwDeleted.of<ClubBooking>(7, protocol);
      expect(DwTransport([b7, deleted, b8]).objects, [deleted, b8]);
      // And a row re-published after its deletion notice travels as the row.
      expect(DwTransport([deleted, b7]).objects, [b7]);
    });

    test('only data objects and deletions travel', () {
      expect(
        () => DwTransport([const RenameBooking(bookingId: 1)]),
        throwsArgumentError,
      );
    });

    test('empty', () {
      expect(DwTransport.empty.isEmpty, isTrue);
      expect(DwTransport(const []), DwTransport.empty);
      expect(DwTransport.empty.toJson(), isEmpty);
      expect(
        DwTransport.fromJson(<String, Object?>{}, protocol),
        DwTransport.empty,
      );
    });

    test('a malformed transport is a FormatException', () {
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
          'DwDeleted': [
            {'type': 'CoachNote', 'id': 1},
          ],
        },
        {
          'DwDeleted': [
            {'type': 'RenameBooking', 'id': 1},
          ],
        },
      ]) {
        expect(
          () => DwTransport.fromJson(roundTrip(json), protocol),
          throwsFormatException,
          reason: '$json',
        );
      }
    });
  });
}
