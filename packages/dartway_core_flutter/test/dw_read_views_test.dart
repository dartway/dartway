import 'dart:async';
import 'dart:convert';

import 'package:dartway_client/testing.dart';
import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'fixtures/rooms.dart';

const alice = DwAuthSession(id: 7, token: 'token-7', isNewAccount: false);

class _MemoryStore extends DwKeyValueStorePlugin {
  _MemoryStore(this.values);

  final Map<String, Object> values;

  @override
  Future<void> init(DwFlutterToolbox core) async {}

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<void> setInt(String key, int value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  bool get isPersistent => true;
}

/// What the fake server answers `GetRoom` with next.
DwCallResult<RoomView> Function() getRoom = () =>
    const DwCallOk(RoomView(id: 1, name: 'alpha'));

/// While set, `GetRoom` and the pages after the first wait for it.
Completer<void>? gate;

/// Rooms `FeedRooms` pages through, two per page.
List<RoomView> feed = [];

/// What the fake server answers a `FeedRooms` page with instead of [feed],
/// when set; the argument is the page's offset.
DwCallResult<DwPageResult<RoomView>>? Function(int offset)? feedAnswer;

/// What the fake server answers `ReadChat` with next.
DwCallResult<DwWindowResult<ChatLine>> Function(
  ReadChat request,
  DwPageQuery? page,
)?
chatAnswer;

/// What the fake server answers `RoomsTable` with next.
DwCallResult<DwTablePage<RoomView>> Function(RoomsTable request)? tableAnswer;

/// While set, the page at this offset is refused once.
int? failPageAt;

final reports = <DwErrorReport>[];

DwFlutterCore core(DwFakeServer server) => DwFlutterCore(
  config: DwFlutterConfig(
    appVersion: '1.0.0+1',
    refusalText: (refusal) => refusal.code,
    onErrorReport: reports.add,
    readLoadingBuilder: (context) => const Text('loading…'),
    readFailedBuilder: (context, error, retry) => TextButton(
      onPressed: retry,
      child: Text('failed: ${error.runtimeType}'),
    ),
  ),
  protocol: roomsProtocol,
  baseUrl: server.baseUrl,
  httpTransport: server.httpTransport,
  liveConnector: server.liveConnector,
  plugins: [
    _MemoryStore({'dw.session': jsonEncode(alice.toJson())}),
  ],
  clientOptions: dwFakeClientOptions,
);

DwFakeServer fakeServer() => DwFakeServer(protocol: roomsProtocol)
  ..registerToken(alice.token, alice.id)
  ..onRequest<GetRoom>((request, call) async {
    await gate?.future;
    return getRoom();
  })
  ..onRequest<FeedRooms>((request, call) async {
    final page = call.page;
    final offset = page is DwOffsetQuery ? page.offset : 0;
    if (offset > 0) await gate?.future;
    if (feedAnswer?.call(offset) case final answer?) return answer;
    if (offset == failPageAt) {
      failPageAt = null;
      return const DwCallFailed('incident-page');
    }
    return DwCallOk(dwFakeOffsetPage(feed, request, call.page));
  })
  ..onRequest<ReadChat>(
    (request, call) =>
        chatAnswer?.call(request, call.page) ??
        DwCallOk(dwFakeWindow(const <ChatLine>[], request, call.page)),
  )
  ..onRequest<RoomsTable>(
    (request, call) =>
        tableAnswer?.call(request) ??
        DwCallOk(
          dwFakeTablePage(const [RoomView(id: 1, name: 'alpha')], request),
        ),
  );

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

Widget app(Widget child) => ProviderScope(
  child: MaterialApp(home: Material(child: child)),
);

Widget roomView(DwFlutterCore dw, {RoomView? placeholder}) => DwReadBuilder(
  dw.request(const GetRoom(1)),
  placeholder: placeholder,
  onRefused: {
    DwCoreRefusal.notFound: (context, refusal) => const Text('unavailable'),
  },
  builder: (context, room) => Text('room ${room.name}'),
);

void main() {
  late DwFakeServer server;
  late DwFlutterCore dw;

  setUp(() {
    reports.clear();
    gate = null;
    failPageAt = null;
    feedAnswer = null;
    chatAnswer = null;
    tableAnswer = null;
    getRoom = () => const DwCallOk(RoomView(id: 1, name: 'alpha'));
    server = fakeServer();
  });

  /// The core is built inside the test's fake clock, so its timers are too.
  Future<void> start() async {
    dw = core(server);
    await dw.init();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await dw.dispose();
    expect(server.errors, isEmpty);
  }

  group('DwReadBuilder', () {
    testWidgets('loading is the app\'s view, then the data', (tester) async {
      await start();
      gate = Completer<void>();
      await tester.pumpWidget(app(roomView(dw)));
      await tester.pump();
      expect(find.text('loading…'), findsOneWidget);

      gate!.complete();
      await settle(tester);
      expect(find.text('room alpha'), findsOneWidget);
      expect(find.text('loading…'), findsNothing);
      await close(tester);
    });

    testWidgets('a placeholder is drawn through the builder as a skeleton', (
      tester,
    ) async {
      await start();
      gate = Completer<void>();
      await tester.pumpWidget(
        app(roomView(dw, placeholder: const RoomView(id: 0, name: 'stand-in'))),
      );
      await tester.pump();
      expect(find.byType(SkeletonizerScope), findsOneWidget);
      expect(find.text('room stand-in'), findsOneWidget);
      expect(find.text('loading…'), findsNothing);

      gate!.complete();
      await settle(tester);
      expect(find.byType(SkeletonizerScope), findsNothing);
      expect(find.text('room alpha'), findsOneWidget);
      await close(tester);
    });

    testWidgets('a failure is the app\'s failed view, reported once; retry '
        'asks again', (tester) async {
      await start();
      getRoom = () => const DwCallFailed('incident-1');
      await tester.pumpWidget(app(roomView(dw)));
      await settle(tester);
      expect(find.text('failed: DwFailedException'), findsOneWidget);

      // Rebuilds over the same failure do not report it again.
      await tester.pumpWidget(app(roomView(dw)));
      await settle(tester);
      expect(reports, hasLength(1));
      expect(reports.single.source, DwErrorSource.asyncBuild);
      expect(reports.single.failedCall, 'GetRoom');

      getRoom = () => const DwCallOk(RoomView(id: 1, name: 'back'));
      await tester.tap(find.byType(TextButton));
      await settle(tester);
      expect(find.text('room back'), findsOneWidget);
      expect(server.callsOf<GetRoom>(), hasLength(2));
      await close(tester);
    });

    testWidgets('a refusal with a branch shows the branch, and is no '
        'incident', (tester) async {
      await start();
      getRoom = () => DwCallRefused(DwCallRefusal(DwCoreRefusal.notFound));
      await tester.pumpWidget(app(roomView(dw)));
      await settle(tester);
      expect(find.text('unavailable'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(reports, isEmpty);
      await close(tester);
    });

    testWidgets('a refusal without a branch is the failed view, and is no '
        'incident', (tester) async {
      await start();
      getRoom = () => DwCallRefused(DwCallRefusal(DwCoreRefusal.forbidden));
      await tester.pumpWidget(app(roomView(dw)));
      await settle(tester);
      expect(find.text('failed: DwRefusalException'), findsOneWidget);
      expect(find.text('unavailable'), findsNothing);
      expect(reports, isEmpty);
      await close(tester);
    });

    testWidgets('a signed-out read shows nothing', (tester) async {
      await start();
      getRoom = () => const DwNotAuthenticated();
      await tester.pumpWidget(app(roomView(dw)));
      await settle(tester);
      expect(find.byType(Text), findsNothing);
      expect(reports, isEmpty);
      await close(tester);
    });

    testWidgets('renders any read of the data layer: a failed table page '
        'retries by its own refetch', (tester) async {
      await start();
      tableAnswer = (_) => const DwCallFailed('incident-table');
      await tester.pumpWidget(
        app(
          DwReadBuilder(
            dw.table(const RoomsTable()),
            builder: (context, page) => Text('${page.total} in the table'),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('failed: DwFailedException'), findsOneWidget);

      tableAnswer = null;
      await tester.tap(find.byType(TextButton));
      await settle(tester);
      expect(find.text('1 in the table'), findsOneWidget);
      expect(server.callsOf<RoomsTable>(), hasLength(2));
      await close(tester);
    });

    testWidgets('derived: a provider of the app\'s own over a read, with the '
        'retry it names', (tester) async {
      await start();
      getRoom = () => const DwCallFailed('incident-2');
      final roomName = Provider.autoDispose<AsyncValue<String>>(
        (ref) => ref
            .watch(dw.request(const GetRoom(1)))
            .whenData((room) => room.name.toUpperCase()),
      );
      await tester.pumpWidget(
        app(
          DwReadBuilder.derived(
            roomName,
            retry: (ref) =>
                ref.read(dw.request(const GetRoom(1)).notifier).refetch(),
            onRefused: {
              DwCoreRefusal.notFound: (context, _) => const Text('unavailable'),
            },
            builder: (context, name) => Text('name $name'),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('failed: DwFailedException'), findsOneWidget);

      getRoom = () => const DwCallOk(RoomView(id: 1, name: 'alpha'));
      await tester.tap(find.byType(TextButton));
      await settle(tester);
      expect(find.text('name ALPHA'), findsOneWidget);
      await close(tester);
    });
  });

  group('DwWindowListView, first answer', () {
    Widget chat() => app(
      SizedBox(
        height: 400,
        child: DwWindowListView<ChatLine>(
          request: const ReadChat(),
          onRefused: {
            DwCoreRefusal.forbidden: (context, _) => const Text('not yours'),
          },
          emptyBuilder: (context) => const Text('no lines'),
          itemBuilder: (context, row) => Text(row.item.text),
        ),
      ),
    );

    testWidgets('a refusal with a branch shows the branch', (tester) async {
      await start();
      chatAnswer = (_, _) =>
          DwCallRefused(DwCallRefusal(DwCoreRefusal.forbidden));
      await tester.pumpWidget(chat());
      await settle(tester);
      expect(find.text('not yours'), findsOneWidget);
      expect(reports, isEmpty);
      await close(tester);
    });

    testWidgets('a failure is the app\'s failed view, and retry reads the '
        'window again', (tester) async {
      await start();
      chatAnswer = (_, _) => const DwCallFailed('incident-chat');
      await tester.pumpWidget(chat());
      await settle(tester);
      expect(find.text('failed: DwFailedException'), findsOneWidget);
      expect(reports, hasLength(1));

      chatAnswer = null;
      await tester.tap(find.byType(TextButton));
      await settle(tester);
      expect(find.text('no lines'), findsOneWidget);
      await close(tester);
    });
  });

  group('DwPagedListView', () {
    List<RoomView> rooms(int count) => [
      for (var i = 1; i <= count; i++) RoomView(id: i, name: 'r$i', rank: i),
    ];

    Widget list({RoomView? placeholder, double height = 600}) => app(
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: height,
          child: DwPagedListView<RoomView>(
            request: const FeedRooms(),
            placeholder: placeholder,
            header: const Text('header'),
            emptyBuilder: (context) => const Text('nothing yet'),
            itemBuilder: (context, room) => SizedBox(
              key: ValueKey('room-${room.id}'),
              height: 100,
              child: Text(room.name),
            ),
          ),
        ),
      ),
    );

    List<int> offsets() => [
      for (final call in server.callsOf<FeedRooms>())
        int.parse(call.query['offset'] ?? '0'),
    ];

    testWidgets('fills the screen page by page, then stops at the cache '
        'extent', (tester) async {
      await start();
      feed = rooms(40);
      await tester.pumpWidget(list());
      await settle(tester);

      expect(find.text('header'), findsOneWidget);
      expect(find.text('r1'), findsOneWidget);
      // 600 px of rows and the default 250 px cache extent past them: pages
      // of two until the slot after the last row falls out of it.
      final asked = offsets();
      expect(asked.first, 0);
      expect(asked.length, greaterThan(3));
      expect(asked.length, lessThan(10));
      await close(tester);
    });

    testWidgets('loads the next page as the end comes near', (tester) async {
      await start();
      feed = rooms(40);
      await tester.pumpWidget(list());
      await settle(tester);
      final before = offsets().length;

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await settle(tester);
      expect(offsets().length, greaterThan(before));
      await close(tester);
    });

    testWidgets('stops when the server has no more', (tester) async {
      await start();
      feed = rooms(3);
      await tester.pumpWidget(list());
      await settle(tester);
      expect(offsets(), [0, 2]);
      expect(find.text('r3'), findsOneWidget);
      await tester.pumpWidget(list());
      await settle(tester);
      expect(offsets(), [0, 2]);
      await close(tester);
    });

    testWidgets('a failed page shows a retry and does not ask again by '
        'itself', (tester) async {
      await start();
      feed = rooms(40);
      failPageAt = 2;
      await tester.pumpWidget(list(height: 250));
      await settle(tester);
      expect(offsets(), [0, 2]);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.pumpWidget(list(height: 250));
      await settle(tester);
      expect(offsets(), [0, 2]);

      await tester.tap(find.byIcon(Icons.refresh));
      await settle(tester);
      expect(offsets().sublist(0, 3), [0, 2, 2]);
      expect(find.byIcon(Icons.refresh), findsNothing);
      await close(tester);
    });

    testWidgets('a refused first page shows its branch; a failed one retries '
        'by the feed\'s own refetch', (tester) async {
      await start();
      feed = rooms(2);
      feedAnswer = (_) => DwCallRefused(DwCallRefusal(DwCoreRefusal.forbidden));
      await tester.pumpWidget(
        app(
          DwPagedListView<RoomView>(
            request: const FeedRooms(),
            onRefused: {
              DwCoreRefusal.forbidden: (context, _) => const Text('not yours'),
            },
            emptyBuilder: (context) => const Text('nothing yet'),
            itemBuilder: (context, room) => Text(room.name),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('not yours'), findsOneWidget);
      await close(tester);

      await start();
      feedAnswer = (_) => const DwCallFailed('incident-feed');
      await tester.pumpWidget(list());
      await settle(tester);
      expect(find.text('failed: DwFailedException'), findsOneWidget);
      feedAnswer = null;
      await tester.tap(find.byType(TextButton));
      await settle(tester);
      expect(find.text('r1'), findsOneWidget);
      await close(tester);
    });

    testWidgets('a first page with no rows while more follow is not empty: it '
        'loads on', (tester) async {
      await start();
      feed = rooms(2);
      var calls = 0;
      feedAnswer = (_) => calls++ == 0
          ? const DwCallOk(DwPageResult<RoomView>([], hasMore: true))
          : null;
      await tester.pumpWidget(list());
      await settle(tester);
      expect(find.text('nothing yet'), findsNothing);
      expect(find.text('r1'), findsOneWidget);
      expect(calls, greaterThan(1));
      await close(tester);
    });

    testWidgets('as a sliver in the page\'s own scroll view', (tester) async {
      await start();
      feed = rooms(40);
      await tester.pumpWidget(
        app(
          SizedBox(
            height: 600,
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: Text('profile above')),
                DwPagedListView<RoomView>.sliver(
                  request: const FeedRooms(),
                  emptyBuilder: (context) => const Text('nothing yet'),
                  itemBuilder: (context, room) =>
                      SizedBox(height: 100, child: Text(room.name)),
                ),
              ],
            ),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('profile above'), findsOneWidget);
      expect(find.text('r1'), findsOneWidget);
      final asked = offsets().length;
      expect(asked, greaterThan(1));
      expect(asked, lessThan(10));
      await close(tester);
    });

    testWidgets('an empty feed is the empty view', (tester) async {
      await start();
      feed = [];
      await tester.pumpWidget(list());
      await settle(tester);
      expect(find.text('nothing yet'), findsOneWidget);
      expect(find.text('header'), findsOneWidget);
      await close(tester);
    });

    testWidgets('loads as placeholder rows, drawn as a skeleton', (
      tester,
    ) async {
      await start();
      feed = rooms(2);
      gate = Completer<void>();
      // The first page does not wait on the gate; hold it by the server.
      server.onRequest<FeedRooms>((request, call) async {
        await gate?.future;
        return DwCallOk(dwFakeOffsetPage(feed, request, call.page));
      });
      await tester.pumpWidget(
        list(placeholder: const RoomView(id: 0, name: 'stand-in')),
      );
      await tester.pump();
      expect(find.byType(SkeletonizerScope), findsOneWidget);
      expect(find.text('stand-in'), findsNWidgets(3));

      gate!.complete();
      await settle(tester);
      expect(find.text('stand-in'), findsNothing);
      expect(find.text('r1'), findsOneWidget);
      await close(tester);
    });
  });
}
