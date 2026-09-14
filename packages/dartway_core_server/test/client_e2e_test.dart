import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';

import 'support/test_app.dart';

/// The real client against the real server: HTTP calls, the live socket and
/// the response transport, with nothing faked in between. The wire itself is
/// pinned by the other suites; these check that the two sides, as shipped,
/// agree.
void main() {
  final harness = useHarness();

  DwTestServer server() => harness().server;

  /// Signs [client] in by code, as an app does: request a code, read the one
  /// the test app delivered, verify it, adopt the session.
  Future<DwAuthSession> signIn(DwAppClient client, String email) async {
    final ticket = await client.command(
      DwRequestCode(kind: DwIdentifierKind.email, identifier: email),
    );
    final code = harness().app.delivered[email];
    expect(code, isNotNull, reason: 'the code was delivered');
    final verified = await client.command(
      DwVerifyCode(ticketId: ticket.valueOrNull!.id, code: code!),
    );
    final session = verified.valueOrNull!;
    await client.signIn(session);
    return session;
  }

  Future<DwAppClient> connect({
    DwHttpTransport? httpTransport,
    DwLiveConnector? liveConnector,
  }) async {
    final client = await server().connectClient(
      httpTransport: httpTransport,
      liveConnector: liveConnector,
    );
    addTearDown(client.stop);
    return client;
  }

  List<String> texts(DwRequestState<List<NoteView>> state) => switch (state) {
    DwRequestData(:final value) => [for (final note in value) note.text],
    _ => throw TestFailure('expected data, got $state'),
  };

  test(
    'sign-in by code, a live list updated over the socket by another '
    "client's command, and the author's own list from the response",
    () async {
      final aliceFrames = _RecordingConnector();
      final bobFrames = _RecordingConnector();
      final alice = await connect(liveConnector: aliceFrames);
      final bob = await connect(liveConnector: bobFrames);
      final aliceSession = await signIn(alice, 'e2e-alice@example.com');
      await signIn(bob, 'e2e-bob@example.com');
      expect(alice.accountId, aliceSession.id);

      final aliceNotes = alice.watch(const LiveNotes());
      final bobNotes = bob.watch(const LiveNotes());
      await eventually(() => aliceNotes.isLive && bobNotes.isLive);

      final created = await bob.command(const CreateNote('from bob'));
      expect(created, isA<DwCallOk<NoteView>>());
      // Applied before the command completed: the response carried it.
      expect(texts(bobNotes.state).first, 'from bob');

      await eventually(() => texts(aliceNotes.state).firstOrNull == 'from bob');
      expect(
        aliceFrames.updates,
        isNotEmpty,
        reason: 'it came over the socket',
      );

      // Give an echo every chance to arrive before saying there is none.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(
        bobFrames.updates,
        isEmpty,
        reason: "the author's socket does not echo its own command's updates",
      );
      expect(texts(bobNotes.state).where((t) => t == 'from bob'), hasLength(1));
    },
  );

  test('signed out, a request with channels fetches at once without a socket, '
      'and becomes live after sign-in', () async {
    final connector = _RecordingConnector();
    final client = await connect(liveConnector: connector);
    final notes = client.watch(const LiveNotes());
    await eventually(() => notes.state is DwRequestData);
    expect(notes.isLive, isFalse);
    expect(connector.connects, 0, reason: 'no socket for an anonymous client');
    expect(client.connectionStatus, DwConnectionStatus.idle);

    await signIn(client, 'e2e-late@example.com');
    await eventually(() => notes.isLive);
    expect(connector.connects, 1);
    expect(
      connector.received.where((frame) => frame.contains('"subno"')),
      isEmpty,
      reason: 'never subscribed while signed out',
    );
  });

  test(
    'refusals: by the server, by validation, and by an access check',
    () async {
      final client = await connect();
      await signIn(client, 'e2e-refused@example.com');

      final refused = await client.command(
        const Count('e2e-refusal', mode: 'refuse'),
      );
      expect(
        refused,
        isA<DwCallRefused<int>>()
            .having(
              (r) => r.refusal.isCode(DwCoreRefusal.conflict),
              'code',
              true,
            )
            .having((r) => r.refusal.params, 'params', {'n': '1'}),
      );

      final invalid = await client.command(const CreateNote(''));
      expect(
        invalid,
        isA<DwCallRefused<NoteView>>().having(
          (r) => r.refusal.field,
          'field',
          'text',
        ),
      );

      final foreign = client.watch(const NotesOfOwner(999999));
      await eventually(() => foreign.state is! DwRequestLoading);
      expect(
        foreign.state,
        isA<DwRequestRefused<List<NoteView>>>().having(
          (s) => s.refusal.isCode(DwCoreRefusal.forbidden),
          'forbidden',
          isTrue,
        ),
      );
    },
  );

  test('a table page with its total', () async {
    for (var i = 1; i <= 5; i++) {
      await TestApp.insertNote(harness().db, 'e2e-table-$i');
    }
    final client = await connect();
    final page = client.watchTable(
      const TableNotes('e2e-table', page: 2, pageSize: 2),
    );
    await eventually(() => page.state is DwRequestData);
    final value = (page.state as DwRequestData<DwTablePage<NoteView>>).value;
    expect(
      [for (final note in value.items) note.text],
      ['e2e-table-3', 'e2e-table-4'],
    );
    expect(value.total, 5);
    expect((value.page, value.pageSize), (2, 2));
  });

  test('a window loads older and newer rows around an anchor, rows sharing a '
      'timestamp neither lost nor repeated', () async {
    // Twelve messages in four instants, three per instant.
    final base = DateTime.utc(2026, 9, 14, 12);
    final ids = <int>[];
    for (var i = 0; i < 12; i++) {
      final row = (await harness().db.query(
        'INSERT INTO message (room, text, sent_at) '
        'VALUES (@room, @text, @at) RETURNING id',
        params: {
          'room': 'e2e-ties',
          'text': 'm$i',
          'at': base.add(Duration(minutes: i ~/ 3)),
        },
      )).single;
      ids.add(row.get<int>('id'));
    }
    const request = ChatWindow('e2e-ties');
    // Anchored in the middle of a tie: m7 shares its instant with m6 and m8.
    final anchor = DwWindowCursor.encode(
      base.add(const Duration(minutes: 2)),
      ids[7],
    );

    final client = await connect();
    final window = client.watchWindow(request, anchor: anchor);
    await eventually(() => window.state is DwRequestData);
    DwWindowData<MessageView> data() =>
        (window.state as DwRequestData<DwWindowData<MessageView>>).value;
    expect(data().items.map((m) => m.text), contains('m7'));
    expect((data().hasOlder, data().hasNewer), (true, true));

    while (data().hasOlder) {
      await window.loadOlder();
    }
    while (data().hasNewer) {
      await window.loadNewer();
    }
    expect(data().items.map((m) => m.text).toList(), [
      for (var i = 11; i >= 0; i--) 'm$i',
    ]);
    expect(data().loadError, isNull);
  });

  test(
    'an account switch never shows the previous account its entries',
    () async {
      // Sessions made on another client and adopted here: a code is sent once
      // per identifier within the resend delay.
      final writer = await connect();
      final carol = await signIn(writer, 'e2e-carol@example.com');
      await writer.command(const CreateNote('carol private'));
      final dave = await signIn(writer, 'e2e-dave@example.com');
      await writer.command(const CreateNote('dave private'));

      final client = await connect();
      await client.signIn(carol);
      final mine = client.watch(const MyNotes());
      await eventually(() => mine.state is DwRequestData);
      expect(texts(mine.state), ['carol private']);

      final seen = <DwRequestState<List<NoteView>>>[];
      final subscription = mine.states.listen(seen.add);
      addTearDown(subscription.cancel);
      await client.signIn(dave);
      expect(client.accountId, dave.id);
      await eventually(
        () => mine.state is DwRequestData && texts(mine.state).isNotEmpty,
      );
      expect(texts(mine.state), ['dave private']);
      final afterSwitch = seen
          .skip(1)
          .whereType<DwRequestData<List<NoteView>>>();
      expect(
        afterSwitch.expand((state) => state.value).map((note) => note.text),
        isNot(contains('carol private')),
      );
    },
  );

  test('sign-out ends the session here and on the server', () async {
    final client = await connect();
    final session = await signIn(client, 'e2e-leaving@example.com');
    final mine = client.watch(const MyNotes());
    await eventually(() => mine.state is DwRequestData);

    await client.signOut();
    expect(client.accountId, isNull);
    await eventually(() => mine.state is DwRequestUnauthenticated);

    final stale = harness().caller(token: session.token);
    final answer = await stale.call(const MyNotes());
    expect(answer.response, isA<DwApiUnauthenticated>());
  });

  test('a command whose answer was lost is replayed on retry, and what is on '
      'screen is read again', () async {
    final transport = _LosingTransport(DwHttpClientTransport());
    final client = await connect(httpTransport: transport);
    await signIn(client, 'e2e-replay@example.com');
    final notes = client.watch(const LiveNotes());
    await eventually(() => notes.isLive);
    final readsBefore = transport.posts('LiveNotes');

    transport.loseNextAnswerTo = 'CreateNote';
    final result = await client.command(const CreateNote('once only'));
    expect(result, isA<DwCallOk<NoteView>>());
    expect(transport.posts('CreateNote'), 2, reason: 'retried with its key');
    expect(transport.lost, 1);

    await eventually(() => transport.posts('LiveNotes') > readsBefore);
    await eventually(() => texts(notes.state).contains('once only'));
    final stored = await harness().db.query(
      "SELECT count(*) AS n FROM note WHERE text = 'once only'",
    );
    expect(stored.single.get<int>('n'), 1, reason: 'the handler ran once');
  });
}

/// The real socket, with every frame the server sent recorded.
final class _RecordingConnector implements DwLiveConnector {
  final DwLiveConnector _inner = const DwWebSocketConnector();
  final List<String> received = [];
  int connects = 0;

  /// The `upd` frames received.
  List<String> get updates => [
    for (final frame in received)
      if ((jsonDecode(frame) as Map<String, Object?>)['k'] == 'upd') frame,
  ];

  @override
  Future<DwLiveConnection> connect(Uri url) async {
    connects++;
    return _RecordingConnection(await _inner.connect(url), received);
  }
}

final class _RecordingConnection implements DwLiveConnection {
  _RecordingConnection(this._inner, this._received);

  final DwLiveConnection _inner;
  final List<String> _received;

  @override
  late final Stream<String> messages = _inner.messages.map((frame) {
    _received.add(frame);
    return frame;
  });

  @override
  void send(String frame) => _inner.send(frame);

  @override
  int? get closeCode => _inner.closeCode;

  @override
  String? get closeReason => _inner.closeReason;

  @override
  Future<void> close([int? code, String? reason]) => _inner.close(code, reason);
}

/// Real HTTP, except that the answer to the next call of one DTO is received
/// and then thrown away — a response lost on a flaky network after the server
/// did the work.
final class _LosingTransport implements DwHttpTransport {
  _LosingTransport(this._inner);

  final DwHttpTransport _inner;
  final Map<String, int> _posts = {};

  String? loseNextAnswerTo;
  int lost = 0;

  int posts(String wireName) => _posts[wireName] ?? 0;

  @override
  Future<DwHttpReply> post(DwHttpPost post) async {
    final wireName = post.url.pathSegments.last;
    _posts.update(wireName, (n) => n + 1, ifAbsent: () => 1);
    final reply = await _inner.post(post);
    if (loseNextAnswerTo == wireName) {
      loseNextAnswerTo = null;
      lost++;
      throw StateError('the answer to $wireName was lost');
    }
    return reply;
  }

  @override
  void close() => _inner.close();
}
