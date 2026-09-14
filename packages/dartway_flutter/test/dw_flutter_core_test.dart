import 'dart:convert';

import 'package:dartway_client/testing.dart';
import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_flutter/src/bootstrap/widgets/dw_app_bootstrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/rooms.dart';

const a = RoomView(id: 1, name: 'alpha', rank: 10);
const b = RoomView(id: 2, name: 'beta', rank: 20);
const c = RoomView(id: 3, name: 'gamma', rank: 30);
const alice = DwAuthSession(id: 7, token: 'token-7', isNewAccount: false);
const bob = DwAuthSession(id: 8, token: 'token-8', isNewAccount: false);

/// A key-value store plugin in memory, standing in for shared preferences.
class _MemoryStore extends DwKeyValueStorePlugin {
  _MemoryStore([Map<String, Object>? values]) : values = values ?? {};

  final Map<String, Object> values;

  @override
  Future<void> init(DwFlutter core) async {}

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

_MemoryStore signedIn(DwAuthSession session) =>
    _MemoryStore({'dw.session': jsonEncode(session.toJson())});

class _CapturingHandler implements DwNotificationHandler<DwUiNotification> {
  final shown = <DwUiNotification>[];

  @override
  void show(BuildContext context, DwUiNotification event) => shown.add(event);
}

final reports = <DwErrorReport>[];

/// A fake server with rooms, notes, a chat, and the commands over them.
final class World {
  World() {
    server
      ..registerToken(alice.token, alice.id)
      ..registerToken(bob.token, bob.id)
      ..onRequest<ListRooms>((r, call) => DwCallOk(rooms.toList()))
      ..onRequest<ListMyNotes>((r, call) {
        final account = call.accountId;
        if (account == null) return const DwNotAuthenticated<List<NoteView>>();
        return DwCallOk(notes[account]?.toList() ?? <NoteView>[]);
      })
      ..onRequest<FeedRooms>(
        (r, call) => DwCallOk(dwFakeOffsetPage(rooms, r, call.page)),
      )
      ..onRequest<RoomsTable>((r, call) => DwCallOk(dwFakeTablePage(rooms, r)))
      ..onRequest<ReadChat>(
        (r, call) => DwCallOk(
          dwFakeWindow(chat, r, call.page, sortValue: (line) => line.at),
        ),
      )
      ..onCommand<RenameRoom>((command, call) {
        final renamed = RoomView(id: command.roomId, name: command.name);
        rooms = [for (final r in rooms) r.id == renamed.id ? renamed : r];
        call.publish(roomsChannel, [renamed]);
        return DwCallOk(renamed);
      });
  }

  final server = DwFakeServer(protocol: roomsProtocol);
  List<RoomView> rooms = [a, b];
  Map<int, List<NoteView>> notes = {};
  List<ChatLine> chat = [];

  DwFlutterCore core({
    _MemoryStore? store,
    String appVersion = '1.0.0+5',
    Widget Function(BuildContext, DwCallRefusal)? updateRequiredScreen,
  }) => DwFlutterCore(
    config: DwConfig(
      appVersion: appVersion,
      onErrorReport: reports.add,
      refusalText: (refusal) => refusal.isCode(RoomRefusal.nameTaken)
          ? 'The name ${refusal.params['name']} is taken'
          : 'Refused (${refusal.code})',
      updateRequiredScreen: updateRequiredScreen,
    ),
    protocol: roomsProtocol,
    baseUrl: server.baseUrl,
    httpTransport: server.httpTransport,
    liveConnector: server.liveConnector,
    plugins: [store ?? signedIn(alice)],
    clientOptions: dwFakeClientOptions,
  );
}

/// Pumps frames until the in-memory traffic and Riverpod have settled.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

Widget app(Widget child, {Key? key}) => ProviderScope(
  key: key,
  child: MaterialApp(home: Material(child: child)),
);

class RoomsScreen extends ConsumerWidget {
  const RoomsScreen(this.dw, {super.key});

  final DwFlutterCore dw;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(dw.request(const ListRooms()));
    return Column(
      children: [
        ...switch (rooms) {
          AsyncData(:final value) => [
            for (final room in value) Text(room.name),
          ],
          AsyncError(:final error) => [Text('error: $error')],
          _ => [const Text('loading')],
        },
      ],
    );
  }
}

void main() {
  setUp(reports.clear);

  testWidgets('a live list follows the response transport and the socket; '
      'leaving it unsubscribes', (tester) async {
    final world = World();
    final dw = world.core();
    await dw.init();

    await tester.pumpWidget(
      app(
        Column(
          children: [
            RoomsScreen(dw),
            DwActionBuilder(
              action: dw.action<DwCallResult<RoomView>>(
                (context) =>
                    dw.command(const RenameRoom(roomId: 1, name: 'alpha 2')),
              ),
              builder: (context, onPressed, busy) =>
                  TextButton(onPressed: onPressed, child: const Text('rename')),
            ),
          ],
        ),
      ),
    );
    expect(find.text('loading'), findsOneWidget);
    await settle(tester);
    expect(find.text('alpha'), findsOneWidget);

    // The author's own change: in the command's response, before it completes.
    await tester.tap(find.text('rename'));
    await settle(tester);
    expect(find.text('alpha 2'), findsOneWidget);

    // Someone else's: over the socket.
    world.server.publish(roomsChannel, [
      c,
      DwDeletedObject.of<RoomView>(2, roomsProtocol),
    ]);
    await settle(tester);
    expect(find.text('gamma'), findsOneWidget);
    expect(find.text('beta'), findsNothing);
    expect(
      world.server.requestsOf<ListRooms>(),
      hasLength(1),
      reason: 'live, never refetched',
    );

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    expect(world.server.subscriberCount(roomsChannel), 0);
    expect(world.server.unsubscribeCount(roomsChannel), 1);
    await dw.dispose();
    expect(world.server.errors, isEmpty);
  });

  testWidgets('two widgets watching one request share one fetch and one '
      'subscription; liveStatus says connected', (tester) async {
    final world = World();
    final dw = world.core();
    await dw.init();
    DwConnectionStatus? status;

    await tester.pumpWidget(
      app(
        Column(
          children: [
            Expanded(child: RoomsScreen(dw)),
            Expanded(child: RoomsScreen(dw)),
            Consumer(
              builder: (context, ref, _) {
                status = ref.watch(dw.liveStatus);
                return const SizedBox();
              },
            ),
          ],
        ),
      ),
    );
    await settle(tester);
    expect(find.text('alpha'), findsNWidgets(2));
    expect(world.server.requestsOf<ListRooms>(), hasLength(1));
    expect(world.server.subscribeCount(roomsChannel), 1);
    expect(status, DwConnectionStatus.connected);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await dw.dispose();
  });

  testWidgets('a window loads older and newer rows and counts unseen ones', (
    tester,
  ) async {
    final world = World()
      ..chat = [
        for (var i = 9; i >= 1; i--) ChatLine(id: i, at: i, text: 'line $i'),
      ];
    final dw = world.core();
    await dw.init();
    final provider = dw.window(
      const ReadChat(),
      anchor: DwWindowCursor.encode(3, 3),
    );
    late WidgetRef widgetRef;

    await tester.pumpWidget(
      app(
        Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            final window = ref.watch(provider);
            return switch (window) {
              AsyncData(:final value) => Column(
                children: [
                  Text('unseen ${value.unseenNewerCount}'),
                  Text('prepended ${value.prependedCount}'),
                  for (final line in value.items) Text(line.text),
                ],
              ),
              _ => const Text('loading'),
            };
          },
        ),
      ),
    );
    await settle(tester);
    expect(find.text('line 4'), findsOneWidget);
    expect(find.text('line 2'), findsOneWidget);
    expect(find.text('line 1'), findsNothing);

    widgetRef.read(provider.notifier).loadOlder();
    await settle(tester);
    expect(find.text('line 1'), findsOneWidget);

    const line10 = ChatLine(id: 10, at: 10, text: 'line 10');
    world.chat = [line10, ...world.chat];
    world.server.publish(chatChannel, [line10]);
    await settle(tester);
    expect(find.text('unseen 1'), findsOneWidget);
    expect(find.text('line 10'), findsNothing);

    widgetRef.read(provider.notifier).loadNewer();
    await settle(tester);
    expect(find.text('prepended 3'), findsOneWidget);
    expect(find.text('line 7'), findsOneWidget);
    widgetRef.read(provider.notifier).loadNewer();
    await settle(tester);
    expect(find.text('line 10'), findsOneWidget);
    expect(find.text('unseen 0'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await dw.dispose();
    expect(world.server.errors, isEmpty);
  });

  testWidgets('a table pages by watching another page request', (tester) async {
    final world = World()..rooms = [a, b, c];
    final dw = world.core();
    await dw.init();

    await tester.pumpWidget(app(_TableScreen(dw)));
    await settle(tester);
    expect(find.text('page 1 of 2, 3 rows'), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('gamma'), findsNothing);

    await tester.tap(find.text('next'));
    await settle(tester);
    expect(find.text('page 2 of 2, 3 rows'), findsOneWidget);
    expect(find.text('gamma'), findsOneWidget);
    expect(find.text('alpha'), findsNothing);

    world.server.publish(roomsChannel, [
      const RoomView(id: 3, name: 'gamma 2'),
    ]);
    await settle(tester);
    expect(find.text('gamma 2'), findsOneWidget);
    expect(world.server.requestsOf<RoomsTable>(), hasLength(2));

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await dw.dispose();
  });

  testWidgets('pages load more through the notifier', (tester) async {
    final world = World()..rooms = [a, b, c];
    final dw = world.core();
    await dw.init();

    await tester.pumpWidget(
      app(
        Consumer(
          builder: (context, ref, _) {
            final pages = ref.watch(dw.pages(const FeedRooms()));
            return Column(
              children: [
                if (pages case AsyncData(:final value)) ...[
                  for (final room in value.items) Text(room.name),
                  if (value.hasMore)
                    TextButton(
                      onPressed: () => ref
                          .read(dw.pages(const FeedRooms()).notifier)
                          .loadMore(),
                      child: const Text('more'),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
    await settle(tester);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('gamma'), findsNothing);
    await tester.tap(find.text('more'));
    await settle(tester);
    expect(find.text('gamma'), findsOneWidget);
    expect(find.text('more'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await dw.dispose();
  });

  testWidgets('a refused command shows the catalogue text through dw.action', (
    tester,
  ) async {
    final world = World();
    world.server.onCommand<RenameRoom>(
      (command, call) => DwCallRefused<RoomView>(
        DwCallRefusal(RoomRefusal.nameTaken, params: {'name': command.name}),
      ),
    );
    final dw = world.core();
    await dw.init();
    final notifications = _CapturingHandler();
    DwCallResult<RoomView>? outcome;

    await tester.pumpWidget(
      app(
        DwNotificationsListener(
          handlers: {DwUiNotification: notifications},
          child: Column(
            children: [
              DwActionBuilder(
                action: dw.action<DwCallResult<RoomView>>(
                  (context) =>
                      dw.command(const RenameRoom(roomId: 1, name: 'lobby')),
                  onSuccessNotification: 'Renamed',
                  followUpIfMountedAction: (context, value) => outcome = value,
                ),
                builder: (context, onPressed, busy) => TextButton(
                  onPressed: onPressed,
                  child: const Text('rename'),
                ),
              ),
              DwActionBuilder(
                action: dw.action<DwCallResult<RoomView>>(
                  (context) =>
                      dw.command(const RenameRoom(roomId: 1, name: '')),
                ),
                builder: (context, onPressed, busy) => TextButton(
                  onPressed: onPressed,
                  child: const Text('rename to nothing'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('rename'));
    await settle(tester);
    expect(notifications.shown.single.message, 'The name lobby is taken');
    expect(notifications.shown.single.type, DwUiNotificationType.error);
    expect(outcome, isNull, reason: 'no follow-up for a refusal');
    expect(reports.single.error, isA<DwRefusalException>());

    await tester.tap(find.text('rename to nothing'));
    await settle(tester);
    expect(notifications.shown.last.message, 'Refused (dw.invalid)');
    expect(
      world.server.callsOf<RenameRoom>(),
      hasLength(1),
      reason: 'the invalid one never left the app',
    );

    await tester.pumpWidget(const SizedBox());
    await dw.dispose();
  });

  testWidgets('a build the server no longer supports gets the update-required '
      'screen over the app', (tester) async {
    final world = World();
    world.server.minAppBuild = 6;
    final dw = world.core(
      appVersion: '1.0.0+5',
      updateRequiredScreen: (context, refusal) => Directionality(
        textDirection: TextDirection.ltr,
        child: Text('Please update (${refusal.code})'),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: DwAppBootstrapper(
          appInitializers: [dw.init],
          useNativeSplash: false,
          onError: (_, _) {},
          errorScreenBuilder: DwAppLoadingOptions.defaultErrorScreen,
          loadingScreen: const SizedBox.shrink(),
          child: MaterialApp(home: Material(child: RoomsScreen(dw))),
        ),
      ),
    );
    await settle(tester);
    // Whichever notices first — the refused live upgrade or the call that
    // stops waiting for it — the answer is the same.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);

    expect(find.text('Please update (dw.updateRequired)'), findsOneWidget);
    expect(find.byType(RoomsScreen), findsNothing);
    expect(dw.client.connectionStatus, DwConnectionStatus.incompatible);
    final calls = world.server.calls.length;
    expect(
      await dw.command(const RenameRoom(roomId: 1, name: 'x')),
      isA<DwCallRefused<RoomView>>(),
    );
    expect(world.server.calls, hasLength(calls), reason: 'failed fast');

    await tester.pumpWidget(const SizedBox());
    await dw.dispose();
  });

  testWidgets("switching accounts never shows the previous account's data", (
    tester,
  ) async {
    final world = World()
      ..notes = {
        7: [const NoteView(id: 1, text: 'alice note')],
        8: [const NoteView(id: 2, text: 'bob note')],
      };
    final dw = world.core();
    await dw.init();
    final frames = <(int?, List<String>)>[];

    await tester.pumpWidget(
      app(
        Consumer(
          builder: (context, ref, _) {
            final account = ref.watch(dw.accountId);
            final notes = ref.watch(dw.request(const ListMyNotes()));
            final texts = switch (notes) {
              AsyncData(:final value) => [for (final n in value) n.text],
              _ => const <String>[],
            };
            frames.add((account, texts));
            return Column(children: [for (final t in texts) Text(t)]);
          },
        ),
      ),
    );
    await settle(tester);
    expect(find.text('alice note'), findsOneWidget);

    await dw.signIn(bob);
    await settle(tester);
    expect(find.text('bob note'), findsOneWidget);
    expect(find.text('alice note'), findsNothing);
    expect(
      frames.where((f) => f.$1 == bob.id && f.$2.contains('alice note')),
      isEmpty,
      reason: "no frame rendered alice's notes as bob",
    );
    expect(world.server.callsOf<ListMyNotes>().map((c) => c.authorization), [
      'Bearer token-7',
      'Bearer token-8',
    ]);

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await dw.dispose();
  });

  testWidgets('a not-authenticated answer in dw.action signs out quietly', (
    tester,
  ) async {
    final world = World();
    world.server.onCommand<RenameRoom>(
      (command, call) => const DwNotAuthenticated<RoomView>(),
    );
    final store = signedIn(alice);
    final dw = world.core(store: store);
    await dw.init();
    final notifications = _CapturingHandler();

    await tester.pumpWidget(
      app(
        DwNotificationsListener(
          handlers: {DwUiNotification: notifications},
          child: DwActionBuilder(
            action: dw.action<DwCallResult<RoomView>>(
              (context) => dw.command(const RenameRoom(roomId: 1, name: 'x')),
              onErrorNotification: 'Could not rename',
            ),
            builder: (context, onPressed, busy) =>
                TextButton(onPressed: onPressed, child: const Text('rename')),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(dw.client.accountId, alice.id);

    await tester.tap(find.text('rename'));
    await settle(tester);
    expect(dw.client.accountId, isNull);
    expect(store.values, isEmpty);
    expect(
      notifications.shown,
      isEmpty,
      reason: 'the sign-in screen is the message',
    );
    expect(reports.single.error, isA<DwNotAuthenticatedException>());

    await tester.pumpWidget(const SizedBox());
    await dw.dispose();
  });

  testWidgets('a sign-in survives a restart through the key-value store role', (
    tester,
  ) async {
    final world = World();
    final store = _MemoryStore();

    final first = world.core(store: store);
    await first.init();
    expect(first.client.accountId, isNull);
    await first.signIn(alice);
    await first.dispose();

    final second = world.core(store: store);
    await second.init();
    expect(second.client.accountId, alice.id);
    await second.dispose();
  });

  testWidgets('dw is built, disposed and built again in one process', (
    tester,
  ) async {
    final world = World();
    for (var round = 0; round < 3; round++) {
      final dw = world.core();
      expect(
        () => world.core(),
        throwsStateError,
        reason: 'one live core at a time',
      );
      await dw.init();
      await tester.pumpWidget(app(RoomsScreen(dw), key: ValueKey(round)));
      await settle(tester);
      expect(find.text('alpha'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
      await dw.dispose();
    }
    expect(world.server.connections, hasLength(3));
    expect(world.server.openConnections, isEmpty);
    expect(world.server.errors, isEmpty);
  });

  test('a config that cannot render refusals or name its build is refused, '
      'claiming nothing', () async {
    final world = World();
    expect(
      () => DwFlutterCore(
        config: const DwConfig(appVersion: '1.0.0+1'),
        protocol: roomsProtocol,
        baseUrl: world.server.baseUrl,
      ),
      throwsArgumentError,
    );
    expect(
      () => DwFlutterCore(
        config: DwConfig(refusalText: (refusal) => refusal.code),
        protocol: roomsProtocol,
        baseUrl: world.server.baseUrl,
      ),
      throwsArgumentError,
    );
    expect(
      () => DwFlutterCore(
        config: DwConfig(
          appVersion: 'one',
          refusalText: (refusal) => refusal.code,
        ),
        protocol: roomsProtocol,
        baseUrl: world.server.baseUrl,
      ),
      throwsFormatException,
    );
    final dw = world.core();
    await dw.dispose();
  });

  test('without a key-value store plugin init fails, naming the fix', () async {
    final world = World();
    final dw = DwFlutterCore(
      config: DwConfig(
        appVersion: '1.0.0+1',
        refusalText: (refusal) => refusal.code,
      ),
      protocol: roomsProtocol,
      baseUrl: world.server.baseUrl,
      httpTransport: world.server.httpTransport,
      liveConnector: world.server.liveConnector,
    );
    await expectLater(
      dw.init(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('DwKeyValueStorePlugin'),
        ),
      ),
    );
    await dw.dispose();
  });
}

class _TableScreen extends ConsumerStatefulWidget {
  const _TableScreen(this.dw);

  final DwFlutterCore dw;

  @override
  ConsumerState<_TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends ConsumerState<_TableScreen> {
  int page = 1;

  @override
  Widget build(BuildContext context) {
    final table = ref.watch(widget.dw.table(RoomsTable(page: page)));
    return switch (table) {
      AsyncData(:final value) => Column(
        children: [
          Text('page ${value.page} of ${value.pageCount}, ${value.total} rows'),
          for (final room in value.items) Text(room.name),
          TextButton(
            onPressed: () => setState(() => page++),
            child: const Text('next'),
          ),
        ],
      ),
      _ => const Text('loading'),
    };
  }
}
