import 'package:dartway_server/dartway_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// Subscriptions on the live socket: who may subscribe, and what closes them.
void main() {
  final harness = useHarness();

  Future<(DwTestCaller, DwAuthSession, DwTestLiveSocket)> signedSocket(
    String identifier,
  ) async {
    final (caller, session) = await harness().signedIn(identifier);
    return (caller, session, await harness().live(token: session.token));
  }

  test('a kind without a rule is refused as unknown', () async {
    final (_, _, socket) = await signedSocket('unknown@example.com');
    final answer = await socket.subscribe('nosuchkind:1');
    expect(
      (answer as DwSubscriptionRefusedMessage).refusal,
      DwCallRefusal(DwCoreRefusal.unknownChannel),
    );
  });

  test('an anonymous connection is refused as not authenticated', () async {
    final socket = await harness().live();
    final answer = await socket.subscribe('notes');
    expect((answer as DwSubscriptionRefusedMessage).isUnauthenticated, isTrue);
  });

  test('keyed: the check decides; malformed, non-canonical and missing keys '
      'are invalid', () async {
    final (_, session, socket) = await signedSocket('keyed@example.com');
    expect(
      await socket.subscribe('account:${session.id}'),
      isA<DwSubscribedMessage>(),
    );
    final other = await socket.subscribe('account:${session.id + 1000}');
    expect(
      (other as DwSubscriptionRefusedMessage).refusal,
      DwCallRefusal(DwCoreRefusal.forbidden),
    );
    for (final name in [
      'account:x',
      'account:0${session.id}',
      'account',
      'notes:1',
    ]) {
      final answer = await socket.subscribe(name);
      expect(
        (answer as DwSubscriptionRefusedMessage).refusal,
        DwCallRefusal(DwCoreRefusal.invalid, field: 'channel'),
        reason: name,
      );
    }
    final nobody = await socket.subscribe('nobody');
    expect(
      (nobody as DwSubscriptionRefusedMessage).refusal!.code,
      'dw.forbidden',
    );
  });

  test(
    'a throwing rule is a failure with an incident, not a forbidden',
    () async {
      final (_, _, socket) = await signedSocket('broken@example.com');
      final answer =
          await socket.subscribe('broken') as DwSubscriptionRefusedMessage;
      expect(answer.refusal, isNull);
      final incident = answer.incidentId;
      expect(incident, isNotNull);
      await eventually(
        () => harness().app.alerts.incidents.any((i) => i.id == incident),
      );
    },
  );

  test(
    'subscribing twice is idempotent: one subscription, one delivery',
    () async {
      final (_, _, listener) = await signedSocket('twice-l@example.com');
      final (author, _) = await harness().signedIn('twice-a@example.com');
      expect(await listener.subscribe('notes'), isA<DwSubscribedMessage>());
      expect(await listener.subscribe('notes'), isA<DwSubscribedMessage>());
      await author.call(const CreateNote('once'));
      final update = await listener.expect<DwUpdateMessage>();
      expect((update.updates.objects.single as NoteView).text, 'once');
      await listener.expectSilence();

      listener.unsubscribe('notes');
      // Unsubscribe has no answer; a subscription after it proves it was
      // processed, in order.
      expect(await listener.subscribe('public'), isA<DwSubscribedMessage>());
      await author.call(const CreateNote('after unsubscribe'));
      await listener.expectSilence();
    },
  );

  test('subscribe and unsubscribe of one channel apply in order', () async {
    final (_, _, socket) = await signedSocket('order@example.com');
    socket.send(const DwSubscribeMessage('notes'));
    socket.send(const DwUnsubscribeMessage('notes'));
    socket.send(const DwSubscribeMessage('notes'));
    await socket.expect<DwSubscribedMessage>();
    await socket.expect<DwSubscribedMessage>();
    final (author, _) = await harness().signedIn('order-a@example.com');
    await author.call(const CreateNote('ordered'));
    expect(
      ((await socket.expect<DwUpdateMessage>()).updates.objects.single
              as NoteView)
          .text,
      'ordered',
    );
  });

  test('an update message is one channel and its transport', () async {
    final (_, _, socket) = await signedSocket('wire@example.com');
    expect(await socket.subscribe('public'), isA<DwSubscribedMessage>());
    final (author, _) = await harness().signedIn('wire-a@example.com');
    final frames = socket.frames.length;
    await author.call(const Burst(3, 1));
    await socket.expect<DwUpdateMessage>();
    expect(socket.frames.length - frames, 1);
    expect(
      socket.frames.last,
      '{"k":"upd","ch":"public","updates":{"NoteView":'
      '[{"id":0,"text":"x"},{"id":1,"text":"x"},{"id":2,"text":"x"}]}}',
    );
  });
}
