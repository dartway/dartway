import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_client/testing.dart';
import 'package:test/test.dart';

import 'support.dart';

const d = RoomView(id: 4, name: 'd', rank: 40);
const e = RoomView(id: 5, name: 'e', rank: 50);

List<ChatLine> lines(int count) => [
  for (var i = count; i >= 1; i--) ChatLine(id: i, at: i * 10, text: 'line $i'),
];

List<int> idsOf(List<DwDataObject> items) => [
  for (final item in items) item.id as int,
];

void main() {
  group('pages', () {
    test('loads the first page, then the next on loadMore', () async {
      final h = Harness()..serveRooms();
      h.rooms = [a, b, c, d, e];
      await h.start();
      final watch = h.client.watchPages(const FeedRooms());
      await settle();
      expect(
        watch.state,
        DwRequestData(DwPagedData(const [a, b], hasMore: true), live: true),
      );

      await watch.loadMore();
      expect(pagedItems(watch.state), [a, b, c, d]);
      await watch.loadMore();
      expect(pagedItems(watch.state), [a, b, c, d, e]);
      expect(watch.hasMore, isFalse);
      expect(
        [for (final call in h.server.callsOf<FeedRooms>()) call.query],
        [
          {},
          {'offset': '2'},
          {'offset': '4'},
        ],
      );
      await watch.loadMore();
      expect(h.server.callsOf<FeedRooms>(), hasLength(3), reason: 'no more');
    });

    test('loadMore is idempotent while a page is on its way', () async {
      final h = Harness()..serveRooms();
      h.rooms = [a, b, c, d];
      await h.start();
      final watch = h.client.watchPages(const FeedRooms());
      await settle();
      final states = DwStreamRecording(watch.states);
      final loads = [watch.loadMore(), watch.loadMore(), watch.loadMore()];
      expect(dataOf(watch.state).loadingMore, isTrue);
      await Future.wait(loads);
      expect(h.server.callsOf<FeedRooms>(), hasLength(2));
      expect(dataOf(states.last).loadingMore, isFalse);
    });

    test('a next page that fails keeps the loaded rows and says why', () async {
      final h = Harness()..serveRooms();
      h.rooms = [a, b, c];
      await h.start();
      final watch = h.client.watchPages(const FeedRooms());
      await settle();
      h.server.onRequest<FeedRooms>(
        (request, call) => const DwCallFailed<DwPageResult<RoomView>>('x'),
      );
      await watch.loadMore();
      final data = dataOf(watch.state);
      expect(data.items, [a, b]);
      expect(
        data.loadMoreError,
        const DwFailedException('x', call: 'FeedRooms'),
      );
    });

    test(
      'an insert sorting past the loaded pages is dropped while more exist',
      () async {
        final h = Harness()..serveRooms();
        h.rooms = [a, b, c];
        await h.start();
        final watch = h.client.watchPages(const FeedRooms());
        await settle();
        h.server.publish(roomsChannel, [
          const RoomView(id: 9, name: 'late', rank: 99),
          const RoomView(id: 8, name: 'early', rank: 15),
        ]);
        await settle();
        expect(idsOf(pagedItems(watch.state)), [1, 8, 2]);
      },
    );

    test('without a sort a new object goes to the head', () async {
      final h = Harness()..serveRooms();
      h.rooms = [a, b, c];
      await h.start();
      final watch = h.client.watchPages(const FeedRooms(sorted: false));
      await settle();
      h.server.publish(roomsChannel, [d]);
      await settle();
      expect(pagedItems(watch.state), [d, a, b]);
    });

    test('a refetch reloads as many rows as are loaded, in one call up to '
        'maxPageSize and page by page beyond', () async {
      final h = Harness()..serveRooms();
      h.rooms = [a, b, c, d, e];
      await h.start();
      final watch = h.client.watchPages(const FeedRooms());
      await settle();
      await watch.loadMore();
      await watch.loadMore();
      expect(pagedItems(watch.state), hasLength(5));
      h.server.calls.clear();

      await watch.refetch();
      expect(pagedItems(watch.state), [a, b, c, d, e]);
      expect(
        [for (final call in h.server.callsOf<FeedRooms>()) call.query],
        [
          {'pageSize': '3'},
          {'offset': '3'},
        ],
      );
    });

    test('shows the rows as refreshing while a reload runs', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final watch = h.client.watchPages(const FeedRooms());
      await settle();
      final states = DwStreamRecording(watch.states);
      await watch.refetch();
      await settle();
      expect(
        states.values.map((s) => (s as DwRequestData).refreshing).toList(),
        [false, true, false],
      );
    });

    test('loadMore asked during a reload loads after it', () async {
      final h = Harness()..serveRooms();
      h.rooms = [a, b, c, d];
      await h.start();
      final watch = h.client.watchPages(const FeedRooms());
      await settle();
      final reload = watch.refetch();
      final more = watch.loadMore();
      await reload;
      await more;
      expect(pagedItems(watch.state), [a, b, c, d]);
    });
  });

  group('table', () {
    test('each numbered page is its own entry with the total', () async {
      final h = Harness()..serveRooms();
      h.rooms = [a, b, c];
      await h.start();
      final first = h.client.watchTable(const RoomsTable());
      final second = h.client.watchTable(const RoomsTable(page: 2));
      await settle();
      expect(dataOf(first.state).items, [a, b]);
      expect(dataOf(second.state).items, [c]);
      expect(dataOf(first.state).total, 3);
      expect(dataOf(first.state).pageCount, 2);
      expect(dataOf(first.state), isA<DwTablePage<RoomView>>());
    });

    test('a row on the page is updated in place, without reading the page '
        'again', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final table = h.client.watchTable(const RoomsTable());
      await settle();
      const renamed = RoomView(id: 2, name: 'b2', rank: 20);
      h.server.publish(roomsChannel, [renamed]);
      await settle();
      expect(dataOf(table.state).items, [a, renamed]);
      expect(dataOf(table.state), isA<DwTablePage<RoomView>>());
      expect(h.server.requestsOf<RoomsTable>(), hasLength(1));
    });

    test('a new matching row is never inserted: the page is read again, so '
        'the total and the paging stay true — once for a burst', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final first = h.client.watchTable(const RoomsTable());
      final second = h.client.watchTable(const RoomsTable(page: 2));
      await settle();
      expect(dataOf(second.state).items, isEmpty);
      expect(dataOf(first.state).total, 2);

      const newest = RoomView(id: 9, name: 'aa', rank: 5);
      const others = [
        RoomView(id: 10, name: 'x', rank: 40),
        RoomView(id: 11, name: 'y', rank: 50),
        RoomView(id: 12, name: 'z', rank: 60),
      ];
      h.rooms = [newest, a, b, ...others];
      // Published one by one: each arrives as its own update.
      for (final room in [newest, ...others]) {
        h.server.publish(roomsChannel, [room]);
      }
      await settle();
      expect(dataOf(first.state).items, [newest, a]);
      expect(dataOf(first.state).total, 6);
      expect(dataOf(second.state).items, [b, others.first]);
      expect(
        h.server.requestsOf<RoomsTable>().where((r) => r.page == 1).length,
        lessThanOrEqualTo(3),
        reason: 'one read in flight and one after it, however many rows came',
      );
    });

    test('a row on the page that stops matching reads the page again; an '
        'update of a row that matches nothing on it still does, since it may '
        'have left an earlier page', () async {
      final h = Harness()..serveRooms();
      h.rooms = [a, b, c];
      await h.start();
      final table = h.client.watchTable(const RoomsTable(minRank: 15));
      await settle();
      expect(dataOf(table.state).items, [b, c]);

      const demoted = RoomView(id: 2, name: 'b', rank: 1);
      h.rooms = [a, demoted, c];
      h.server.publish(roomsChannel, [demoted]);
      await settle();
      expect(dataOf(table.state).items, [c]);
      expect(dataOf(table.state).total, 1);
      expect(h.server.requestsOf<RoomsTable>(), hasLength(2));
    });

    test('a deletion reads the page again, since later rows move up', () async {
      final h = Harness()..serveRooms();
      h.rooms = [a, b, c];
      await h.start();
      final second = h.client.watchTable(const RoomsTable(page: 2));
      await settle();
      expect(dataOf(second.state).items, [c]);
      await h.client.command(const DeleteRoom(1));
      await settle();
      expect(dataOf(second.state).items, isEmpty);
      expect(dataOf(second.state).total, 2);
    });

    test('watch refuses paginated kinds, naming the method', () {
      final h = Harness();
      expect(() => h.client.watch(const RoomsTable()), throwsArgumentError);
      expect(() => h.client.watch(const FeedRooms()), throwsArgumentError);
      expect(() => h.client.watch(const ReadChat()), throwsArgumentError);
    });
  });

  group('window', () {
    test('opens at the newest rows and loads older ones', () async {
      final h = Harness()..serveRooms();
      h.chat = lines(8);
      await h.start();
      final watch = h.client.watchWindow(const ReadChat());
      await settle();
      var data = dataOf(watch.state);
      expect(idsOf(data.items), [8, 7, 6]);
      expect((data.hasOlder, data.hasNewer), (true, false));

      final loads = [watch.loadOlder(), watch.loadOlder()];
      expect(dataOf(watch.state).loadingOlder, isTrue);
      await Future.wait(loads);
      data = dataOf(watch.state);
      expect(idsOf(data.items), [8, 7, 6, 5, 4, 3]);
      expect(data.prependedCount, 0);
      expect(h.server.callsOf<ReadChat>(), hasLength(2), reason: 'idempotent');
      await watch.loadOlder();
      expect(idsOf(dataOf(watch.state).items), [8, 7, 6, 5, 4, 3, 2, 1]);
      expect(dataOf(watch.state).hasOlder, isFalse);
    });

    test('opens at an anchor and loads newer rows, saying how many were '
        'prepended', () async {
      final h = Harness()..serveRooms();
      h.chat = lines(10);
      await h.start();
      final anchor = DwWindowCursor.encode(30, 3);
      final watch = h.client.watchWindow(const ReadChat(), anchor: anchor);
      await settle();
      var data = dataOf(watch.state);
      expect(idsOf(data.items), [4, 3, 2]);
      expect((data.hasOlder, data.hasNewer), (true, true));
      expect(h.server.callsOf<ReadChat>().single.query, {'anchor': anchor});

      await watch.loadNewer();
      data = dataOf(watch.state);
      expect(idsOf(data.items), [7, 6, 5, 4, 3, 2]);
      expect(data.prependedCount, 3);
      await watch.loadNewer();
      data = dataOf(watch.state);
      expect(idsOf(data.items).first, 10);
      expect(data.hasNewer, isFalse);
    });

    test('a new row is inserted at the head only while the window shows the '
        'newest rows', () async {
      final h = Harness()..serveRooms();
      h.chat = lines(6);
      await h.start();
      final newest = h.client.watchWindow(const ReadChat());
      final anchored = h.client.watchWindow(
        const ReadChat(),
        anchor: DwWindowCursor.encode(20, 2),
      );
      await settle();

      const line7 = ChatLine(id: 7, at: 70, text: 'line 7');
      h.chat = [line7, ...h.chat];
      h.server.publish(chatChannel, [line7]);
      h.server.publish(chatChannel, [line7]);
      await settle();

      final top = dataOf(newest.state);
      expect(idsOf(top.items), [7, 6, 5, 4]);
      expect(
        top.prependedCount,
        1,
        reason: 'the equal second update changed nothing and emitted nothing',
      );
      final middle = dataOf(anchored.state);
      expect(idsOf(middle.items), [3, 2, 1]);
      expect(middle.unseenNewerCount, 1, reason: 'counted once');

      await anchored.loadNewer();
      await anchored.loadNewer();
      final reached = dataOf(anchored.state);
      expect(reached.hasNewer, isFalse);
      expect(reached.unseenNewerCount, 0);
      expect(idsOf(reached.items).first, 7);
    });

    test('a new row goes where positionOf puts it, and only inside the loaded '
        'range', () async {
      final h = Harness()..serveRooms();
      h.chat = lines(6);
      await h.start();
      final watch = h.client.watchWindow(const ReadChat());
      await settle();
      expect(idsOf(dataOf(watch.state).items), [6, 5, 4]);
      expect(dataOf(watch.state).hasOlder, isTrue);

      h.server.publish(chatChannel, [
        // A late row between 5 and 4: inside the range, in order.
        const ChatLine(id: 45, at: 45, text: 'late'),
        // Ties with row 5 on the sort value; the larger id is newer.
        const ChatLine(id: 8, at: 50, text: 'tie'),
        // Older than the oldest row shown while older rows exist: the rows
        // between are not loaded, so it waits for loadOlder.
        const ChatLine(id: 11, at: 15, text: 'old'),
      ]);
      await settle();
      var data = dataOf(watch.state);
      expect(idsOf(data.items), [6, 8, 5, 45, 4]);
      expect(data.prependedCount, 0, reason: 'nothing went to the head');
      expect(data.unseenNewerCount, 0);

      // Loaded to the oldest end: below the last row is inside the range.
      h.chat = lines(4);
      await watch.loadOlder();
      await watch.loadOlder();
      expect(dataOf(watch.state).hasOlder, isFalse);
      h.server.publish(chatChannel, [
        const ChatLine(id: 20, at: 0, text: 'first ever'),
      ]);
      await settle();
      data = dataOf(watch.state);
      expect(idsOf(data.items).last, 20);
      expect(data.items.map((line) => line.at), [
        60,
        50,
        50,
        45,
        40,
        30,
        20,
        10,
        0,
      ]);
    });

    test('rows are updated and removed in place; a removed unseen row is '
        'uncounted', () async {
      final h = Harness()..serveRooms();
      h.chat = lines(6);
      await h.start();
      final watch = h.client.watchWindow(
        const ReadChat(),
        anchor: DwWindowCursor.encode(20, 2),
      );
      await settle();
      const line9 = ChatLine(id: 9, at: 90, text: 'nine');
      h.server.publish(chatChannel, [
        const ChatLine(id: 2, at: 20, text: 'edited'),
        DwDeletedObject.of<ChatLine>(1, roomsProtocol),
        line9,
      ]);
      await settle();
      var data = dataOf(watch.state);
      expect(data.items, [
        const ChatLine(id: 3, at: 30, text: 'line 3'),
        const ChatLine(id: 2, at: 20, text: 'edited'),
      ]);
      expect(data.unseenNewerCount, 1);
      h.server.publish(chatChannel, [
        DwDeletedObject.of<ChatLine>(9, roomsProtocol),
      ]);
      await settle();
      data = dataOf(watch.state);
      expect(data.unseenNewerCount, 0);
    });

    test('a reconnect reloads the window where it stands', () async {
      final h = Harness()..serveRooms();
      h.chat = lines(10);
      await h.start();
      final anchor = DwWindowCursor.encode(50, 5);
      final watch = h.client.watchWindow(const ReadChat(), anchor: anchor);
      await settle();
      await watch.loadOlder();
      expect(dataOf(watch.state).items, hasLength(6));
      h.server.calls.clear();

      await h.server.dropConnections();
      await until(() => h.server.calls.isNotEmpty);
      await settle();
      expect(h.server.callsOf<ReadChat>().single.query, {
        'anchor': anchor,
        'pageSize': '6',
      });
      expect(dataOf(watch.state).items, hasLength(6));
    });

    test(
      'windows of one request at different anchors are separate entries',
      () async {
        final h = Harness()..serveRooms();
        h.chat = lines(6);
        await h.start();
        final first = h.client.watchWindow(const ReadChat());
        final again = h.client.watchWindow(const ReadChat());
        final other = h.client.watchWindow(
          const ReadChat(),
          anchor: DwWindowCursor.encode(20, 2),
        );
        await settle();
        expect(h.server.callsOf<ReadChat>(), hasLength(2));
        expect(dataOf(first.state), dataOf(again.state));
        expect(idsOf(dataOf(other.state).items), [3, 2, 1]);
      },
    );

    test('an older load that fails keeps the rows and says why', () async {
      final h = Harness()..serveRooms();
      h.chat = lines(6);
      await h.start();
      final watch = h.client.watchWindow(const ReadChat());
      await settle();
      h.server.onRequest<ReadChat>(
        (request, call) => DwCallRefused<DwWindowResult<ChatLine>>(
          DwCallRefusal(DwCoreRefusal.forbidden),
        ),
      );
      await watch.loadOlder();
      final data = dataOf(watch.state);
      expect(idsOf(data.items), [6, 5, 4]);
      expect(data.loadingOlder, isFalse);
      expect(data.loadError, isA<DwRefusalException>());
    });
  });
}
