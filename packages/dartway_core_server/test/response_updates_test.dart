import 'dart:convert';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// A channel only staff may subscribe to: admin counters and profiles.
enum StaffChannel with DwChannelKind { staff }

const _staff = DwLiveChannel(StaffChannel.staff);

/// What a command's response carries (D-053): the publications to channels
/// its caller may read — its connection subscribed to them, or their rule
/// allows the caller now — whether or not it has a live connection. A
/// publication to a channel the caller may not read never travels in its
/// response; subscribers hear it over the socket.
void main() {
  final harness = useHarness(
    build: (app, config) => app.server(
      config,
      auth: _announcingNewcomers(app.auth()),
      handlers: [
        for (final handler in app.handlers())
          if (handler.callType != Ping) handler,
        // A member's action that the staff dashboard hears of, published as
        // well to a channel nobody may read and to one whose rule throws.
        DwCallHandler.command<Ping, String>(
          access: DwAccessRule.signedIn,
          handle: (ctx, command) async {
            final note = NoteView(
              id: ctx.requireAccountId,
              text: 'action ${ctx.requireAccountId}',
            );
            ctx
              ..publish(_staff, note)
              ..publish(const DwLiveChannel(TestChannel.notes), note)
              ..publish(const DwLiveChannel(TestChannel.nobody), note)
              ..publish(const DwLiveChannel(TestChannel.broken), note);
            return 'pong';
          },
        ),
      ],
      channels: [
        ...app.channels(),
        DwChannelRule.single(
          StaffChannel.staff,
          canSubscribe: (ctx) async => app.staff.contains(ctx.accountId),
        ),
      ],
    ),
  );

  /// A staff member's socket subscribed to [_staff].
  Future<DwTestLiveSocket> staffSocket(String identifier) async {
    final (_, session) = await harness().signedIn(identifier);
    harness().app.staff.add(session.id);
    final socket = await harness().live(token: session.token);
    expect(await socket.subscribe('staff'), isA<DwSubscribedMessage>());
    return socket;
  }

  Map<Object?, Object?> updatesOf(DwTestAnswer answer) =>
      ((answer.json! as Map)['updates'] as Map?) ?? const {};

  test("a newcomer's sign-in response carries none of what the sign-in hook "
      'published to staff, and staff hear it over the socket', () async {
    final admin = await staffSocket('leak-admin@example.com');

    final anonymous = harness().caller();
    const identifier = 'leak-newcomer@example.com';
    final request = DwRequestCode(
      kind: DwIdentifierKind.email,
      identifier: identifier,
    );
    final ticket = (await anonymous.call(request)).value(request);
    final verify = DwVerifyCode(
      ticketId: ticket.id,
      code: harness().app.delivered[identifier]!,
    );
    final answer = await anonymous.call(verify);
    final session = answer.value(verify);

    expect(answer.status, 200);
    expect((answer.json! as Map).containsKey('updates'), isFalse);
    expect(answer.text, isNot(contains('newcomer $identifier')));
    final heard = await admin.expect<DwUpdateMessage>(
      where: (m) => m.channel == 'staff',
    );
    expect(heard.updates.objects, [
      NoteView(id: session.id, text: 'newcomer $identifier'),
    ]);
  });

  test(
    'a member with no live connection gets in the response the channels '
    'it may read, not the staff channel; staff hear it over the socket',
    () async {
      final admin = await staffSocket('leak-admin2@example.com');
      final (member, session) = await harness().signedIn(
        'leak-member@example.com',
      );

      final answer = await member.call(const Ping());
      expect(answer.value(const Ping()), 'pong');
      expect(updatesOf(answer), {
        'notes': {
          'NoteView': [
            {'id': session.id, 'text': 'action ${session.id}'},
          ],
        },
      });

      final heard = await admin.expect<DwUpdateMessage>(
        where: (m) => m.channel == 'staff' && _isAction(m),
      );
      expect(heard.updates.objects, [
        NoteView(id: session.id, text: 'action ${session.id}'),
      ]);
    },
  );

  test('a rule that refuses keeps its channel out of the response; one that '
      'throws does too, and is reported', () async {
    final (member, _) = await harness().signedIn('leak-rules@example.com');

    final answer = await member.call(const Ping());
    expect(updatesOf(answer).keys, ['notes']);
    await eventually(
      () => harness().app.alerts.incidents.any(
        (i) => i.where.contains('broken') && i.error is StateError,
      ),
    );
  });

  test(
    "a caller naming its own connection gets its channels in the response "
    'and nothing of the call over that socket; other subscribers hear it',
    () async {
      final admin = await staffSocket('leak-admin3@example.com');
      final (member, session) = await harness().signedIn(
        'leak-named@example.com',
      );
      final memberSocket = await harness().live(token: session.token);
      expect(await memberSocket.subscribe('notes'), isA<DwSubscribedMessage>());
      member.liveConnection = memberSocket.connectionId;

      final answer = await member.call(const Ping());
      expect(updatesOf(answer).keys, ['notes']);
      expect(
        (await admin.expect<DwUpdateMessage>(
          where: (m) => m.channel == 'staff' && _isAction(m),
        )).updates.objects,
        [NoteView(id: session.id, text: 'action ${session.id}')],
      );
      await memberSocket.expectSilence();
    },
  );

  test('staff get the staff channel in the response, with a subscribed '
      'connection and without one', () async {
    const identifier = 'leak-admin4@example.com';
    final (caller, session) = await harness().signedIn(identifier);
    harness().app.staff.add(session.id);

    final withoutSocket = await caller.call(const Ping());
    expect(updatesOf(withoutSocket).keys, ['staff', 'notes']);

    final socket = await harness().live(token: session.token);
    expect(await socket.subscribe('staff'), isA<DwSubscribedMessage>());
    caller.liveConnection = socket.connectionId;
    final withSocket = await caller.call(const Ping());
    expect(updatesOf(withSocket).keys, ['staff', 'notes']);
    await socket.expectSilence();
  });

  test('a channel the call revokes for its caller is not in its response, '
      'while one it still reads is', () async {
    final (member, session) = await harness().signedIn(
      'leak-revoked@example.com',
    );
    final socket = await harness().live(token: session.token);
    expect(await socket.subscribe('notes'), isA<DwSubscribedMessage>());
    member.liveConnection = socket.connectionId;

    final answer = await member.call(RevokeNotes(session.id));
    expect(answer.status, 200);
    expect(updatesOf(answer).keys, ['public']);
    expect(
      await socket.expect<DwChannelClosedMessage>(),
      isA<DwChannelClosedMessage>().having(
        (m) => m.channel,
        'channel',
        'notes',
      ),
    );
    await socket.expectSilence();
  });

  group('the real client', () {
    test("a new account's sign-in by code: the verify response carries no "
        'staff data, and its own command updates its own list from the '
        'response', () async {
      final admin = await staffSocket('leak-admin5@example.com');
      final transport = _RecordingTransport(DwHttpClientTransport());
      final client = await harness().server.connectClient(
        httpTransport: transport,
      );
      addTearDown(client.stop);

      const identifier = 'leak-client@example.com';
      final ticket = await client.command(
        const DwRequestCode(
          kind: DwIdentifierKind.email,
          identifier: identifier,
        ),
      );
      final verified = await client.command(
        DwVerifyCode(
          ticketId: ticket.valueOrNull!.id,
          code: harness().app.delivered[identifier]!,
        ),
      );
      final session = verified.valueOrNull!;

      final verifyReply = transport.replyTo('DwVerifyCode');
      expect(verifyReply.status, 200);
      expect(
        (jsonDecode(verifyReply.body) as Map).containsKey('updates'),
        isFalse,
      );
      expect(verifyReply.body, isNot(contains('newcomer')));
      expect(
        (await admin.expect<DwUpdateMessage>(
          where: (m) => m.channel == 'staff',
        )).updates.objects,
        [NoteView(id: session.id, text: 'newcomer $identifier')],
      );

      await client.signIn(session);
      final notes = client.watch(const LiveNotes());
      await eventually(() => notes.isLive);

      final created = await client.command(const CreateNote('from the client'));
      expect(created, isA<DwCallOk<NoteView>>());
      // Applied before the command completed: the response carried it.
      expect(switch (notes.state) {
        DwRequestData(:final value) => value.first.text,
        final other => other,
      }, 'from the client');

      final post = transport.postTo('CreateNote');
      expect(post.headers[DwHttpContract.liveConnectionHeader], isNotNull);
      final reply = jsonDecode(transport.replyTo('CreateNote').body) as Map;
      expect((reply['updates'] as Map).keys, [
        'notes',
        'account:${session.id}',
      ]);
    });
  });
}

/// An update of the `Ping` action rather than a newcomer's announcement.
bool _isAction(DwUpdateMessage message) => message.updates.objects.any(
  (object) => object is NoteView && object.text.startsWith('action '),
);

/// The fixture's auth, with an account-creation hook that — like the
/// example's — tells staff of the newcomer.
DwAuthConfig _announcingNewcomers(DwAuthConfig base) => DwAuthConfig(
  accountDeletion: base.accountDeletion,
  normalize: base.normalize,
  deliverCode: base.deliverCode,
  generateCode: base.generateCode,
  onAccountCreated: (ctx, accountId, kind, identifier, origin) async {
    await base.onAccountCreated!(ctx, accountId, kind, identifier, origin);
    ctx.publish(_staff, NoteView(id: accountId, text: 'newcomer $identifier'));
  },
  onIdentifierChanged: base.onIdentifierChanged,
  maxAttempts: base.maxAttempts,
  maxRequestsPerWindow: base.maxRequestsPerWindow,
  requestWindow: base.requestWindow,
  resendDelay: base.resendDelay,
  keyTouchInterval: base.keyTouchInterval,
);

/// Real HTTP, with every post and its reply kept by the call's wire name.
final class _RecordingTransport implements DwHttpTransport {
  _RecordingTransport(this._inner);

  final DwHttpTransport _inner;
  final List<(DwHttpPost, DwHttpReply)> _calls = [];

  DwHttpPost postTo(String wireName) => _last(wireName).$1;

  DwHttpReply replyTo(String wireName) => _last(wireName).$2;

  (DwHttpPost, DwHttpReply) _last(String wireName) =>
      _calls.lastWhere((call) => call.$1.url.pathSegments.last == wireName);

  @override
  Future<DwHttpReply> post(DwHttpPost post) async {
    final reply = await _inner.post(post);
    _calls.add((post, reply));
    return reply;
  }

  @override
  void close() => _inner.close();
}
