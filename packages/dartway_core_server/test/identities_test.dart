import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// Identities: listing them, attaching and changing one by one-time code
/// without signing in again, moving them for a merge, removing them — and the
/// hook that mirrors each change in the same transaction.
void main() {
  final harness = useHarness();

  TestApp app() => harness().app;
  DwAccountService accounts() => harness().server.server.accounts;

  const anyTicket = DwRequestIdentifierCode(
    kind: DwIdentifierKind.email,
    identifier: '',
  );
  const anyConfirm = DwConfirmIdentifier(ticketId: '', code: '');

  Future<DwTestAnswer> requestAttach(
    DwTestCaller caller,
    String identifier, {
    DwIdentifierKind kind = DwIdentifierKind.email,
  }) =>
      caller.call(DwRequestIdentifierCode(kind: kind, identifier: identifier));

  Future<DwTestAnswer> confirm(
    DwTestCaller caller,
    String ticketId,
    String code, {
    bool replace = false,
    String? key,
  }) => caller.call(
    DwConfirmIdentifier(ticketId: ticketId, code: code, replace: replace),
    key: key,
  );

  /// Requests and confirms [identifier] for [caller]; answers the identity.
  Future<DwIdentityInfo> attach(
    DwTestCaller caller,
    String identifier, {
    DwIdentifierKind kind = DwIdentifierKind.email,
    bool replace = false,
  }) async {
    final ticket = (await requestAttach(
      caller,
      identifier,
      kind: kind,
    )).value(anyTicket);
    return (await confirm(
      caller,
      ticket.id,
      app().delivered[identifier]!,
      replace: replace,
    )).value(anyConfirm);
  }

  /// Moves the tickets of [identifier] out of the resend delay and window.
  Future<void> age(String identifier) => harness().db.execute(
    "UPDATE dw_code_ticket SET created_at = created_at - interval '1 hour' "
    'WHERE identifier = @identifier',
    params: {'identifier': identifier},
  );

  Future<String> profileIdentifier(int accountId) async =>
      (await harness().db.query(
        'SELECT identifier FROM profile WHERE account_id = @id',
        params: {'id': accountId},
      )).single.get<String>('identifier');

  List<String> values(List<DwIdentityInfo> identities) => [
    for (final identity in identities)
      '${identity.kind.name}:${identity.value}',
  ];

  group('listing', () {
    test('a sign-in verifies its identifier; a tool\'s is not verified until '
        'it signs in; many accounts in one call', () async {
      final (_, session) = await harness().signedIn('listed@example.com');
      final signedIn = (await accounts().listIdentities(session.id)).single;
      expect(signedIn.accountId, session.id);
      expect(signedIn.kind, DwIdentifierKind.email);
      expect(signedIn.value, 'listed@example.com');
      expect(signedIn.verifiedAt, isNotNull);

      final tool = await accounts().ensure(
        DwIdentifierKind.phone,
        '+15550002222',
      );
      expect(
        (await accounts().listIdentities(tool.accountId)).single.verifiedAt,
        isNull,
      );
      await app().signIn(
        harness().caller(),
        '+15550002222',
        kind: DwIdentifierKind.phone,
      );
      final verified = (await accounts().listIdentities(tool.accountId)).single;
      expect(verified.verifiedAt, isNotNull);
      expect(verified.id, isNot(signedIn.id));

      final both = await accounts().listIdentitiesOf([
        session.id,
        tool.accountId,
        987654321,
      ]);
      expect(
        both.keys,
        unorderedEquals([session.id, tool.accountId, 987654321]),
      );
      expect(values(both[session.id]!), ['email:listed@example.com']);
      expect(values(both[tool.accountId]!), ['phone:+15550002222']);
      expect(both[987654321], isEmpty);
      expect(await accounts().listIdentitiesOf(const []), isEmpty);
    });

    test('accountsMatching finds by a fragment, ignoring case, with LIKE '
        'characters literal and kinds narrowing', () async {
      final a = await accounts().ensure(
        DwIdentifierKind.email,
        'match_100%@example.com',
      );
      final b = await accounts().ensure(
        DwIdentifierKind.email,
        'matchX100@example.com',
      );
      final c = await accounts().ensure(DwIdentifierKind.phone, '+15551001000');
      expect(await accounts().accountsMatching('MATCH_100%'), {a.accountId});
      expect(
        await accounts().accountsMatching('100'),
        containsAll([a.accountId, b.accountId, c.accountId]),
      );
      final phones = await accounts().accountsMatching(
        '100',
        kinds: {DwIdentifierKind.phone},
      );
      expect(phones, contains(c.accountId));
      expect(phones, isNot(contains(a.accountId)));
      expect(() => accounts().accountsMatching(''), throwsArgumentError);
    });
  });

  group('attach by code', () {
    test(
      'a signed-in caller attaches a second identifier without signing in '
      'again: the code goes out as for a sign-in, the hook mirrors it in '
      'the same transaction, and the identifier signs in to the account',
      () async {
        final (caller, session) = await harness().signedIn('owner@example.com');
        final ticket = (await requestAttach(
          caller,
          ' +15550003333 ',
          kind: DwIdentifierKind.phone,
        )).value(anyTicket);
        expect(app().codeCallers['+15550003333'], session.id);
        final changes = app().identifierChanges.length;

        final identity = (await confirm(
          caller,
          ticket.id,
          app().delivered['+15550003333']!,
        )).value(anyConfirm);
        expect(identity.accountId, session.id);
        expect(identity.kind, DwIdentifierKind.phone);
        expect(identity.value, '+15550003333');
        expect(identity.verifiedAt, isNotNull);
        expect(values(await accounts().listIdentities(session.id)), [
          'email:owner@example.com',
          'phone:+15550003333',
        ]);
        expect(
          app().identifierChanges.skip(changes).single,
          isA<DwIdentifierChange>()
              .having((c) => c.accountId, 'account', session.id)
              .having(
                (c) => c.cause,
                'cause',
                DwIdentifierChangeCause.confirmed,
              )
              .having((c) => c.previous, 'previous', isNull)
              .having((c) => c.current, 'current', '+15550003333'),
        );
        expect(await profileIdentifier(session.id), '+15550003333');

        await age('+15550003333');
        final again = await app().signIn(
          harness().caller(),
          '+15550003333',
          kind: DwIdentifierKind.phone,
        );
        expect((again.id, again.isNewAccount), (session.id, false));
      },
    );

    test('replace changes the identifier in place: the old one is free, the '
        'identity keeps its id', () async {
      final (caller, session) = await harness().signedIn('old@example.com');
      final before = (await accounts().listIdentities(session.id)).single;
      final changes = app().identifierChanges.length;
      final replaced = await attach(caller, 'new@example.com', replace: true);
      expect(replaced.id, before.id);
      expect(replaced.value, 'new@example.com');
      expect(values(await accounts().listIdentities(session.id)), [
        'email:new@example.com',
      ]);
      expect(
        await accounts().find(DwIdentifierKind.email, 'old@example.com'),
        isNull,
      );
      final change = app().identifierChanges.skip(changes).single;
      expect(
        (change.previous, change.current),
        ('old@example.com', 'new@example.com'),
      );
      expect(await profileIdentifier(session.id), 'new@example.com');

      // Without replace, a second identifier of the kind joins the first.
      await attach(caller, 'second@example.com');
      expect(values(await accounts().listIdentities(session.id)), [
        'email:new@example.com',
        'email:second@example.com',
      ]);
      // Replacing with one the account has keeps it and drops the others.
      await age('second@example.com');
      final kept = await attach(caller, 'second@example.com', replace: true);
      expect(values(await accounts().listIdentities(session.id)), [
        'email:second@example.com',
      ]);
      expect(kept.verifiedAt, isNotNull);
    });

    test('an identifier of another account is refused only once its code is '
        'right: the request looks the same as for a free one, the ticket is '
        'used, nothing changes', () async {
      final (caller, session) = await harness().signedIn('taker@example.com');
      final (_, other) = await harness().signedIn('taken@example.com');
      await age('taken@example.com');

      final taken = await requestAttach(caller, 'taken@example.com');
      final free = await requestAttach(caller, 'free-one@example.com');
      String shape(DwTestAnswer a) =>
          '${a.status} ${((a.json! as Map)['result'] as Map).keys.join(',')}';
      expect(shape(taken), shape(free));

      final ticket = taken.value(anyTicket);
      final code = app().delivered['taken@example.com']!;
      final wrong = await confirm(
        caller,
        ticket.id,
        code == '111111' ? '222222' : '111111',
      );
      expect(
        wrong.refusal.code,
        DwCoreRefusal.invalid.code,
        reason: 'a wrong code says nothing about the owner',
      );
      final refused = await confirm(caller, ticket.id, code);
      expect(refused.status, 422);
      expect(
        refused.refusal,
        DwCallRefusal(DwAuthRefusal.identifierTaken, field: 'code'),
      );
      expect(
        (await confirm(caller, ticket.id, code)).refusal.code,
        DwCoreRefusal.codeExpired.code,
      );
      expect(values(await accounts().listIdentities(session.id)), [
        'email:taker@example.com',
      ]);
      expect(values(await accounts().listIdentities(other.id)), [
        'email:taken@example.com',
      ]);
    });

    test('a ticket is confirmed only by its own purpose and account', () async {
      final (alice, _) = await harness().signedIn('alice-ticket@example.com');
      final (bob, _) = await harness().signedIn('bob-ticket@example.com');
      final attachTicket = (await requestAttach(
        alice,
        'purpose@example.com',
      )).value(anyTicket);
      final code = app().delivered['purpose@example.com']!;

      // Someone else's ticket reads as unknown and burns none of its attempts.
      for (var i = 0; i < 5; i++) {
        expect(
          (await confirm(bob, attachTicket.id, code)).refusal.code,
          DwCoreRefusal.codeExpired.code,
        );
      }
      // An attach ticket does not sign in.
      final verify = DwVerifyCode(ticketId: attachTicket.id, code: code);
      expect(
        (await harness().caller().call(verify)).refusal.code,
        DwCoreRefusal.codeExpired.code,
      );
      // Still good for its owner.
      expect((await confirm(alice, attachTicket.id, code)).status, 200);

      // A sign-in ticket does not attach.
      const request = DwRequestCode(
        kind: DwIdentifierKind.email,
        identifier: 'signin-ticket@example.com',
      );
      final signInTicket = (await harness().caller().call(
        request,
      )).value(request);
      expect(
        (await confirm(
          alice,
          signInTicket.id,
          app().delivered['signin-ticket@example.com']!,
        )).refusal.code,
        DwCoreRefusal.codeExpired.code,
      );
    });

    test('limits and attempts are sign-in\'s: one window per identifier '
        'across both, wrong codes counted per ticket', () async {
      final (caller, _) = await harness().signedIn('limits@example.com');
      const id = 'limited-attach@example.com';
      const signIn = DwRequestCode(
        kind: DwIdentifierKind.email,
        identifier: id,
      );
      expect((await harness().caller().call(signIn)).status, 200);
      final early = await requestAttach(caller, id);
      expect(early.status, 429, reason: 'the sign-in request counts');
      expect(early.refusal.retryAfter!.inSeconds, inInclusiveRange(28, 30));
      await age(id);

      final ticket = (await requestAttach(caller, id)).value(anyTicket);
      final code = app().delivered[id]!;
      final wrong = code == '111111' ? '222222' : '111111';
      expect(
        (await confirm(
          caller,
          ticket.id,
          wrong,
        )).refusal.params['attemptsLeft'],
        '2',
      );
      expect(
        (await confirm(
          caller,
          ticket.id,
          wrong,
        )).refusal.params['attemptsLeft'],
        '1',
      );
      expect(
        (await confirm(caller, ticket.id, wrong)).refusal.code,
        DwCoreRefusal.codeExpired.code,
      );
      expect(
        (await confirm(caller, ticket.id, code)).refusal.code,
        DwCoreRefusal.codeExpired.code,
      );

      final invalid = await requestAttach(caller, 'no-at-sign');
      expect(
        invalid.refusal,
        DwCallRefusal(DwCoreRefusal.invalid, field: 'identifier'),
      );
      expect((await requestAttach(harness().caller(), id)).status, 401);
    });

    test('a fixed code (generateCode) applies, and both it and deliverCode see '
        'the attaching caller', () async {
      final (caller, session) = await harness().signedIn('fixed@example.com');
      final deliveries = app().deliveredTo.length;
      final ticket = (await requestAttach(
        caller,
        TestApp.reviewer,
      )).value(anyTicket);
      expect(app().deliveredTo.length, deliveries, reason: 'not delivered');
      expect(app().generateCodeCallers[TestApp.reviewer], session.id);
      expect(app().codeCallers[TestApp.reviewer], session.id);
      final identity = (await confirm(
        caller,
        ticket.id,
        '000000',
      )).value(anyConfirm);
      expect(identity.value, TestApp.reviewer);
    });

    test(
      'a hook that throws undoes the change and leaves the ticket usable',
      () async {
        final (caller, session) = await harness().signedIn(
          'rollback@example.com',
        );
        const id = 'mirror-down@example.com';
        app().failingIdentifierChanges.add(id);
        final ticket = (await requestAttach(caller, id)).value(anyTicket);
        final code = app().delivered[id]!;
        expect((await confirm(caller, ticket.id, code)).status, 500);
        expect(values(await accounts().listIdentities(session.id)), [
          'email:rollback@example.com',
        ]);
        expect(
          await profileIdentifier(session.id),
          'rollback@example.com',
          reason: 'the hook\'s own write rolled back with it',
        );

        app().failingIdentifierChanges.remove(id);
        expect((await confirm(caller, ticket.id, code)).status, 200);
        expect(await profileIdentifier(session.id), id);
      },
    );

    test(
      'a confirmation sent twice with one key answers the same identity',
      () async {
        final (caller, _) = await harness().signedIn(
          'twice-confirm@example.com',
        );
        const id = 'replayed@example.com';
        final ticket = (await requestAttach(caller, id)).value(anyTicket);
        final code = app().delivered[id]!;
        final first = await confirm(caller, ticket.id, code, key: 'confirm-1');
        final second = await confirm(caller, ticket.id, code, key: 'confirm-1');
        expect(second.value(anyConfirm), first.value(anyConfirm));
        expect((second.response as DwApiOk).replayed, isTrue);
      },
    );

    test('an attach and a sign-in of one new identifier at once: one account '
        'ends up with it', () async {
      final (caller, session) = await harness().signedIn('racer@example.com');
      const id = 'contested@example.com';
      final attachTicket = (await requestAttach(caller, id)).value(anyTicket);
      final attachCode = app().delivered[id]!;
      await age(id);
      const request = DwRequestCode(
        kind: DwIdentifierKind.email,
        identifier: id,
      );
      final anonymous = harness().caller();
      final signInTicket = (await anonymous.call(request)).value(request);
      final signInCode = app().delivered[id]!;

      final verify = DwVerifyCode(ticketId: signInTicket.id, code: signInCode);
      final [attached, signedIn] = await Future.wait([
        confirm(caller, attachTicket.id, attachCode),
        anonymous.call(verify),
      ]);
      final signInSession = signedIn.value(verify);
      final owner = await accounts().find(DwIdentifierKind.email, id);
      if (attached.status == 200) {
        expect(owner, session.id);
        expect(signInSession.id, session.id);
        expect(signInSession.isNewAccount, isFalse);
      } else {
        expect(attached.refusal.code, DwAuthRefusal.identifierTaken.code);
        expect(owner, signInSession.id);
        expect(signInSession.isNewAccount, isTrue);
      }
      final rows = await harness().db.query(
        'SELECT count(*) AS n FROM dw_identity WHERE value = @id',
        params: {'id': id},
      );
      expect(rows.single['n'], 1);
    });
  });

  group('move and remove', () {
    test('moveIdentities moves the chosen kinds in one transaction, runs the '
        'hook on both accounts and revokes nothing', () async {
      final (fromCaller, from) = await harness().signedIn('merged@example.com');
      await attach(fromCaller, '+15550004444', kind: DwIdentifierKind.phone);
      final (_, to) = await harness().signedIn('primary@example.com');
      final changes = app().identifierChanges.length;

      final moved = await accounts().moveIdentities(
        from.id,
        to.id,
        kinds: {DwIdentifierKind.phone},
      );
      expect(values(moved), ['phone:+15550004444']);
      expect(moved.single.accountId, to.id);
      expect(values(await accounts().listIdentities(from.id)), [
        'email:merged@example.com',
      ]);
      // Oldest first: the moved identity keeps its id, and its age.
      expect(values(await accounts().listIdentities(to.id)), [
        'phone:+15550004444',
        'email:primary@example.com',
      ]);
      expect(
        [
          for (final c in app().identifierChanges.skip(changes))
            (c.accountId, c.cause, c.previous, c.current),
        ],
        [
          (from.id, DwIdentifierChangeCause.moved, '+15550004444', null),
          (to.id, DwIdentifierChangeCause.moved, null, '+15550004444'),
        ],
      );
      expect((await fromCaller.call(const MyNotes())).status, 200);
      await age('+15550004444');
      final signIn = await app().signIn(
        harness().caller(),
        '+15550004444',
        kind: DwIdentifierKind.phone,
      );
      expect(signIn.id, to.id);

      expect(
        await accounts().moveIdentities(
          from.id,
          to.id,
          kinds: {DwIdentifierKind.phone},
        ),
        isEmpty,
      );
      expect(
        () => accounts().moveIdentities(to.id, to.id),
        throwsArgumentError,
      );
      await expectLater(
        accounts().moveIdentities(from.id, 987654321),
        throwsArgumentError,
      );
    });

    test('a hook that throws undoes the whole move', () async {
      final (_, from) = await harness().signedIn('move-fails@example.com');
      final (_, to) = await harness().signedIn('move-target@example.com');
      app().failingIdentifierChanges.add('move-fails@example.com');
      await expectLater(
        accounts().moveIdentities(from.id, to.id),
        throwsStateError,
      );
      app().failingIdentifierChanges.remove('move-fails@example.com');
      expect(values(await accounts().listIdentities(from.id)), [
        'email:move-fails@example.com',
      ]);
    });

    test('removeIdentities frees identifiers: a later sign-in makes a new '
        'account', () async {
      final (_, session) = await harness().signedIn('removed@example.com');
      final changes = app().identifierChanges.length;
      final removed = await accounts().removeIdentities(session.id);
      expect(values(removed), ['email:removed@example.com']);
      expect(await accounts().listIdentities(session.id), isEmpty);
      final change = app().identifierChanges.skip(changes).single;
      expect(
        (change.cause, change.previous, change.current),
        (DwIdentifierChangeCause.removed, 'removed@example.com', null),
      );
      await age('removed@example.com');
      final fresh = await app().signIn(
        harness().caller(),
        'removed@example.com',
      );
      expect(fresh.id, isNot(session.id));
      expect(fresh.isNewAccount, isTrue);
    });

    test('inside a caller\'s transaction a move rolls back with it', () async {
      final (_, from) = await harness().signedIn('ctx-move@example.com');
      final (_, to) = await harness().signedIn('ctx-move-to@example.com');
      await expectLater(
        harness().db.transaction((tx) async {
          await DwAccountService(
            tx,
            app().auth(),
          ).moveIdentities(from.id, to.id);
          throw StateError('rolled back');
        }),
        throwsStateError,
      );
      expect(values(await accounts().listIdentities(from.id)), [
        'email:ctx-move@example.com',
      ]);
    });
  });
}
