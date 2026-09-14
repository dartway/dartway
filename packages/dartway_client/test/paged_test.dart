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

    test('rows are updated in place; nothing is inserted', () async {
      final h = Harness()..serveRooms();
      await h.start();
      final table = h.client.watchTable(const RoomsTable());
      await settle();
      const renamed = RoomView(id: 2, name: 'b2', rank: 20);
      h.server.publish(roomsChannel, [c, renamed]);
      await settle();
      expect(dataOf(table.state).items, [a, renamed]);
      expect(dataOf(table.state), isA<DwTablePage<RoomView>>());
      expect(h.server.requestsOf<RoomsTable>(), hasLength(1));
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
