import 'dart:convert';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// A channel only staff may subscribe to: admin counters and profiles.
enum StaffChannel with DwChannelKind { staff }

const _staff = DwLiveChannel(StaffChannel.staff);

/// What a command's response may carry (D-053): only the channels its own
/// named live connection subscribed to — access to those was checked when it
/// subscribed. A publication to a channel the caller may not read never
/// travels in its response.
void main() {
  final harness = useHarness(
    build: (app, config) => app.server(
      config,
      auth: _announcingNewcomers(app.auth()),
      handlers: [
        for (final handler in app.handlers())
          if (handler.callType != Ping) handler,
        // A member's action that the staff dashboard hears of.
        DwCallHandler.command<Ping, String>(
          access: DwAccessRule.signedIn,
          handle: (ctx, command) async {
            final note = NoteView(
              id: ctx.requireAccountId,
              text: 'staff-only ${ctx.requireAccountId}',
            );
            ctx
              ..publish(_staff, note)
              ..publish(const DwLiveChannel(TestChannel.notes), note);
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

  test('a command naming no live connection that publishes to a channel the '
      'caller may not subscribe to answers ok without updates; a subscribed '
      'staff connection hears the object', () async {
    final admin = await staffSocket('leak-admin2@example.com');
    final (member, session) = await harness().signedIn(
      'leak-member@example.com',
    );
    final memberSocket = await harness().live(token: session.token);
    expect(
      await memberSocket.subscribe('staff'),
      isA<DwSubscriptionRefusedMessage>(),
      reason: 'the member may not read the channel',
    );

    final answer = await member.call(const Ping());
    expect(answer.value(const Ping()), 'pong');
    expect((answer.json! as Map).containsKey('updates'), isFalse);
    expect(answer.text, isNot(contains('staff-only')));

    // The member's own sign-in announced them to staff before this.
    final heard = await admin.expect<DwUpdateMessage>(
      where: (m) => m.channel == 'staff' && _isAction(m),
    );
    expect(
      (heard.updates.objects.single as NoteView).text,
      'staff-only ${session.id}',
    );
  });

  test('a caller naming its own connection gets only the channels that '
      'connection subscribed to', () async {
    final admin = await staffSocket('leak-admin3@example.com');
    final (member, session) = await harness().signedIn(
      'leak-named@example.com',
    );
    final memberSocket = await harness().live(token: session.token);
    expect(await memberSocket.subscribe('notes'), isA<DwSubscribedMessage>());
    member.liveConnection = memberSocket.connectionId;

    final answer = await member.call(const Ping());
    expect(answer.updates.channels.keys, ['notes']);
    expect((answer.json! as Map)['updates'], {
      'notes': {
        'NoteView': [
          {'id': session.id, 'text': 'staff-only ${session.id}'},
        ],
      },
    });
    expect(
      (await admin.expect<DwUpdateMessage>(
        where: (m) => m.channel == 'staff' && _isAction(m),
      )).updates.objects,
      [NoteView(id: session.id, text: 'staff-only ${session.id}')],
    );
    await memberSocket.expectSilence();
  });

  test('staff naming a connection subscribed to the staff channel get it in '
      'the response', () async {
    const identifier = 'leak-admin4@example.com';
    final (caller, session) = await harness().signedIn(identifier);
    harness().app.staff.add(session.id);
    final socket = await harness().live(token: session.token);
    expect(await socket.subscribe('staff'), isA<DwSubscribedMessage>());
    caller.liveConnection = socket.connectionId;

    final answer = await caller.call(const Ping());
    expect(answer.updates.channels.keys, ['staff']);
    await socket.expectSilence();
  });

  group('the real client', () {
    test("a new account's sign-in by code: the verify response carries no "
        'staff data, and once live, its own command updates its own list '
        'from the response it named its connection in', () async {
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
      expect((reply['updates'] as Map).keys, ['notes']);
    });
  });
}

/// An update of the `Ping` action rather than a newcomer's announcement.
bool _isAction(DwUpdateMessage message) => message.updates.objects.any(
  (object) => object is NoteView && object.text.startsWith('staff-only'),
);

/// The fixture's auth, with an account-creation hook that — like the
/// example's — tells staff of the newcomer.
DwAuthConfig _announcingNewcomers(DwAuthConfig base) => DwAuthConfig(
  normalize: base.normalize,
  deliverCode: base.deliverCode,
  fixedCode: base.fixedCode,
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
