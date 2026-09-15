import 'dart:convert';

import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  final harness = useHarness();

  Future<int> executions(String label) async {
    final rows = await harness().db.query(
      'SELECT n FROM counter WHERE label = @label',
      params: {'label': label},
    );
    return rows.isEmpty ? 0 : rows.single.get<int>('n');
  }

  group('idempotency', () {
    test(
      'a repeated key answers the stored ok outcome without executing',
      () async {
        final caller = harness().caller();
        final first = await caller.call(const Count('repeat-ok'), key: 'r1');
        final second = await caller.call(const Count('repeat-ok'), key: 'r1');
        expect(first.value(const Count('')), 1);
        expect(second.value(const Count('')), 1);
        expect(await executions('repeat-ok'), 1);
        // Another caller of the same (anonymous) scope sees the same key.
        final other = harness().caller();
        expect(
          (await other.call(
            const Count('repeat-ok'),
            key: 'r1',
          )).value(const Count('')),
          1,
        );
        expect(await executions('repeat-ok'), 1);
      },
    );

    test('a refusal is stored after the rollback and answered again', () async {
      final caller = harness().caller();
      final first = await caller.call(
        const Count('repeat-refused', mode: 'refuse'),
        key: 'r2',
      );
      expect(first.status, 409);
      expect(
        first.refusal,
        DwCallRefusal(DwCoreRefusal.conflict, params: {'n': 1}),
      );
      expect(await executions('repeat-refused'), 0, reason: 'rolled back');
      final second = await caller.call(
        const Count('repeat-refused', mode: 'refuse'),
        key: 'r2',
      );
      expect(second.refusal, first.refusal);
      final stored = await harness().db.query(
        "SELECT status, type FROM dw_command_outcome WHERE key = 'r2'",
      );
      expect(stored.single['status'], 'refused');
      expect(stored.single['type'], 'Count');
    });

    test('a handler refusing with an incompatibility is answered 426, and '
        'so is its replay', () async {
      final caller = harness().caller();
      for (var i = 0; i < 2; i++) {
        final answer = await caller.call(
          const Count('outdated', mode: 'outdated'),
          key: 'r-outdated',
        );
        expect(answer.status, 426);
        expect(answer.refusal.isCode(DwCoreRefusal.updateRequired), isTrue);
      }
    });

    test('a failure is not stored: the same key executes again', () async {
      final caller = harness().caller();
      final first = await caller.call(
        const Count('retry-failed', mode: 'failOnce'),
        key: 'r3',
      );
      expect(first.status, 500);
      final second = await caller.call(
        const Count('retry-failed', mode: 'failOnce'),
        key: 'r3',
      );
      expect(second.value(const Count('')), 1, reason: 'the first rolled back');
    });

    test(
      'a serialization failure re-runs the whole transaction, silently',
      () async {
        final incidents = harness().app.alerts.incidents.length;
        final answer = await harness().caller().call(
          const Count('conflicted', mode: 'conflictOnce'),
        );
        expect(answer.value(const Count('')), 1);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(harness().app.alerts.incidents.length, incidents);
      },
    );

    test('the same key with another command type is a conflict', () async {
      final caller = harness().caller();
      await caller.call(const Count('typed'), key: 'r4');
      final other = await caller.call(const Ping(), key: 'r4');
      expect(other.status, 409);
      expect(other.refusal.params, {'idempotencyKey': 'reused'});
    });

    test('keys are scoped by account', () async {
      final (a, _) = await harness().signedIn('scope-a@example.com');
      final (b, _) = await harness().signedIn('scope-b@example.com');
      Future<int> count(DwTestCaller caller) async => (await caller.call(
        const Count('scoped'),
        key: 'r5',
      )).value(const Count(''));
      expect(await count(a), 1);
      expect(await count(b), 2);
      expect(await count(harness().caller()), 3);
      expect(await count(a), 1);
    });

    test('sends of one key racing each other execute once', () async {
      final answers = await Future.wait([
        for (var i = 0; i < 4; i++)
          harness().caller().call(const Count('race'), key: 'r6'),
      ]);
      expect(answers.map((a) => a.value(const Count(''))), everyElement(1));
      expect(await executions('race'), 1);
    });

    test(
      'a non-transactional command stores its outcome after the handler',
      () async {
        final caller = harness().caller();
        for (var i = 0; i < 2; i++) {
          final answer = await caller.call(
            const CountOutside('outside'),
            key: 'r7',
          );
          expect(answer.value(const CountOutside('')), 1);
        }
        expect(await executions('outside'), 1);
      },
    );
  });

  group('updates', () {
    test(
      'without Dw-Live-Connection the response carries no updates, and every '
      "subscriber hears them over the socket, the caller's own connections "
      'included',
      () async {
        final (author, session) = await harness().signedIn('plain@example.com');
        final authorSocket = await harness().live(token: session.token);
        for (final channel in ['notes', 'account:${session.id}']) {
          expect(
            await authorSocket.subscribe(channel),
            isA<DwSubscribedMessage>(),
          );
        }
        final (_, listenerSession) = await harness().signedIn(
          'plain-l@example.com',
        );
        final listener = await harness().live(token: listenerSession.token);
        expect(await listener.subscribe('notes'), isA<DwSubscribedMessage>());

        final answer = await author.call(const CreateNote('plain'));
        final note = answer.value(const CreateNote(''));
        // A call naming no live connection has no live state the response
        // could update, and nothing checked what it may read (D-053).
        expect(answer.updates.isEmpty, isTrue);
        expect((answer.json! as Map).containsKey('updates'), isFalse);
        // Each publication reaches the caller's socket under the channel it
        // went to (D-036): not named, so not relieved of the socket.
        expect(
          (await authorSocket.expect<DwUpdateMessage>(
            where: (m) => m.channel == 'notes',
          )).updates.objects,
          [note],
        );
        expect(
          (await authorSocket.expect<DwUpdateMessage>(
            where: (m) => m.channel == 'account:${session.id}',
          )).updates.objects,
          [note],
        );
        expect((await listener.expect<DwUpdateMessage>()).updates.objects, [
          note,
        ]);
      },
    );

    test('with Dw-Live-Connection the response carries what that connection '
        'listens to, the connection hears nothing of it over the socket, and '
        'others do — one message per channel', () async {
      final (author, session) = await harness().signedIn('named@example.com');
      final authorSocket = await harness().live(token: session.token);
      expect(await authorSocket.subscribe('notes'), isA<DwSubscribedMessage>());
      author.liveConnection = authorSocket.connectionId;

      final otherDevice = await harness().live(token: session.token);
      for (final channel in ['notes', 'account:${session.id}']) {
        expect(
          await otherDevice.subscribe(channel),
          isA<DwSubscribedMessage>(),
        );
      }

      final answer = await author.call(
        const CreateNote('named', extraPublishes: 2),
      );
      final note = answer.value(const CreateNote(''));
      // Subscribed to `notes` only: the `account:<id>` publication is not
      // this connection's business. The note published three times travels
      // once, as it ended.
      expect(answer.updates.channels.keys, ['notes']);
      expect(answer.updates.objectsOn('notes'), [
        NoteView(id: note.id, text: 'named #1', ownerId: session.id),
      ]);
      final wire = answer.json! as Map<String, Object?>;
      expect(wire['updates'], {
        'notes': {
          'NoteView': [
            {'id': note.id, 'text': 'named #1', 'ownerId': session.id},
          ],
        },
      });

      final notes = await otherDevice.expect<DwUpdateMessage>(
        where: (m) => m.channel == 'notes',
      );
      final account = await otherDevice.expect<DwUpdateMessage>(
        where: (m) => m.channel == 'account:${session.id}',
      );
      expect((notes.updates.objects.single as NoteView).text, 'named #1');
      expect(account.updates.objects, [note]);
      await otherDevice.expectSilence();
      await authorSocket.expectSilence();
      expect(authorSocket.frames.where((f) => f.contains('"upd"')), isEmpty);
    });

    test('a named connection subscribed to nothing gets a response without '
        'updates', () async {
      final (author, session) = await harness().signedIn('bare@example.com');
      final socket = await harness().live(token: session.token);
      author.liveConnection = socket.connectionId;
      final answer = await author.call(const CreateNote('bare'));
      expect(answer.updates.isEmpty, isTrue);
      expect((answer.json! as Map).containsKey('updates'), isFalse);
    });

    test('an unknown connection id, or one of another account, is ignored: '
        "the response carries nothing — not that connection's channels — and "
        'no connection is relieved', () async {
      final (author, _) = await harness().signedIn('ignored-a@example.com');
      final (_, strangerSession) = await harness().signedIn(
        'ignored-s@example.com',
      );
      final stranger = await harness().live(token: strangerSession.token);
      expect(await stranger.subscribe('notes'), isA<DwSubscribedMessage>());

      for (final id in ['no-such-connection', stranger.connectionId]) {
        author.liveConnection = id;
        final answer = await author.call(CreateNote('ignored $id'));
        final note = answer.value(const CreateNote(''));
        expect(
          answer.updates.isEmpty,
          isTrue,
          reason:
              "naming someone else's connection must not borrow what "
              'it may read',
        );
        expect(
          (await stranger.expect<DwUpdateMessage>()).updates.objects,
          [note],
          reason: "naming someone else's connection must not silence it",
        );
      }
    });

    test('an anonymous connection is not bound to a signed-in caller: the '
        'response carries nothing and the socket hears nothing', () async {
      final (author, _) = await harness().signedIn('anon-bind@example.com');
      final anonymousSocket = await harness().live();
      author.liveConnection = anonymousSocket.connectionId;
      final answer = await author.call(const CreateNote('to all'));
      expect(answer.status, 200);
      expect(answer.updates.isEmpty, isTrue);
      expect((answer.json! as Map).containsKey('updates'), isFalse);
      await anonymousSocket.expectSilence();
    });

    test('a refused or failed transaction publishes nothing', () async {
      final (author, session) = await harness().signedIn(
        'rollback@example.com',
      );
      final (_, listenerSession) = await harness().signedIn(
        'rollback-l@example.com',
      );
      final listener = await harness().live(token: listenerSession.token);
      expect(await listener.subscribe('notes'), isA<DwSubscribedMessage>());
      final socket = await harness().live(token: session.token);
      author.liveConnection = socket.connectionId;
      expect((await author.call(const PublishAndEnd('refuse'))).status, 409);
      expect((await author.call(const PublishAndEnd('fail'))).status, 500);
      await listener.expectSilence();
      final rows = await harness().db.query(
        "SELECT count(*) AS n FROM note WHERE text IN ('refuse', 'fail')",
      );
      expect(rows.single['n'], 0);
    });

    test(
      'a non-transactional command that committed and then failed: its '
      'updates reach every subscriber over the socket, the named '
      'connection included, since the failed response carries none',
      () async {
        final (author, session) = await harness().signedIn(
          'committed@example.com',
        );
        final socket = await harness().live(token: session.token);
        expect(await socket.subscribe('notes'), isA<DwSubscribedMessage>());
        author.liveConnection = socket.connectionId;
        final answer = await author.call(const CountOutside('fail-after'));
        expect(answer.status, 500);
        final update = await socket.expect<DwUpdateMessage>();
        expect(
          (update.updates.objects.single as NoteView).text,
          'outside fail-after',
        );
      },
    );

    test('a revocation goes first: the revoked subscriber hears nothing of '
        'the same command, and a named author revoked from a channel gets '
        'only what it still listens to', () async {
      final (admin, adminSession) = await harness().signedIn(
        'revoker@example.com',
      );
      final adminSocket = await harness().live(token: adminSession.token);
      for (final channel in ['notes', 'public']) {
        expect(
          await adminSocket.subscribe(channel),
          isA<DwSubscribedMessage>(),
        );
      }
      admin.liveConnection = adminSocket.connectionId;
      final (_, victimSession) = await harness().signedIn('victim@example.com');
      final victim = await harness().live(token: victimSession.token);
      expect(await victim.subscribe('notes'), isA<DwSubscribedMessage>());

      final revokeVictim = await admin.call(RevokeNotes(victimSession.id));
      expect(revokeVictim.updates.channels.keys, ['notes', 'public']);
      expect((await victim.expect<DwChannelClosedMessage>()).channel, 'notes');
      await victim.expectSilence();

      final revokeSelf = await admin.call(RevokeNotes(adminSession.id));
      expect(
        (await adminSocket.expect<DwChannelClosedMessage>()).channel,
        'notes',
      );
      // The note went to `notes` and `public`; only `public` is still heard.
      expect(revokeSelf.updates.channels.keys, ['public']);
      final [note] = revokeSelf.updates.objectsOn('public');
      expect((note as NoteView).text, 'after revoke');
      await adminSocket.expectSilence();
    });

    test('a replayed command answers its result without updates', () async {
      final (author, session) = await harness().signedIn('replay@example.com');
      final socket = await harness().live(token: session.token);
      expect(await socket.subscribe('notes'), isA<DwSubscribedMessage>());
      author.liveConnection = socket.connectionId;
      final first = await author.call(const CreateNote('once'), key: 'rp');
      expect(first.updates.isEmpty, isFalse, reason: 'named and subscribed');
      final again = await author.call(const CreateNote('once'), key: 'rp');
      expect(
        again.value(const CreateNote('')),
        first.value(const CreateNote('')),
      );
      expect(again.updates.isEmpty, isTrue);
      expect(jsonDecode(again.text), isNot(contains('updates')));
      // The replay says so, and the first execution does not.
      expect(jsonDecode(again.text), containsPair('replayed', true));
      expect(jsonDecode(first.text), isNot(contains('replayed')));
      await socket.expectSilence();
    });
  });
}
