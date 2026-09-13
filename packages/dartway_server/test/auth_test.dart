import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartway_core/dartway_core.dart';
import 'package:dartway_server/testing.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  final harness = useHarness();
  late DwTestConnection connection;

  setUpAll(() async => connection = await harness().connect());

  TestApp app() => harness().app;

  Future<DwResultMessage> requestCode(
    String identifier, {
    DwIdentifierKind kind = DwIdentifierKind.email,
    DwTestConnection? on,
  }) => (on ?? connection).command(
    DwRequestCode(kind: kind, identifier: identifier),
  );

  DwCodeTicket ticketOf(DwResultMessage result) => result.okCommandValue(
    const DwRequestCode(kind: DwIdentifierKind.email, identifier: ''),
    testProtocol,
  );

  Future<DwResultMessage> verify(
    String ticketId,
    String code, {
    Map<String, String> registration = const {},
    DwTestConnection? on,
  }) => (on ?? connection).command(
    DwVerifyCode(ticketId: ticketId, code: code, registration: registration),
  );

  DwSession sessionOf(DwResultMessage result) => result.okCommandValue(
    const DwVerifyCode(ticketId: '', code: ''),
    testProtocol,
  );

  /// Moves the tickets of [identifier] into the past, past the resend delay.
  Future<void> age(String identifier, Duration by) => harness().db.execute(
    'UPDATE dw_code_ticket SET created_at = created_at - '
    '@by::int8 * interval \'1 microsecond\' WHERE identifier = @identifier',
    params: {'identifier': identifier, 'by': by.inMicroseconds},
  );

  test('a new identifier: code delivered, account and profile created in the '
      'sign-in transaction, session returned', () async {
    final ticketResult = await requestCode('  New@Example.com ');
    final ticket = ticketOf(ticketResult);
    expect(app().delivered.keys, contains('new@example.com'));
    expect(ticket.expiresAt.isAfter(DateTime.now()), isTrue);
    expect(
      ticket.resendAfter.difference(DateTime.now()).inSeconds,
      closeTo(30, 2),
    );
    final code = app().delivered['new@example.com']!;
    expect(code, matches(RegExp(r'^\d{6}$')));

    final session = sessionOf(
      await verify(ticket.id, code, registration: {'name': 'Ann'}),
    );
    expect(session.isNewAccount, isTrue);
    expect(app().createdAccounts, contains(session.id));
    final profile = await harness().db.query(
      'SELECT name, identifier FROM profile WHERE account_id = @id',
      params: {'id': session.id},
    );
    expect(profile.single['name'], 'Ann');
    expect(profile.single['identifier'], 'new@example.com');

    final authed = await connection.authenticate(session.token);
    expect(authed.accountId, session.id);
    expect(authed.rejected, isFalse);
    await connection.authenticate(null);
  });

  test(
    'an existing identifier signs into the same account, without the hook',
    () async {
      final first = await app().signIn(connection, 'again@example.com');
      await age('again@example.com', const Duration(minutes: 1));
      final created = app().createdAccounts.length;
      final second = await app().signIn(
        connection,
        'AGAIN@example.com',
        registration: {'name': 'ignored'},
      );
      expect(second.id, first.id);
      expect(second.isNewAccount, isFalse);
      expect(second.token, isNot(first.token));
      expect(app().createdAccounts.length, created);
      expect(
        jsonDecode(connection.frames.last),
        isNot(contains('isNewAccount')),
        reason: 'false is omitted on the wire',
      );
    },
  );

  test('an invalid identifier refuses on its field', () async {
    final result = await requestCode('not-an-email');
    expect(
      result.refusal,
      DwRefusal(DwCoreRefusal.invalid, field: 'identifier'),
    );
    final phone = await requestCode('12', kind: DwIdentifierKind.phone);
    expect(phone.refusal!.field, 'identifier');
  });

  test('the answer does not reveal whether an account exists', () async {
    await app().signIn(connection, 'exists@example.com');
    await age('exists@example.com', const Duration(minutes: 1));
    final known = await requestCode('exists@example.com');
    final unknown = await requestCode('nobody@example.com');
    Map<String, Object?> shape(DwResultMessage m) => {
      's': m.status.name,
      'keys': (m.value! as Map).keys.toList(),
    };
    expect(shape(known), shape(unknown));
  });

  test('resend delay and request window are enforced', () async {
    const id = 'limited@example.com';
    expect((await requestCode(id)).status, DwResultStatus.ok);
    final early = await requestCode(id);
    expect(early.refusal!.isCode(DwCoreRefusal.tooManyRequests), isTrue);
    expect(early.refusal!.retryAfter!.inSeconds, inInclusiveRange(28, 30));
    await age(id, const Duration(seconds: 31));
    expect((await requestCode(id)).status, DwResultStatus.ok);
    await age(id, const Duration(seconds: 31));
    expect((await requestCode(id)).status, DwResultStatus.ok);
    await age(id, const Duration(seconds: 31));
    // Three in the ten-minute window: the fourth waits for the oldest to age
    // out of it.
    final windowed = await requestCode(id);
    expect(windowed.refusal!.code, 'dw.tooManyRequests');
    expect(
      int.parse(windowed.refusal!.params['retryAfter']!),
      inInclusiveRange(600 - 94, 600 - 92),
    );
    expect(app().deliveredTo.where((i) => i == id), hasLength(3));
  });

  test(
    'parallel requests for one identifier are limited under a lock',
    () async {
      const id = 'race@example.com';
      final connections = [
        for (var i = 0; i < 6; i++) await harness().connect(),
      ];
      final results = await Future.wait([
        for (final c in connections) requestCode(id, on: c),
      ]);
      expect(results.where((r) => r.status == DwResultStatus.ok), hasLength(1));
      expect(
        results.where((r) => r.refusal?.code == 'dw.tooManyRequests'),
        hasLength(5),
      );
      for (final c in connections) {
        await c.close();
      }
    },
  );

  test('a failed delivery leaves no ticket and fails the call', () async {
    const id = 'down@example.com';
    app().failingDelivery.add(id);
    final result = await requestCode(id);
    expect(result.status, DwResultStatus.failed);
    final tickets = await harness().db.query(
      'SELECT count(*) AS n FROM dw_code_ticket WHERE identifier = @id',
      params: {'id': id},
    );
    expect(tickets.single['n'], 0);
    app().failingDelivery.remove(id);
    expect((await requestCode(id)).status, DwResultStatus.ok);
  });

  test(
    'wrong codes count attempts; the last attempt kills the ticket',
    () async {
      const id = 'guess@example.com';
      final ticket = ticketOf(await requestCode(id));
      final code = app().delivered[id]!;
      final wrong = code == '111111' ? '222222' : '111111';
      final first = await verify(ticket.id, wrong);
      expect(
        first.refusal,
        DwRefusal(
          DwCoreRefusal.invalid,
          field: 'code',
          params: {'attemptsLeft': 2},
        ),
      );
      final second = await verify(ticket.id, wrong);
      expect(second.refusal!.params['attemptsLeft'], '1');
      final third = await verify(ticket.id, wrong);
      expect(third.refusal!.code, 'dw.codeExpired');
      final right = await verify(ticket.id, code);
      expect(right.refusal!.code, 'dw.codeExpired');
    },
  );

  test(
    'an expired, a used and an unknown ticket all answer codeExpired',
    () async {
      const id = 'expire@example.com';
      final ticket = ticketOf(await requestCode(id));
      await harness().db.execute(
        "UPDATE dw_code_ticket SET expires_at = now() - interval '1 second' "
        'WHERE id = @id',
        params: {'id': ticket.id},
      );
      final expired = await verify(ticket.id, app().delivered[id]!);
      expect(expired.refusal!.code, 'dw.codeExpired');

      await age(id, const Duration(minutes: 1));
      final fresh = ticketOf(await requestCode(id));
      expect(
        (await verify(fresh.id, app().delivered[id]!)).status,
        DwResultStatus.ok,
      );
      final reused = await verify(fresh.id, app().delivered[id]!);
      expect(reused.refusal!.code, 'dw.codeExpired');

      expect(
        (await verify('no-such-ticket', '123456')).refusal!.code,
        'dw.codeExpired',
      );
    },
  );

  test('a fixed code skips delivery and signs in', () async {
    final deliveries = app().deliveredTo.length;
    final ticket = ticketOf(await requestCode(TestApp.reviewer));
    expect(app().deliveredTo.length, deliveries);
    final session = sessionOf(await verify(ticket.id, '000000'));
    expect(session.isNewAccount, isTrue);
  });

  test(
    'two tickets of one new identifier verified at once create one account',
    () async {
      const id = 'twice@example.com';
      final a = ticketOf(await requestCode(id));
      final codeA = app().delivered[id]!;
      await age(id, const Duration(minutes: 1));
      final b = ticketOf(await requestCode(id));
      final codeB = app().delivered[id]!;
      final other = await harness().connect();
      final results = await Future.wait([
        verify(a.id, codeA),
        verify(b.id, codeB, on: other),
      ]);
      final sessions = results.map(sessionOf).toList();
      expect(sessions[0].id, sessions[1].id);
      expect(sessions.where((s) => s.isNewAccount), hasLength(1));
      final identities = await harness().db.query(
        'SELECT count(*) AS n FROM dw_identity WHERE value = @id',
        params: {'id': id},
      );
      expect(identities.single['n'], 1);
      await other.close();
    },
  );

  test('tokens and codes are stored hashed and never logged; the session is '
      'not kept as a command outcome', () async {
    const id = 'secret@example.com';
    final ticket = ticketOf(await requestCode(id));
    final code = app().delivered[id]!;
    const key = 'verify-key-1';
    final result = await connection.command(
      DwVerifyCode(ticketId: ticket.id, code: code),
      key: key,
    );
    final session = sessionOf(result);

    final keys = await harness().db.query(
      'SELECT token_hash FROM dw_auth_key WHERE account_id = @id',
      params: {'id': session.id},
    );
    expect(
      keys.single.get<Uint8List>('token_hash'),
      sha256.convert(utf8.encode(session.token)).bytes,
    );
    final tickets = await harness().db.query(
      'SELECT code_hash FROM dw_code_ticket WHERE id = @id',
      params: {'id': ticket.id},
    );
    expect(
      tickets.single.get<Uint8List>('code_hash'),
      sha256.convert(utf8.encode('${ticket.id}:$code')).bytes,
    );
    final outcomes = await harness().db.query(
      'SELECT count(*) AS n FROM dw_command_outcome WHERE key = @key',
      params: {'key': key},
    );
    expect(outcomes.single['n'], 0);

    final everything = RecordingLogger.lines.join('\n');
    expect(everything, isNot(contains(session.token)));
    expect(everything, isNot(contains(ticket.id)));
    expect(everything, isNot(contains(code)));
  });
}
