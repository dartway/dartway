import 'dart:async';

import 'package:dartway_client/dartway_client.dart';
import 'package:dartway_client/testing.dart';
import 'package:test/test.dart';

import 'support.dart';

RoomView room(int id, int rank) => RoomView(id: id, name: 'r$id', rank: rank);

void main() {
  late Harness h;

  /// Ordered by rank for [FeedRooms]; newest (highest id) first for
  /// [RoomHistory].
  late List<RoomView> feed;

  setUp(() async {
    h = Harness();
    feed = [room(1, 10), room(2, 20), room(3, 30), room(4, 40), room(5, 50)];
    h.server
      ..onRequest<FeedRooms>(
        (r, call) => DwOk(dwFakePage(feed, call.page, pageSize: r.pageSize)),
      )
      ..onRequest<RoomHistory>(
        (r, call) => DwOk(
          dwFakePage(
            feed.toList()..sort((x, y) => y.id.compareTo(x.id)),
            call.page,
            pageSize: r.pageSize,
          ),
        ),
      );
    await h.start();
  });

  List<DwPageParams?> pagesAsked<Q extends DwRequest<Object?>>() => [
    for (final m in h.server.receivedOf<DwRequestMessage>())
      if (m.request is Q) m.page,
  ];

  group('offset pages', () {
    test(
      'load the first page, then more by the loaded count, until none',
      () async {
        final watch = h.client.watchPages(const FeedRooms());
        await settle();
        expect(itemsOf(watch.state), [room(1, 10), room(2, 20)]);
        expect(watch.hasMore, isTrue);

        await watch.loadMore();
        await settle();
        expect(itemsOf(watch.state).map((r) => r.id), [1, 2, 3, 4]);

        await watch.loadMore();
        await settle();
        expect(itemsOf(watch.state).map((r) => r.id), [1, 2, 3, 4, 5]);
        expect(watch.hasMore, isFalse);

        await watch.loadMore();
        await settle();
        expect(
          pagesAsked<FeedRooms>().map((p) => (p! as DwOffsetParams).offset),
          [0, 2, 4],
          reason: 'no request once there is no more',
        );
      },
    );

    test('loadMore is idempotent while in flight', () async {
      final watch = h.client.watchPages(const FeedRooms());
      await settle();
      final hold = Completer<void>();
      h.server.onRequest<FeedRooms>((r, call) async {
        await hold.future;
        return DwOk(dwFakePage(feed, call.page, pageSize: r.pageSize));
      });
      final loads = [watch.loadMore(), watch.loadMore(), watch.loadMore()];
      await settle();
      expect(dataOf(watch.state).loadingMore, isTrue);
      hold.complete();
      await Future.wait(loads);
      await settle();
      expect(pagesAsked<FeedRooms>(), hasLength(2));
      expect(dataOf(watch.state).loadingMore, isFalse);
    });

    test('a failed next page keeps the loaded items and says why', () async {
      final watch = h.client.watchPages(const FeedRooms());
      await settle();
      h.server.onRequest<FeedRooms>(
        (r, call) => const DwFailed<DwPage<RoomView>>('incident-3'),
      );
      await watch.loadMore();
      await settle();
      final data = dataOf(watch.state);
      expect(data.items, hasLength(2));
      expect(
        data.loadMoreError,
        const DwFailedException('incident-3', call: 'FeedRooms'),
      );
      expect(data.hasMore, isTrue);
    });

    test(
      'updates: replace in place, insert by sort, drop past the loaded pages, remove',
      () async {
        final watch = h.client.watchPages(const FeedRooms());
        await settle();
        await watch.loadMore();
        await settle();
        expect(itemsOf(watch.state).map((r) => r.id), [1, 2, 3, 4]);

        h.server.publish(rooms, [
          room(3, 1), // re-ranked: stays in place
          room(6, 15), // sorts inside the loaded window: inserted
          room(7, 99), // sorts past it while more exist: arrives on scroll
          DwDeleted.of<RoomView>(1, roomsProtocol),
        ]);
        await settle();
        expect(itemsOf(watch.state).map((r) => r.id), [6, 2, 3, 4]);
      },
    );

    test(
      'an object shifted into the next page by an insert is not shown twice',
      () async {
        final watch = h.client.watchPages(const FeedRooms());
        await settle();
        // Inserted on the server and published: the server's offsets shift.
        final inserted = room(6, 15);
        feed = [
          room(1, 10),
          inserted,
          room(2, 20),
          room(3, 30),
          room(4, 40),
          room(5, 50),
        ];
        h.server.publish(rooms, [inserted]);
        await settle();
        expect(itemsOf(watch.state).map((r) => r.id), [1, 6, 2]);
        await watch.loadMore();
        await settle();
        expect(itemsOf(watch.state).map((r) => r.id), [1, 6, 2, 3, 4]);
      },
    );

    test('without sort a new object goes to the head', () async {
      final watch = h.client.watchPages(const FeedRooms(sorted: false));
      await settle();
      h.server.publish(rooms, [room(9, 99)]);
      await settle();
      expect(itemsOf(watch.state).map((r) => r.id), [9, 1, 2]);
    });

    test(
      'reconnect re-runs from the first page up to the loaded count',
      () async {
        final watch = h.client.watchPages(const FeedRooms());
        await settle();
        await watch.loadMore();
        await settle();
        h.server.received.clear();

        feed = [
          room(1, 10),
          room(2, 21),
          room(3, 30),
          room(4, 40),
          room(5, 50),
        ];
        await h.server.dropConnections();
        await until(() => watch.isLive && itemsOf(watch.state)[1].rank == 21);

        expect(
          pagesAsked<FeedRooms>().map((p) => (p! as DwOffsetParams).offset),
          [0, 2],
        );
        expect(itemsOf(watch.state).map((r) => r.id), [1, 2, 3, 4]);
        expect(watch.hasMore, isTrue);
      },
    );

    test(
      'reconnect during loadMore abandons it and reloads from the top',
      () async {
        final watch = h.client.watchPages(const FeedRooms());
        await settle();
        var first = true;
        h.server.onRequest<FeedRooms>((r, call) {
          if (first &&
              call.page is DwOffsetParams &&
              (call.page! as DwOffsetParams).offset == 2) {
            first = false;
            return Completer<DwResult<Object?>>().future;
          }
          return DwOk(dwFakePage(feed, call.page, pageSize: r.pageSize));
        });
        final more = watch.loadMore();
        await settle();
        h.server.received.clear();
        await h.server.dropConnections();
        await more;
        await until(() => watch.isLive);
        await settle();
        expect(
          pagesAsked<FeedRooms>()
              .map((p) => (p! as DwOffsetParams).offset)
              .first,
          0,
        );
        expect(dataOf(watch.state).loadingMore, isFalse);
        expect(itemsOf(watch.state).map((r) => r.id), [1, 2]);
      },
    );

    test('two watchers share one entry and one subscription', () async {
      final one = h.client.watchPages(const FeedRooms());
      final two = h.client.watchPages(const FeedRooms());
      await settle();
      expect(pagesAsked<FeedRooms>(), hasLength(1));
      expect(h.server.subscribeCount(rooms), 1);
      await one.loadMore();
      await settle();
      expect(itemsOf(two.state), hasLength(4));
      one.close();
      two.close();
      await settle();
      expect(h.server.unsubscribeCount(rooms), 1);
    });
  });

  group('cursor pages', () {
    test(
      'load newest first, then older by the id of the oldest loaded',
      () async {
        final watch = h.client.watchPages(const RoomHistory());
        await settle();
        expect(itemsOf(watch.state).map((r) => r.id), [5, 4]);
        await watch.loadMore();
        await settle();
        await watch.loadMore();
        await settle();
        expect(itemsOf(watch.state).map((r) => r.id), [5, 4, 3, 2, 1]);
        expect(watch.hasMore, isFalse);
        expect(
          pagesAsked<RoomHistory>().map((p) => (p! as DwCursorParams).before),
          [null, 4, 2],
        );
      },
    );

    test(
      'updates: replace in place, new objects at the head, deletions removed',
      () async {
        final watch = h.client.watchPages(const RoomHistory());
        await settle();
        h.server.publish(rooms, [
          const RoomView(id: 4, name: 'edited', rank: 40),
          room(6, 60),
          DwDeleted.of<RoomView>(5, roomsProtocol),
        ]);
        await settle();
        expect(itemsOf(watch.state).map((r) => r.id), [6, 4]);
        expect(itemsOf(watch.state)[1].name, 'edited');
      },
    );
  });

  test('watchPages refuses a request that is not paginated', () {
    expect(() => h.client.watchPages(const _PageShaped()), throwsArgumentError);
  });
}

/// Answers pages without being a page kind.
final class _PageShaped extends DwRequest<DwPage<RoomView>> {
  const _PageShaped();

  @override
  String get dwTypeName => 'FeedRooms';

  @override
  Map<String, Object?> toJson() => const {};

  @override
  Object? encodeResult(DwPage<RoomView> result, DwProtocol protocol) => null;

  @override
  DwPage<RoomView> decodeResult(Object? json, DwProtocol protocol) =>
      const DwPage([], hasMore: false);
}
