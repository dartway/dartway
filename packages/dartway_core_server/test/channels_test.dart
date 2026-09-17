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

  group('caller channels (D-037)', () {
    test(
      'ofCaller: a connection subscribes to its own account\'s key only',
      () async {
        final (_, session, socket) = await signedSocket('inbox@example.com');
        expect(
          await socket.subscribe('inbox:${session.id}'),
          isA<DwSubscribedMessage>(),
        );
        final other = await socket.subscribe('inbox:${session.id + 1000}');
        expect(
          (other as DwSubscriptionRefusedMessage).refusal,
          DwCallRefusal(DwCoreRefusal.forbidden),
        );
        for (final name in [
          'inbox',
          'inbox:me',
          'inbox:0${session.id}',
          'inbox:+${session.id}',
        ]) {
          final answer = await socket.subscribe(name);
          expect(
            (answer as DwSubscriptionRefusedMessage).refusal,
            DwCallRefusal(DwCoreRefusal.invalid, field: 'channel'),
            reason: name,
          );
        }
      },
    );

    test(
      'forAccount publishes to that account\'s caller channel only',
      () async {
        final (_, recipient, recipientSocket) = await signedSocket(
          'inbox-r@example.com',
        );
        final (_, _, bystander) = await signedSocket('inbox-b@example.com');
        final (sender, senderSession) = await harness().signedIn(
          'inbox-s@example.com',
        );
        final senderSocket = await harness().live(token: senderSession.token);
        expect(
          await recipientSocket.subscribe('inbox:${recipient.id}'),
          isA<DwSubscribedMessage>(),
        );
        expect(
          await senderSocket.subscribe('inbox:${senderSession.id}'),
          isA<DwSubscribedMessage>(),
        );
        sender.liveConnection = senderSocket.connectionId;

        final answer = await sender.call(
          SendToInbox('for you', accountId: recipient.id),
        );
        final update = await recipientSocket.expect<DwUpdateMessage>();
        expect(update.channel, 'inbox:${recipient.id}');
        expect((update.updates.objects.single as NoteView).text, 'for you');
        // The sender listens to its own inbox, not the recipient's: the
        // response carries nothing, and nothing reaches anyone else.
        expect(answer.updates.isEmpty, isTrue);
        await senderSocket.expectSilence();
        await bystander.expectSilence();
      },
    );

    test('publishing to an unresolved caller channel is a failure where it '
        'is made', () async {
      final (sender, _) = await harness().signedIn('inbox-x@example.com');
      final answer = await sender.call(const SendToInbox('whose?'));
      expect(answer.status, 500);
      final incident = harness().app.alerts.incidents.last;
      expect(incident.id, (answer.response as DwApiFailed).incidentId);
      expect(
        incident.error,
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('DwLiveChannel.forAccount(inbox, accountId)'),
        ),
      );
    });
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

  group('server-level work', () {
    test(
      'publishes after commit, as a job would, and answers its value',
      () async {
        final (_, _, listener) = await signedSocket('ctx-listener@example.com');
        expect(await listener.subscribe('notes'), isA<DwSubscribedMessage>());
        final answer = await harness().server.runInContext((ctx) async {
          ctx.publish(
            const DwLiveChannel(TestChannel.notes),
            const NoteView(id: 901, text: 'from a service'),
          );
          await listener.expectSilence();
          return 'done';
        });
        expect(answer, 'done');
        final update = await listener.expect<DwUpdateMessage>();
        expect(
          (update.updates.objects.single as NoteView).text,
          'from a service',
        );
      },
    );

    test('publishes nothing when the work throws', () async {
      final (_, _, listener) = await signedSocket('ctx-thrown@example.com');
      expect(await listener.subscribe('notes'), isA<DwSubscribedMessage>());
      await expectLater(
        harness().server.runInContext<void>((ctx) async {
          ctx.publish(
            const DwLiveChannel(TestChannel.notes),
            const NoteView(id: 902, text: 'never'),
          );
          throw StateError('the service failed');
        }),
        throwsStateError,
      );
      await listener.expectSilence();
    });
  });

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

  test('an update message is one channel and its objects by type', () async {
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
