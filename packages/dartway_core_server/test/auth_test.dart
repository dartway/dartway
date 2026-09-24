import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// Sign-in by one-time code, over HTTP.
void main() {
  final harness = useHarness();
  late DwTestCaller caller;

  setUpAll(() => caller = harness().caller());

  TestApp app() => harness().app;

  const anyRequest = DwRequestCode(
    kind: DwIdentifierKind.email,
    identifier: '',
  );
  const anyVerify = DwVerifyCode(ticketId: '', code: '');

  Future<DwTestAnswer> requestCode(
    String identifier, {
    DwIdentifierKind kind = DwIdentifierKind.email,
    DwTestCaller? on,
  }) => (on ?? caller).call(DwRequestCode(kind: kind, identifier: identifier));

  Future<DwTestAnswer> verify(
    String ticketId,
    String code, {
    Map<String, String> registration = const {},
    DwTestCaller? on,
    String? key,
  }) => (on ?? caller).call(
    DwVerifyCode(ticketId: ticketId, code: code, registration: registration),
    key: key,
  );

  /// Moves the tickets of [identifier] into the past.
  Future<void> age(String identifier, Duration by) => harness().db.execute(
    'UPDATE dw_code_ticket SET created_at = created_at - '
    '@by::int8 * interval \'1 microsecond\' WHERE identifier = @identifier',
    params: {'identifier': identifier, 'by': by.inMicroseconds},
  );

  test('a new identifier: code delivered, account and profile created in the '
      'sign-in transaction, a session that authenticates calls', () async {
    final ticket = (await requestCode('  New@Example.com ')).value(anyRequest);
    expect(app().delivered.keys, contains('new@example.com'));
    expect(ticket.expiresAt.isAfter(DateTime.now()), isTrue);
    expect(
      ticket.resendAfter.difference(DateTime.now()).inSeconds,
      closeTo(30, 2),
    );
    final code = app().delivered['new@example.com']!;
    expect(code, matches(RegExp(r'^\d{6}$')));

    final session = (await verify(
      ticket.id,
      code,
      registration: {'name': 'Ann'},
    )).value(anyVerify);
    expect(session.isNewAccount, isTrue);
    expect(app().createdAccounts, contains(session.id));
    expect(
      app().accountOrigins[session.id],
      isA<DwSignInOrigin>().having(
        (origin) => origin.registration,
        'registration',
        {'name': 'Ann'},
      ),
    );
    final profile = await harness().db.query(
      'SELECT name, identifier FROM profile WHERE account_id = @id',
      params: {'id': session.id},
    );
    expect(profile.single['name'], 'Ann');
    expect(profile.single['identifier'], 'new@example.com');

    final signed = harness().caller(token: session.token);
    expect(
      (await signed.call(const NeedsAccount())).value(const NeedsAccount()),
      session.id,
    );
  });

  test('an existing identifier signs into the same account, without the '
      'hook, with a new token', () async {
    final first = await app().signIn(caller, 'again@example.com');
    await age('again@example.com', const Duration(minutes: 1));
    final created = app().createdAccounts.length;
    final second = await app().signIn(
      caller,
      'AGAIN@example.com',
      registration: {'name': 'ignored'},
    );
    expect(second.id, first.id);
    expect(second.isNewAccount, isFalse);
    expect(second.token, isNot(first.token));
    expect(app().createdAccounts.length, created);
  });

  test('an invalid identifier refuses on its field', () async {
    final email = await requestCode('not-an-email');
    expect(email.status, 422);
    expect(
      email.refusal,
      DwCallRefusal(DwCoreRefusal.invalid, field: 'identifier'),
    );
    final phone = await requestCode('12', kind: DwIdentifierKind.phone);
    expect(phone.refusal.field, 'identifier');
  });

  test('the answer does not reveal whether an account exists', () async {
    await app().signIn(caller, 'exists@example.com');
    await age('exists@example.com', const Duration(minutes: 1));
    final known = await requestCode('exists@example.com');
    final unknown = await requestCode('nobody@example.com');
    String shape(DwTestAnswer a) =>
        '${a.status} ${((a.json! as Map)['result'] as Map).keys.join(',')}';
    expect(shape(known), shape(unknown));
  });

  test('resend delay and request window are enforced', () async {
    const id = 'limited@example.com';
    expect((await requestCode(id)).status, 200);
    final early = await requestCode(id);
    expect(early.status, 429);
    expect(early.refusal.retryAfter!.inSeconds, inInclusiveRange(28, 30));
    await age(id, const Duration(seconds: 31));
    expect((await requestCode(id)).status, 200);
    await age(id, const Duration(seconds: 31));
    expect((await requestCode(id)).status, 200);
    await age(id, const Duration(seconds: 31));
    // Three in the ten-minute window: the fourth waits for the oldest to age
    // out of it.
    final windowed = await requestCode(id);
    expect(windowed.status, 429);
    expect(
      int.parse(windowed.headers.value('retry-after')!),
      inInclusiveRange(600 - 94, 600 - 92),
    );
    expect(app().deliveredTo.where((i) => i == id), hasLength(3));
  });

  test('generateCode does not run when the request is refused by the resend '
      'delay or by the window — the limit is checked first', () async {
    const id = 'genlimit@example.com';
    expect((await requestCode(id)).status, 200);
    final afterFirst = app().generateCodeCalls;
    // Too soon for a resend.
    expect((await requestCode(id)).status, 429);
    expect(app().generateCodeCalls, afterFirst);

    await age(id, const Duration(seconds: 31));
    expect((await requestCode(id)).status, 200);
    await age(id, const Duration(seconds: 31));
    expect((await requestCode(id)).status, 200);
    final afterThree = app().generateCodeCalls;
    expect(afterThree, afterFirst + 2);

    // Three in the window: the fourth is refused before generateCode runs.
    await age(id, const Duration(seconds: 31));
    expect((await requestCode(id)).status, 429);
    expect(app().generateCodeCalls, afterThree);
  });

  test(
    'parallel requests for one identifier are limited under a lock',
    () async {
      const id = 'race@example.com';
      final answers = await Future.wait([
        for (var i = 0; i < 6; i++) requestCode(id, on: harness().caller()),
      ]);
      expect(answers.where((a) => a.status == 200), hasLength(1));
      expect(answers.where((a) => a.status == 429), hasLength(5));
    },
  );

  test('a failed delivery leaves its ticket — real and already counted '
      'against the limit — and fails the call', () async {
    const id = 'down@example.com';
    app().failingDelivery.add(id);
    expect((await requestCode(id)).status, 500);
    final tickets = await harness().db.query(
      'SELECT count(*) AS n FROM dw_code_ticket WHERE identifier = @id',
      params: {'id': id},
    );
    expect(
      tickets.single['n'],
      1,
      reason:
          'the ticket is written before deliverCode runs, so delivery '
          'throwing does not undo it — deliverCode runs after that '
          'transaction has committed',
    );
    // Too soon for a resend: the failed attempt still counts, the same
    // as a successful one would.
    expect((await requestCode(id)).status, 429);
    app().failingDelivery.remove(id);
    await age(id, const Duration(seconds: 31));
    expect((await requestCode(id)).status, 200);
  });

  test(
    'wrong codes count attempts; the last attempt kills the ticket',
    () async {
      const id = 'guess@example.com';
      final ticket = (await requestCode(id)).value(anyRequest);
      final code = app().delivered[id]!;
      final wrong = code == '111111' ? '222222' : '111111';
      final first = await verify(ticket.id, wrong);
      expect(first.status, 422);
      expect(
        first.refusal,
        DwCallRefusal(
          DwCoreRefusal.invalid,
          field: 'code',
          params: {'attemptsLeft': 2},
        ),
      );
      expect(
        (await verify(ticket.id, wrong)).refusal.params['attemptsLeft'],
        '1',
      );
      expect((await verify(ticket.id, wrong)).refusal.code, 'dw.codeExpired');
      expect((await verify(ticket.id, code)).refusal.code, 'dw.codeExpired');
    },
  );

  test(
    'an expired, a used and an unknown ticket all answer codeExpired',
    () async {
      const id = 'expire@example.com';
      final ticket = (await requestCode(id)).value(anyRequest);
      await harness().db.execute(
        "UPDATE dw_code_ticket SET expires_at = now() - interval '1 second' "
        'WHERE id = @id',
        params: {'id': ticket.id},
      );
      expect(
        (await verify(ticket.id, app().delivered[id]!)).refusal.code,
        'dw.codeExpired',
      );
      await age(id, const Duration(minutes: 1));
      final fresh = (await requestCode(id)).value(anyRequest);
      expect((await verify(fresh.id, app().delivered[id]!)).status, 200);
      expect(
        (await verify(fresh.id, app().delivered[id]!)).refusal.code,
        'dw.codeExpired',
      );
      expect(
        (await verify('no-such-ticket', '123456')).refusal.code,
        'dw.codeExpired',
      );
    },
  );

  test('a fixed code can skip delivery — deliverCode decides, not the '
      'framework', () async {
    final deliveries = app().deliveredTo.length;
    final ticket = (await requestCode(TestApp.reviewer)).value(anyRequest);
    expect(app().deliveredTo.length, deliveries);
    final session = (await verify(ticket.id, '000000')).value(anyVerify);
    expect(session.isNewAccount, isTrue);
    expect(
      app().accountOrigins[session.id],
      isA<DwSignInOrigin>().having(
        (origin) => origin.registration,
        'registration',
        isEmpty,
      ),
      reason: 'a sign-up that sent nothing is still a sign-in',
    );
  });

  test('a fixed code can also be delivered — generateCode and deliverCode are '
      'independent (issue #310)', () async {
    final ticket = (await requestCode(TestApp.reviewerSent)).value(anyRequest);
    expect(app().deliveredTo, contains(TestApp.reviewerSent));
    expect(app().delivered[TestApp.reviewerSent], '111111');
    final session = (await verify(ticket.id, '111111')).value(anyVerify);
    expect(session.isNewAccount, isTrue);
  });

  test('dwRandomCode draws digits-only codes of the requested length', () {
    // Deterministic: a format check, not a claim about randomness — nothing
    // here can fail while the generator is correct, whatever it draws.
    for (final length in [4, 6, 8, 12]) {
      for (var i = 0; i < 50; i++) {
        expect(dwRandomCode(length), matches(RegExp('^\\d{$length}\$')));
      }
    }
  });

  test('dwRandomCode is not stuck on one value', () {
    // Not "no two of N collide" — with a 6-digit code that has a real, if
    // small, chance of failing on entirely correct code (the birthday bound
    // on 20 draws over 10^6 outcomes is already worth avoiding). Drawing far
    // more and asking only for more than one distinct value keeps the same
    // intent — the generator is not returning a constant — at a false-failure
    // probability indistinguishable from zero.
    final codes = {for (var i = 0; i < 300; i++) dwRandomCode(6)};
    expect(codes.length, greaterThan(1));
  });

  test('a project that sets no generateCode at all gets a random code of '
      "codeLength digits, through the real server's default path", () async {
    // TestApp's own `generateCode` is always set (it needs to answer
    // `reviewer`/`reviewerSent`, and everyone else gets `null`, which
    // already exercises the framework's fallback — see the two tests
    // above). What TestApp cannot exercise is `auth.generateCode` being
    // unset entirely, so this builds a server with a `DwAuthConfig` of its
    // own: no `generateCode` field at all, and a `codeLength` (8) that is
    // not TestApp's default (6) — proving the fallback reads `codeLength`
    // itself rather than a length baked in somewhere.
    final testApp = TestApp();
    final delivered = <String, String>{};
    final isolated = await Harness.start(
      app: testApp,
      build: (app, config) => app.server(
        config,
        auth: DwAuthConfig(
          normalize: (kind, raw) => raw.trim().toLowerCase(),
          deliverCode: (ctx, kind, identifier, code, accountId) async {
            delivered[identifier] = code;
          },
          codeLength: 8,
        ),
      ),
    );
    try {
      final isolatedCaller = isolated.caller();
      final codes = <String>{};
      for (var i = 0; i < 5; i++) {
        final identifier = 'nogenerate$i@example.com';
        (await isolatedCaller.call(
          DwRequestCode(kind: DwIdentifierKind.email, identifier: identifier),
        )).value(anyRequest);
        final code = delivered[identifier]!;
        expect(code, matches(RegExp(r'^\d{8}$')));
        codes.add(code);
      }
      expect(codes.length, greaterThan(1));
    } finally {
      await isolated.stop();
    }
  });

  test('two tickets of one new identifier verified at once create one '
      'account', () async {
    const id = 'twice@example.com';
    final a = (await requestCode(id)).value(anyRequest);
    final codeA = app().delivered[id]!;
    await age(id, const Duration(minutes: 1));
    final b = (await requestCode(id)).value(anyRequest);
    final codeB = app().delivered[id]!;
    final sessions = [
      for (final answer in await Future.wait([
        verify(a.id, codeA),
        verify(b.id, codeB, on: harness().caller()),
      ]))
        answer.value(anyVerify),
    ];
    expect(sessions[0].id, sessions[1].id);
    expect(sessions.where((s) => s.isNewAccount), hasLength(1));
    final identities = await harness().db.query(
      'SELECT count(*) AS n FROM dw_identity WHERE value = @id',
      params: {'id': id},
    );
    expect(identities.single['n'], 1);
  });

  test('tokens and codes are stored hashed and never logged; the session is '
      'not kept as a command outcome', () async {
    const id = 'secret@example.com';
    final ticket = (await requestCode(id)).value(anyRequest);
    final code = app().delivered[id]!;
    const key = 'verify-key-1';
    final session = (await verify(ticket.id, code, key: key)).value(anyVerify);

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

    // A token in use goes through the log only as nothing.
    await harness().caller(token: session.token).call(const MyNotes());
    final everything = RecordingLogger.lines.join('\n');
    expect(everything, isNot(contains(session.token)));
    expect(everything, isNot(contains(ticket.id)));
    expect(everything, isNot(contains(code)));
  });

  test('sign-out without a session is unauthenticated', () async {
    expect((await caller.call(const DwSignOut())).status, 401);
  });
}
