import 'dart:convert';

import 'package:dartway_core/dartway_core.dart';
import 'package:dartway_server/testing.dart';
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
        final connection = await harness().connect();
        final first = await connection.command(
          const Count('repeat-ok'),
          key: 'r1',
        );
        final second = await connection.command(
          const Count('repeat-ok'),
          key: 'r1',
        );
        expect(first.value, 1);
        expect(second.status, DwResultStatus.ok);
        expect(second.value, 1);
        expect(await executions('repeat-ok'), 1);
        // Another connection of the same (anonymous) scope sees the same key.
        final other = await harness().connect();
        expect(
          (await other.command(const Count('repeat-ok'), key: 'r1')).value,
          1,
        );
        expect(await executions('repeat-ok'), 1);
        await connection.close();
        await other.close();
      },
    );

    test('a refusal is stored after the rollback and answered again', () async {
      final connection = await harness().connect();
      final first = await connection.command(
        const Count('repeat-refused', mode: 'refuse'),
        key: 'r2',
      );
      expect(
        first.refusal,
        DwRefusal(DwCoreRefusal.conflict, params: {'n': 1}),
      );
      // The handler's write rolled back with the refusal.
      expect(await executions('repeat-refused'), 0);
      final second = await connection.command(
        const Count('repeat-refused', mode: 'refuse'),
        key: 'r2',
      );
      expect(second.refusal, first.refusal);
      final stored = await harness().db.query(
        "SELECT status, type FROM dw_command_outcome WHERE key = 'r2'",
      );
      expect(stored.single['status'], 'refused');
      expect(stored.single['type'], 'Count');
      await connection.close();
    });

    test('a failure is not stored: the same key executes again', () async {
      final connection = await harness().connect();
      final first = await connection.command(
        const Count('retry-failed', mode: 'failOnce'),
        key: 'r3',
      );
      expect(first.status, DwResultStatus.failed);
      final second = await connection.command(
        const Count('retry-failed', mode: 'failOnce'),
        key: 'r3',
      );
      expect(second.value, 1, reason: 'the failed attempt rolled back');
      await connection.close();
    });

    test('a serialization failure re-runs the whole transaction', () async {
      final connection = await harness().connect();
      final incidents = harness().app.alerts.incidents.length;
      final result = await connection.command(
        const Count('conflicted', mode: 'conflictOnce'),
      );
      expect(result.status, DwResultStatus.ok);
      expect(result.value, 1, reason: 'the first attempt rolled back');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(harness().app.alerts.incidents.length, incidents);
      await connection.close();
    });

    test('the same key with another command type is a conflict', () async {
      final connection = await harness().connect();
      await connection.command(const Count('typed'), key: 'r4');
      final other = await connection.command(const Ping(), key: 'r4');
      expect(other.refusal!.isCode(DwCoreRefusal.conflict), isTrue);
      expect(other.refusal!.params, {'idempotencyKey': 'reused'});
      await connection.close();
    });

    test('keys are scoped by account', () async {
      final (a, _) = await harness().signedIn('scope-a@example.com');
      final (b, _) = await harness().signedIn('scope-b@example.com');
      expect((await a.command(const Count('scoped'), key: 'r5')).value, 1);
      expect((await b.command(const Count('scoped'), key: 'r5')).value, 2);
      final anonymous = await harness().connect();
      expect(
        (await anonymous.command(const Count('scoped'), key: 'r5')).value,
        3,
      );
      for (final c in [a, b, anonymous]) {
        await c.close();
      }
    });

    test('two sends of one key racing each other execute once', () async {
      final connections = [
        for (var i = 0; i < 4; i++) await harness().connect(),
      ];
      final results = await Future.wait([
        for (final c in connections) c.command(const Count('race'), key: 'r6'),
      ]);
      expect(results.map((r) => r.value), everyElement(1));
      expect(await executions('race'), 1);
      for (final c in connections) {
        await c.close();
      }
    });

    test(
      'a non-transactional command stores its outcome after the handler',
      () async {
        final connection = await harness().connect();
        expect(
          (await connection.command(
            const CountOutside('outside'),
            key: 'r7',
          )).value,
          1,
        );
        expect(
          (await connection.command(
            const CountOutside('outside'),
            key: 'r7',
          )).value,
          1,
        );
        expect(await executions('outside'), 1);
        await connection.close();
      },
    );

    test('an oversized key is a failure', () async {
      final connection = await harness().connect();
      final result = await connection.command(const Ping(), key: 'k' * 129);
      expect(result.status, DwResultStatus.failed);
      await connection.close();
    });
  });

  group('publishing', () {
    test(
      'delivered after commit to other connections, the author\'s own '
      'connection excluded, the author\'s other connections included',
      () async {
        final (author, session) = await harness().signedIn(
          'pub-author@example.com',
        );
        final authorOther = await harness().connect();
        await authorOther.authenticate(session.token);
        final (stranger, _) = await harness().signedIn(
          'pub-stranger@example.com',
        );
        for (final c in [author, authorOther, stranger]) {
          expect(await c.subscribe('notes'), isA<DwSubscribedMessage>());
        }
        final result = await author.command(const CreateNote('hello'));
        final note = result.okCommandValue(const CreateNote(''), testProtocol);

        for (final c in [authorOther, stranger]) {
          final update = await c.expect<DwUpdateMessage>();
          expect(update.channel, 'notes');
          expect(update.items, [note]);
        }
        await author.expectSilence();
        for (final c in [author, authorOther, stranger]) {
          await c.close();
        }
      },
    );

    test('one message per channel per connection; the latest state of an '
        'object travels once', () async {
      final (author, session) = await harness().signedIn('batch-a@example.com');
      final listener = await harness().connect();
      await listener.authenticate(session.token);
      expect(await listener.subscribe('notes'), isA<DwSubscribedMessage>());
      expect(
        await listener.subscribe('account:${session.id}'),
        isA<DwSubscribedMessage>(),
      );
      final frames = listener.frames.length;
      await author.command(const CreateNote('batched', extraPublishes: 2));
      final notes = await listener.expect<DwUpdateMessage>(
        where: (m) => m.channel == 'notes',
      );
      final account = await listener.expect<DwUpdateMessage>(
        where: (m) => m.channel == 'account:${session.id}',
      );
      expect(notes.items, hasLength(1));
      expect((notes.items.single as NoteView).text, 'batched #1');
      expect((account.items.single as NoteView).text, 'batched');
      await listener.expectSilence();
      expect(listener.frames.length - frames, 2);
      final wire = jsonDecode(listener.frames[frames]) as Map<String, Object?>;
      expect(wire.keys, unorderedEquals(['k', 'ch', 'items']));
      await author.close();
      await listener.close();
    });

    test('a refused or failed transaction publishes nothing', () async {
      final (author, _) = await harness().signedIn('rollback-a@example.com');
      final (listener, _) = await harness().signedIn('rollback-l@example.com');
      expect(await listener.subscribe('notes'), isA<DwSubscribedMessage>());
      expect(
        (await author.command(const PublishAndEnd('refuse'))).status,
        DwResultStatus.refused,
      );
      expect(
        (await author.command(const PublishAndEnd('fail'))).status,
        DwResultStatus.failed,
      );
      await listener.expectSilence();
      final rows = await harness().db.query(
        "SELECT count(*) AS n FROM note WHERE text IN ('refused', 'failed')",
      );
      expect(rows.single['n'], 0);
      await author.close();
      await listener.close();
    });

    test('outside a transactional command, what a committed transaction '
        'published is delivered even when the handler then fails', () async {
      final author = await harness().connect();
      final (listener, _) = await harness().signedIn('committed-l@example.com');
      expect(await listener.subscribe('notes'), isA<DwSubscribedMessage>());
      final result = await author.command(const CountOutside('fail-after'));
      expect(result.status, DwResultStatus.failed);
      final update = await listener.expect<DwUpdateMessage>();
      expect((update.items.single as NoteView).text, 'outside fail-after');
      await author.close();
      await listener.close();
    });
  });
}
