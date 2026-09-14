import 'package:dartway_core/dartway_core.dart';
import 'package:test/test.dart';

import 'support/protocol.dart';

void main() {
  final cancelled = bookingWith(8, status: BookingStatus.cancelled);
  const note = CoachNote(7);
  final deletion = DwDeletedObject.of<ClubBooking>(7, protocol);

  /// The action of every kind for: a matching item, a non-matching item, a
  /// deletion, and an object of another type.
  Map<String, DwUpdateAction> actions(DwDataRequest<Object?> request) => {
    'matching': request.onUpdate(booking),
    'notMatching': request.onUpdate(cancelled),
    'deletion': request.onUpdate(deletion),
    'foreign': request.onUpdate(note),
  };

  group('default update actions per kind (R2.3)', () {
    test('single: update; a deletion removes', () {
      expect(actions(const GetBooking()), {
        'matching': DwUpdateAction.update,
        'notMatching': DwUpdateAction.update,
        'deletion': DwUpdateAction.remove,
        'foreign': DwUpdateAction.ignore,
      });
    });

    test('maybe: matches ? upsert : remove', () {
      expect(actions(const FindBooking(7)), {
        'matching': DwUpdateAction.upsert,
        'notMatching': DwUpdateAction.remove,
        'deletion': DwUpdateAction.remove,
        'foreign': DwUpdateAction.ignore,
      });
    });

    test('list: matches ? upsert : remove', () {
      expect(actions(const ListBookedOnly()), {
        'matching': DwUpdateAction.upsert,
        'notMatching': DwUpdateAction.remove,
        'deletion': DwUpdateAction.remove,
        'foreign': DwUpdateAction.ignore,
      });
    });

    test('list: every item matches unless matches says otherwise', () {
      expect(const ListMyBookings().onUpdate(cancelled), DwUpdateAction.upsert);
      expect(
        const ListMyBookings(status: BookingStatus.booked).onUpdate(cancelled),
        DwUpdateAction.remove,
      );
    });

    test('list.updateOnly(): update, never insert; a deletion removes', () {
      expect(actions(const ListBookingsUpdateOnly()), {
        'matching': DwUpdateAction.update,
        'notMatching': DwUpdateAction.update,
        'deletion': DwUpdateAction.remove,
        'foreign': DwUpdateAction.ignore,
      });
    });

    test('list.refetchOnUpdate(): everything refetches', () {
      expect(actions(const ListBookingStats()), {
        'matching': DwUpdateAction.refetch,
        'notMatching': DwUpdateAction.refetch,
        'deletion': DwUpdateAction.refetch,
        'foreign': DwUpdateAction.ignore,
      });
    });

    test('page: matches ? upsert : remove; .updateOnly(): update', () {
      expect(actions(const FeedBookings()), {
        'matching': DwUpdateAction.upsert,
        'notMatching': DwUpdateAction.upsert,
        'deletion': DwUpdateAction.remove,
        'foreign': DwUpdateAction.ignore,
      });
      expect(actions(const FeedBookingsUpdateOnly()), {
        'matching': DwUpdateAction.update,
        'notMatching': DwUpdateAction.update,
        'deletion': DwUpdateAction.remove,
        'foreign': DwUpdateAction.ignore,
      });
    });

    test('table: update, never insert; a deletion refetches the page', () {
      expect(actions(const ListBookingTable()), {
        'matching': DwUpdateAction.update,
        'notMatching': DwUpdateAction.update,
        'deletion': DwUpdateAction.refetch,
        'foreign': DwUpdateAction.ignore,
      });
    });

    test('window: matches ? upsert : remove', () {
      expect(actions(const BookingHistory()), {
        'matching': DwUpdateAction.upsert,
        'notMatching': DwUpdateAction.remove,
        'deletion': DwUpdateAction.remove,
        'foreign': DwUpdateAction.ignore,
      });
    });

    test('overriding onUpdate stays possible for a special case', () {
      const request = _PinnedFirst();
      expect(request.onUpdate(booking), DwUpdateAction.refetch);
      expect(request.onUpdate(bookingWith(9)), DwUpdateAction.upsert);
    });
  });

  group('item type', () {
    final requests = <DwDataRequest<Object?>>[
      const GetBooking(),
      const FindBooking(7),
      const ListMyBookings(),
      const ListBookingsUpdateOnly(),
      const FeedBookings(),
      const ListBookingTable(),
      const BookingHistory(),
    ];

    test('each kind accepts exactly its item type', () {
      for (final request in requests) {
        expect(request.acceptsItem(booking), isTrue, reason: '$request');
        expect(request.acceptsItem(note), isFalse, reason: '$request');
        expect(request.acceptsItem(null), isFalse, reason: '$request');
      }
    });

    test('each kind accepts exactly the deletions of its item type', () {
      for (final request in requests) {
        expect(request.acceptsDeletion(deletion, protocol), isTrue);
        expect(
          request.acceptsDeletion(
            DwDeletedObject.of<CoachNote>(7, protocol),
            protocol,
          ),
          isFalse,
        );
      }
    });
  });

  group('page sizes', () {
    test('page and window: constants, clamped by maxPageSize', () {
      const feed = FeedBookings();
      expect(feed.pageSize, 20);
      expect(feed.maxPageSize, 100);
      expect(feed.servedPageSize(null), 20);
      expect(feed.servedPageSize(60), 60);
      expect(feed.servedPageSize(500), 100);

      const history = BookingHistory();
      expect(history.maxPageSize, 30, reason: 'defaults to pageSize');
      expect(history.servedPageSize(31), 30);
    });

    test('page sizes are not serialised and do not change equality', () {
      expect(const FeedBookings().toJson(), isEmpty);
      expect(const ListBookingsUpdateOnly(), const ListBookingsUpdateOnly());
    });

    test('table: page and pageSize are fields; the server clamps', () {
      const table = ListBookingTable(page: 3, pageSize: 80);
      expect(table.toJson(), {'page': 3, 'pageSize': 80});
      expect(table.servedPageSize, 50);
      expect(table.offset, 100);
      expect(table.checkPage(), isNull);
      expect(
        const ListBookingTable(page: 0).checkPage(),
        DwCallRefusal(DwCoreRefusal.invalid, field: 'page', params: {'min': 1}),
      );
      expect(
        const ListBookingTable(pageSize: 0).checkPage()?.field,
        'pageSize',
      );
    });
  });

  group('results per kind', () {
    Object? wire(DwDataRequest<Object?> request, Object? result) =>
        roundTrip(request.encodeResult(result, protocol));

    test('single and maybe', () {
      const single = GetBooking();
      expect(single.decodeResult(wire(single, booking), protocol), booking);

      const maybe = FindBooking(7);
      expect(maybe.decodeResult(wire(maybe, booking), protocol), booking);
      expect(wire(maybe, null), isNull);
      expect(maybe.decodeResult(null, protocol), isNull);
      expect(() => single.decodeResult(null, protocol), throwsFormatException);
    });

    test('a list keeps its reified item type', () {
      const request = ListMyBookings();
      final decoded = request.decodeResult(wire(request, [booking]), protocol);
      expect(decoded, isA<List<ClubBooking>>());
      expect(decoded, [booking]);
      expect(
        () => request.decodeResult({'items': []}, protocol),
        throwsFormatException,
      );
    });

    test('page', () {
      const request = FeedBookings();
      final page = DwPageResult([booking, bookingWith(8)], hasMore: true);
      final json = wire(request, page);
      expect(json, {
        'items': [booking.toJson(), bookingWith(8).toJson()],
        'hasMore': true,
      });
      final decoded = request.decodeResult(json, protocol);
      expect(decoded, page);
      expect(decoded.items, isA<List<ClubBooking>>());
      expect(
        () => request.decodeResult({'items': []}, protocol),
        throwsFormatException,
      );
    });

    test('table page', () {
      const request = ListBookingTable(page: 2, pageSize: 2);
      final page = DwTablePage(
        [booking, bookingWith(8)],
        total: 5,
        page: 2,
        pageSize: 2,
      );
      final json = wire(request, page);
      expect(json, {
        'items': [booking.toJson(), bookingWith(8).toJson()],
        'total': 5,
        'page': 2,
        'pageSize': 2,
      });
      final decoded = request.decodeResult(json, protocol);
      expect(decoded, page);
      expect(decoded.pageCount, 3);
      expect(
        DwTablePage<ClubBooking>([], total: 0, page: 1, pageSize: 20).pageCount,
        0,
      );
    });

    test('a table page that cannot exist is refused both ways', () {
      expect(
        () => DwTablePage([booking], total: 1, page: 0, pageSize: 1),
        throwsArgumentError,
      );
      expect(
        () => DwTablePage([booking, booking], total: 2, page: 1, pageSize: 1),
        throwsArgumentError,
      );
      expect(
        () => DwTablePage<ClubBooking>([], total: -1, page: 1, pageSize: 1),
        throwsArgumentError,
      );
      expect(
        () => const ListBookingTable().decodeResult({
          'items': [],
          'total': 0,
          'page': 0,
          'pageSize': 20,
        }, protocol),
        throwsFormatException,
      );
    });

    test('window: cursors present exactly when rows exist past an end', () {
      const request = BookingHistory();
      final older = DwWindowCursor.encode(DateTime.utc(2026), 8);
      final window = DwWindowResult([
        booking,
        bookingWith(8),
      ], olderCursor: older);
      expect(window.hasOlder, isTrue);
      expect(window.hasNewer, isFalse);
      final json = wire(request, window);
      expect(json, {
        'items': [booking.toJson(), bookingWith(8).toJson()],
        'olderCursor': older,
      });
      final decoded = request.decodeResult(json, protocol);
      expect(decoded, window);
      expect(decoded.items, isA<List<ClubBooking>>());

      final newest = DwWindowResult<ClubBooking>([]);
      expect(wire(request, newest), {'items': []});
      expect(
        () => DwWindowResult<ClubBooking>([], newerCursor: 'x'),
        throwsArgumentError,
      );
      expect(
        () => request.decodeResult({'items': [], 'olderCursor': 'x'}, protocol),
        throwsFormatException,
      );
    });
  });
}

final class _PinnedFirst extends DwListRequest<ClubBooking> {
  const _PinnedFirst();

  @override
  DwUpdateAction onUpdate(Object item) => item is ClubBooking && item.id == 7
      ? DwUpdateAction.refetch
      : super.onUpdate(item);

  @override
  String get dwTypeName => '_PinnedFirst';

  @override
  Map<String, Object?> toJson() => const {};
}
