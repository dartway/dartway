import 'package:dartway_core/dartway_core.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  final harness = useHarness();

  test('a kind without a rule is refused as unknown', () async {
    final (connection, _) = await harness().signedIn('unknown@example.com');
    final answer = await connection.subscribe('nosuchkind:1');
    expect(
      (answer as DwSubscriptionRefusedMessage).refusal,
      DwRefusal(DwCoreRefusal.unknownChannel),
    );
    await connection.close();
  });

  test('an anonymous connection is refused as not authenticated', () async {
    final connection = await harness().connect();
    final answer = await connection.subscribe('notes');
    expect(answer, isA<DwSubscriptionRefusedMessage>());
    expect((answer as DwSubscriptionRefusedMessage).refusal, isNull);
    await connection.close();
  });

  test('keyed: the check decides; malformed, non-canonical and missing keys '
      'are invalid', () async {
    final (connection, session) = await harness().signedIn('keyed@example.com');
    expect(
      await connection.subscribe('account:${session.id}'),
      isA<DwSubscribedMessage>(),
    );
    final other = await connection.subscribe('account:${session.id + 1000}');
    expect(
      (other as DwSubscriptionRefusedMessage).refusal,
      DwRefusal(DwCoreRefusal.forbidden),
    );
    for (final name in [
      'account:x',
      'account:0${session.id}',
      'account',
      'notes:1',
    ]) {
      final answer = await connection.subscribe(name);
      expect(
        (answer as DwSubscriptionRefusedMessage).refusal,
        DwRefusal(DwCoreRefusal.invalid, field: 'channel'),
        reason: name,
      );
    }
    final nobody = await connection.subscribe('nobody');
    expect(
      (nobody as DwSubscriptionRefusedMessage).refusal!.code,
      'dw.forbidden',
    );
    await connection.close();
  });

  test(
    'a throwing rule is a failure with an incident, not a forbidden',
    () async {
      final (connection, _) = await harness().signedIn('broken@example.com');
      final answer =
          await connection.subscribe('broken') as DwSubscriptionRefusedMessage;
      expect(answer.refusal!.code, 'dw.failed');
      final incident = answer.refusal!.params['incident'];
      await eventually(
        () => harness().app.alerts.incidents.any((i) => i.id == incident),
      );
      await connection.close();
    },
  );

  test(
    'subscribing twice is idempotent: one subscription, one delivery',
    () async {
      final (listener, _) = await harness().signedIn('twice-l@example.com');
      final (author, _) = await harness().signedIn('twice-a@example.com');
      expect(await listener.subscribe('notes'), isA<DwSubscribedMessage>());
      expect(await listener.subscribe('notes'), isA<DwSubscribedMessage>());
      await author.command(const CreateNote('once'));
      final update = await listener.expect<DwUpdateMessage>();
      expect((update.items.single as NoteView).text, 'once');
      await listener.expectSilence();

      listener.unsubscribe('notes');
      // Unsubscribe has no answer; a round trip proves it was processed.
      await listener.request(const ListNotes(ownerId: -1));
      await author.command(const CreateNote('after unsubscribe'));
      await listener.expectSilence();
      await listener.close();
      await author.close();
    },
  );

  test('subscribe and unsubscribe of one channel apply in order', () async {
    final (connection, _) = await harness().signedIn('order@example.com');
    connection.send(const DwSubscribeMessage('notes'));
    connection.send(const DwUnsubscribeMessage('notes'));
    connection.send(const DwSubscribeMessage('notes'));
    await connection.expect<DwSubscribedMessage>();
    await connection.expect<DwSubscribedMessage>();
    final (author, _) = await harness().signedIn('order-a@example.com');
    await author.command(const CreateNote('ordered'));
    expect(
      ((await connection.expect<DwUpdateMessage>()).items.single as NoteView)
          .text,
      'ordered',
    );
    await connection.close();
    await author.close();
  });

  test(
    'a revocation closes that account\'s subscription after commit',
    () async {
      final (victim, victimSession) = await harness().signedIn(
        'victim@example.com',
      );
      final (bystander, _) = await harness().signedIn('bystander@example.com');
      final (admin, _) = await harness().signedIn('admin@example.com');
      for (final c in [victim, bystander]) {
        expect(await c.subscribe('notes'), isA<DwSubscribedMessage>());
      }
      expect(
        (await admin.command(RevokeNotes(victimSession.id))).status,
        DwResultStatus.ok,
      );
      expect((await victim.expect<DwChannelClosedMessage>()).channel, 'notes');
      // Revocations are delivered before publications of the same command.
      await victim.expectSilence();
      final update = await bystander.expect<DwUpdateMessage>();
      expect((update.items.single as NoteView).text, 'after revoke');
      for (final c in [victim, bystander, admin]) {
        await c.close();
      }
    },
  );
}
