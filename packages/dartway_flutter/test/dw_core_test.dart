import 'dart:convert';

import 'package:dartway_client/testing.dart';
import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/rooms.dart';

const a = RoomView(id: 1, name: 'alpha');
const b = RoomView(id: 2, name: 'beta');
const c = RoomView(id: 3, name: 'gamma');
const session = DwSession(id: 42, token: 'token-42', isNewAccount: false);

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

class _CapturingHandler implements DwNotificationHandler<DwUiNotification> {
  final shown = <DwUiNotification>[];

  @override
  void show(BuildContext context, DwUiNotification event) => shown.add(event);
}

final reports = <DwErrorReport>[];

DwCore buildCore(DwFakeServer server, {_MemoryStore? store}) => DwCore(
  config: DwConfig(
    onErrorReport: reports.add,
    refusalText: (refusal) => refusal.isCode(RoomRefusal.nameTaken)
        ? 'The name ${refusal.params['name']} is taken'
        : 'Refused (${refusal.code})',
  ),
  protocol: roomsProtocol,
  endpoint: server.endpoint,
  connector: server.connector,
  plugins: [store ?? _MemoryStore()],
  clientOptions: const DwClientOptions(
    releaseDelay: Duration.zero,
    reconnectDelay: Duration(milliseconds: 1),
  ),
);

/// Pumps frames until the in-memory traffic and Riverpod have settled.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

class RoomsScreen extends ConsumerWidget {
  const RoomsScreen(this.dw, {super.key});

  final DwCore dw;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(dw.accountId);
    final rooms = ref.watch(dw.request(const ListRooms()));
    return Column(
      children: [
        Text(account == null ? 'signed out' : 'account $account'),
        ...switch (rooms) {
          AsyncData(:final value) => [
            for (final room in value) Text(room.name),
          ],
          AsyncError(error: DwNotAuthenticatedException()) => [
            const Text('sign in to see rooms'),
          ],
          AsyncError(:final error) => [Text('error: $error')],
          _ => [const Text('loading')],
        },
      ],
    );
  }
}

Widget app(Widget child, {Key? key}) => ProviderScope(
  key: key,
  child: MaterialApp(home: Material(child: child)),
);

void main() {
  setUp(reports.clear);

  testWidgets('a list screen loads and updates live; leaving it unsubscribes', (
    tester,
  ) async {
    final server = DwFakeServer(protocol: roomsProtocol);
    var rooms = [a, b];
    server.onRequest<ListRooms>((request, call) => DwOk(rooms));
    final dw = buildCore(server);
    await dw.init();

    await tester.pumpWidget(app(RoomsScreen(dw)));
    expect(find.text('loading'), findsOneWidget);
    await settle(tester);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);

    rooms = [c, a, b];
    server.publish(roomsChannel, [c]);
    await settle(tester);
    expect(find.text('gamma'), findsOneWidget);

    server.publish(roomsChannel, [
      const RoomView(id: 1, name: 'alpha 2'),
      DwDeleted.of<RoomView>(2, roomsProtocol),
    ]);
    await settle(tester);
    expect(find.text('alpha 2'), findsOneWidget);
    expect(find.text('beta'), findsNothing);
    expect(
      server.requestsOf<ListRooms>(),
      hasLength(1),
      reason: 'live, not refetched',
    );

    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    expect(server.subscriberCount(roomsChannel), 0);
    expect(server.unsubscribeCount(roomsChannel), 1);

    await dw.dispose();
    expect(server.errors, isEmpty);
  });

  testWidgets(
    'two widgets watching one request share one fetch and one subscription',
    (tester) async {
      final server = DwFakeServer(protocol: roomsProtocol)
        ..onRequest<ListRooms>((request, call) => const DwOk([a]));
      final dw = buildCore(server);
      await dw.init();

      await tester.pumpWidget(
        app(
          Row(
            children: [
              Expanded(child: RoomsScreen(dw)),
              Expanded(child: RoomsScreen(dw)),
            ],
          ),
        ),
      );
      await settle(tester);
      expect(find.text('alpha'), findsNWidgets(2));
      expect(server.requestsOf<ListRooms>(), hasLength(1));
      expect(server.subscribeCount(roomsChannel), 1);

      await tester.pumpWidget(const SizedBox());
      await settle(tester);
      await dw.dispose();
    },
  );

  testWidgets('a refused command shows the catalogue text through dw.action', (
    tester,
  ) async {
    final server = DwFakeServer(protocol: roomsProtocol)
      ..onCommand<RenameRoom>(
        (command, call) => DwRefused<RoomView>(
          DwRefusal(RoomRefusal.nameTaken, params: {'name': command.name}),
        ),
      );
    final dw = buildCore(server);
    await dw.init();
    final notifications = _CapturingHandler();
    DwResult<RoomView>? outcome;

    await tester.pumpWidget(
      app(
        DwNotificationsListener(
          handlers: {DwUiNotification: notifications},
          child: DwActionBuilder(
            action: dw.action<DwResult<RoomView>>(
              (context) =>
                  dw.command(const RenameRoom(roomId: 1, name: 'lobby')),
              onSuccessNotification: 'Renamed',
              followUpIfMountedAction: (context, value) => outcome = value,
            ),
            builder: (context, onPressed, busy) =>
                TextButton(onPressed: onPressed, child: const Text('rename')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('rename'));
    await settle(tester);

    expect(notifications.shown.single.message, 'The name lobby is taken');
    expect(notifications.shown.single.type, DwUiNotificationType.error);
    expect(outcome, isNull, reason: 'no follow-up for a refusal');
    // The app's error policy still sees it, typed.
    expect(reports.single.error, isA<DwRefusalException>());

    await tester.pumpWidget(const SizedBox());
    await dw.dispose();
  });

  testWidgets('a not-authenticated answer in dw.action signs out quietly', (
    tester,
  ) async {
    final server = DwFakeServer(protocol: roomsProtocol)
      ..registerToken(session.token, session.id)
      ..onCommand<RenameRoom>(
        (command, call) => const DwNotAuthenticated<RoomView>(),
      );
    final store = _MemoryStore({'dw.session': jsonEncode(session.toJson())});
    final dw = buildCore(server, store: store);
    await dw.init();
    final notifications = _CapturingHandler();

    await tester.pumpWidget(
      app(
        DwNotificationsListener(
          handlers: {DwUiNotification: notifications},
          child: DwActionBuilder(
            action: dw.action<DwResult<RoomView>>(
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
    expect(dw.client.accountId, 42);

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

  testWidgets('sign-out clears the session, its storage and its data', (
    tester,
  ) async {
    final server = DwFakeServer(protocol: roomsProtocol)
      ..registerToken(session.token, session.id)
      ..onRequest<ListRooms>(
        (request, call) => call.accountId == null
            ? const DwNotAuthenticated<List<RoomView>>()
            : const DwOk([a, b]),
      );
    final store = _MemoryStore({'dw.session': jsonEncode(session.toJson())});
    final dw = buildCore(server, store: store);
    await dw.init();

    await tester.pumpWidget(app(RoomsScreen(dw)));
    await settle(tester);
    expect(find.text('account 42'), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);
    dw.handleError(StateError('while signed in'), StackTrace.empty);
    expect(reports.single.context.entries['account'], '42');

    await dw.signOut();
    await settle(tester);

    expect(find.text('signed out'), findsOneWidget);
    expect(find.text('alpha'), findsNothing);
    expect(find.text('sign in to see rooms'), findsOneWidget);
    expect(store.values, isEmpty);
    expect(server.isTokenValid(session.token), isFalse);

    await tester.pumpWidget(const SizedBox());
    await dw.dispose();
  });

  testWidgets('a sign-in survives a restart through the key-value store role', (
    tester,
  ) async {
    final server = DwFakeServer(protocol: roomsProtocol)
      ..registerToken(session.token, session.id)
      ..onRequest<ListRooms>((request, call) => const DwOk([a]));
    final store = _MemoryStore();

    final first = buildCore(server, store: store);
    await first.init();
    await first.signIn(session);
    await first.dispose();

    final second = buildCore(server, store: store);
    await second.init();
    expect(second.client.accountId, 42);
    await tester.pumpWidget(app(RoomsScreen(second)));
    await settle(tester);
    expect(find.text('account 42'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await second.dispose();
  });

  testWidgets('pages load more through the notifier', (tester) async {
    final all = [a, b, c];
    final server = DwFakeServer(protocol: roomsProtocol)
      ..onRequest<FeedRooms>(
        (request, call) =>
            DwOk(dwFakePage(all, call.page, pageSize: request.pageSize)),
      );
    final dw = buildCore(server);
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
    await dw.dispose();
  });

  testWidgets('dw is built, disposed and built again in one process', (
    tester,
  ) async {
    final server = DwFakeServer(protocol: roomsProtocol)
      ..onRequest<ListRooms>((request, call) => const DwOk([a]));

    for (var round = 0; round < 3; round++) {
      final dw = buildCore(server);
      expect(
        () => buildCore(server),
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
    expect(server.connections, hasLength(3));
    expect(server.openConnections, isEmpty);
  });

  test(
    'DwCore refuses a config that cannot render refusals, claiming nothing',
    () async {
      final server = DwFakeServer(protocol: roomsProtocol);
      expect(
        () => DwCore(
          config: const DwConfig(),
          protocol: roomsProtocol,
          endpoint: server.endpoint,
          connector: server.connector,
        ),
        throwsArgumentError,
      );
      final dw = buildCore(server);
      await dw.dispose();
    },
  );

  test(
    'DwCore without a key-value store plugin fails init, naming the fix',
    () async {
      final server = DwFakeServer(protocol: roomsProtocol);
      final dw = DwCore(
        config: DwConfig(refusalText: (refusal) => refusal.code),
        protocol: roomsProtocol,
        endpoint: server.endpoint,
        connector: server.connector,
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
    },
  );
}
