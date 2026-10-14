import 'dart:async';

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
    for (final identity in identities) '${identity.kindName}:${identity.value}',
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

  group('provider identities (#355)', () {
    // On master, `DwAuthStore.identityOf` parses `dw_identity.kind` with
    // `DwIdentifierKind.values.byName`, which throws `ArgumentError` the
    // moment a row's kind is a provider's name (`google`, `apple`) rather
    // than `phone` or `email` — every reader below threw it. Merging a
    // provider-only account into one with a code identifier, as this test
    // does, is the shortest way to put both kinds of row on one account
    // without raw SQL on `dw_identity`.
    test('an account with an e-mail and a Google identity: listing, moving '
        '(kinds null and kinds={email}) and removing all work, and the hook '
        'sees the provider identity too', () async {
      final (_, mixed) = await harness().signedIn('mixed@example.com');
      final google = await accounts().signInWithExternalIdentity(
        provider: 'google',
        subject: 'google-mixed-1',
      );
      expect(google.isNewAccount, isTrue);

      final changes = app().identifierChanges.length;
      final moved = await accounts().moveIdentities(google.id, mixed.id);
      expect(moved, hasLength(1));
      expect(moved.single.provider, 'google');
      expect(moved.single.kind, isNull);
      expect(moved.single.value, 'google-mixed-1');
      expect(
        [
          for (final c in app().identifierChanges.skip(changes))
            (
              accountId: c.accountId,
              provider: c.provider,
              kind: c.kind,
              cause: c.cause,
            ),
        ],
        [
          (
            accountId: google.id,
            provider: 'google',
            kind: null,
            cause: DwIdentifierChangeCause.moved,
          ),
          (
            accountId: mixed.id,
            provider: 'google',
            kind: null,
            cause: DwIdentifierChangeCause.moved,
          ),
        ],
      );

      // listIdentities and listIdentitiesOf read both kinds of row.
      expect(values(await accounts().listIdentities(mixed.id)), [
        'email:mixed@example.com',
        'google:google-mixed-1',
      ]);
      final both = await accounts().listIdentitiesOf([mixed.id, 987654321]);
      expect(values(both[mixed.id]!), [
        'email:mixed@example.com',
        'google:google-mixed-1',
      ]);
      expect(both[987654321], isEmpty);

      // moveIdentities(kinds: {email}) selects the code identifier only,
      // leaving the provider identity where it is.
      final (_, third) = await harness().signedIn('third@example.com');
      final movedEmail = await accounts().moveIdentities(
        mixed.id,
        third.id,
        kinds: {DwIdentifierKind.email},
      );
      expect(values(movedEmail), ['email:mixed@example.com']);
      expect(values(await accounts().listIdentities(mixed.id)), [
        'google:google-mixed-1',
      ]);

      // removeIdentities(kinds: null) removes a provider identity too.
      final removed = await accounts().removeIdentities(mixed.id);
      expect(removed, hasLength(1));
      expect(removed.single.provider, 'google');
      expect(await accounts().listIdentities(mixed.id), isEmpty);
    });
  });
  group('trusted identifier batch', () {
    Matcher refusal(DwRefusalCode code, {String? field}) => throwsA(
      isA<DwRefusalException>()
          .having((e) => e.refusal.code, 'code', code.code)
          .having((e) => e.refusal.field, 'field', field),
    );
    Future<String> name(int id) async => (await harness().db.query(
      'SELECT name FROM profile WHERE account_id = @id',
      params: {'id': id},
    )).single.get<String>('name');
    Future<void> rename(DwCallContext ctx, int id, String name) async {
      await ctx.db.query(
        'SELECT account_id FROM profile WHERE account_id = @id FOR UPDATE',
        params: {'id': id},
      );
      await ctx.db.execute(
        'UPDATE profile SET name = @name WHERE account_id = @id',
        params: {'id': id, 'name': name},
      );
    }

    Future<int> countAccounts() async => (await harness().db.query(
      'SELECT count(*) AS n FROM dw_account',
    )).single.get<int>('n');

    test(
      'both fields and project callback commit one final hook snapshot, stable ids and sessions',
      () async {
        final (caller, session) = await harness().signedIn(
          'batch-old@example.com',
        );
        await attach(caller, '+15550007001', kind: DwIdentifierKind.phone);
        final before = await accounts().listIdentities(session.id);
        final keys = await accounts().listKeys(session.id);
        final changed = await accounts().updateIdentifiers(
          session.id,
          phone: const DwFieldPatch.set('  +15550007002  '),
          email: const DwFieldPatch.set(' Batch-New@EXAMPLE.com '),
          beforeChange: (ctx) => rename(ctx, session.id, 'Edited'),
        );
        expect(changed.map((i) => i.id), before.map((i) => i.id));
        expect(changed.map((i) => i.value), [
          'batch-new@example.com',
          '+15550007002',
        ]);
        expect(changed.every((i) => i.verifiedAt == null), isTrue);
        expect(
          (await accounts().listKeys(session.id)).map((k) => k.id),
          keys.map((k) => k.id),
        );
        expect(
          (await caller.call(const NeedsAccount())).value(const NeedsAccount()),
          session.id,
        );
        final snapshots = app().identifierSnapshots
            .where((s) => s.accountId == session.id && s.name == 'Edited')
            .toList();
        expect(snapshots, hasLength(2));
        for (final snapshot in snapshots) {
          expect(snapshot.identities, [
            'email:batch-new@example.com',
            'phone:+15550007002',
          ]);
          expect(
            snapshot.callerId,
            isNull,
            reason: 'target account is not impersonated',
          );
        }
      },
    );

    for (final kind in DwIdentifierKind.values) {
      test(
        'occupied ${kind.name} refuses all fields before callback, without ghost account',
        () async {
          final (_, target) = await harness().signedIn(
            'conflict-target-${kind.name}@example.com',
          );
          final (_, owner) = await harness().signedIn(
            'occupied-${kind.name}@example.com',
          );
          await accounts().updateIdentifiers(
            owner.id,
            phone: DwFieldPatch.set(
              kind == DwIdentifierKind.phone ? '+15550007101' : '+15550007102',
            ),
          );
          final before = await accounts().listIdentities(target.id);
          final count = await countAccounts();
          var called = false;
          await expectLater(
            accounts().updateIdentifiers(
              target.id,
              phone: DwFieldPatch.set(
                kind == DwIdentifierKind.phone
                    ? '+15550007101'
                    : '+15550007103',
              ),
              email: DwFieldPatch.set(
                kind == DwIdentifierKind.email
                    ? 'occupied-email@example.com'
                    : 'free-conflict@example.com',
              ),
              beforeChange: (ctx) async {
                called = true;
                await rename(ctx, target.id, 'Must not persist');
              },
            ),
            refusal(DwAuthRefusal.identifierTaken, field: kind.name),
          );
          expect(called, isFalse);
          expect(await accounts().listIdentities(target.id), before);
          expect(await countAccounts(), count);
        },
      );
    }

    test(
      'invalid value, missing target and last identifier refuse without writes',
      () async {
        final (_, target) = await harness().signedIn('batch-last@example.com');
        final before = await accounts().listIdentities(target.id);
        await expectLater(
          accounts().updateIdentifiers(
            target.id,
            phone: const DwFieldPatch.set('bad'),
          ),
          refusal(DwCoreRefusal.invalid, field: 'phone'),
        );
        await expectLater(
          accounts().updateIdentifiers(
            987654321,
            email: const DwFieldPatch.set('valid@example.com'),
          ),
          refusal(DwCoreRefusal.notFound),
        );
        await expectLater(
          accounts().updateIdentifiers(
            target.id,
            email: const DwFieldPatch.clear(),
          ),
          refusal(DwCoreRefusal.invalid, field: 'identifiers'),
        );
        expect(await accounts().listIdentities(target.id), before);
      },
    );

    test(
      'provider identity permits clearing code identifiers; keep still runs project callback',
      () async {
        final target = await accounts().signInWithExternalIdentity(
          provider: 'google',
          subject: 'batch-provider',
        );
        await accounts().updateIdentifiers(
          target.id,
          email: const DwFieldPatch.set('batch-provider@example.com'),
        );
        final result = await accounts().updateIdentifiers(
          target.id,
          email: const DwFieldPatch.clear(),
        );
        expect(result.single.provider, 'google');
        final hooks = app().identifierChanges.length;
        await accounts().updateIdentifiers(
          target.id,
          beforeChange: (ctx) => rename(ctx, target.id, 'Profile only'),
        );
        expect(await name(target.id), 'Profile only');
        expect(app().identifierChanges, hasLength(hooks));
      },
    );

    test(
      'no-op retains verification and publishes no hooks, but runs callback',
      () async {
        final (_, target) = await harness().signedIn('batch-noop@example.com');
        final before = await accounts().listIdentities(target.id);
        final hooks = app().identifierChanges.length;
        var callbacks = 0;
        final same = await accounts().updateIdentifiers(
          target.id,
          email: const DwFieldPatch.set(' BATCH-NOOP@EXAMPLE.COM '),
          beforeChange: (_) async {
            callbacks++;
          },
        );
        expect(same, before);
        expect(app().identifierChanges.length, hooks);
        expect(callbacks, 1);
        await accounts().updateIdentifiers(
          target.id,
          beforeChange: (_) async {
            callbacks++;
          },
        );
        expect(app().identifierChanges.length, hooks);
        expect(callbacks, 2);
      },
    );

    test(
      'existing matching identity wins over oldest and duplicate identities are dropped',
      () async {
        final (caller, target) = await harness().signedIn(
          'batch-oldest@example.com',
        );
        final matching = await attach(caller, 'batch-owned@example.com');
        final hooks = app().identifierChanges.length;
        final result = await accounts().updateIdentifiers(
          target.id,
          email: const DwFieldPatch.set('batch-owned@example.com'),
        );
        expect(result, [matching]);
        final changed = app().identifierChanges.skip(hooks).toList();
        expect(changed, hasLength(1));
        expect(changed.single.previous, 'batch-oldest@example.com');
        expect(changed.single.current, isNull);
        expect(changed.single.cause, DwIdentifierChangeCause.updated);
      },
    );

    test(
      'callback and hook failures roll back project and both identifier writes',
      () async {
        final (_, target) = await harness().signedIn(
          'rollback-batch@example.com',
        );
        final before = await accounts().listIdentities(target.id);
        final oldName = await name(target.id);
        await expectLater(
          accounts().updateIdentifiers(
            target.id,
            email: const DwFieldPatch.set('callback-new@example.com'),
            beforeChange: (ctx) async {
              await rename(ctx, target.id, 'Not committed');
              throw StateError('callback failed');
            },
          ),
          throwsStateError,
        );
        expect(await name(target.id), oldName);
        expect(await accounts().listIdentities(target.id), before);
        app().failingIdentifierChanges.add('hook-new@example.com');
        await expectLater(
          accounts().updateIdentifiers(
            target.id,
            phone: const DwFieldPatch.set('+15550007201'),
            email: const DwFieldPatch.set('hook-new@example.com'),
            beforeChange: (ctx) =>
                rename(ctx, target.id, 'Not committed either'),
          ),
          throwsStateError,
        );
        expect(await name(target.id), oldName);
        expect(await accounts().listIdentities(target.id), before);
        expect(
          await accounts().find(DwIdentifierKind.phone, '+15550007201'),
          isNull,
        );
      },
    );

    test(
      'outer application transaction rollback includes the batch and callback',
      () async {
        final (_, target) = await harness().signedIn('outer-batch@example.com');
        final oldName = await name(target.id);
        await expectLater(
          harness().server.runInContext(
            (ctx) => ctx.transaction((_) async {
              await ctx.accounts.updateIdentifiers(
                target.id,
                email: const DwFieldPatch.set('outer-new@example.com'),
                beforeChange: (batchCtx) =>
                    rename(batchCtx, target.id, 'Outer edit'),
              );
              throw StateError('outer failed');
            }),
          ),
          throwsStateError,
        );
        expect(await name(target.id), oldName);
        expect(
          await accounts().find(
            DwIdentifierKind.email,
            'outer-batch@example.com',
          ),
          target.id,
        );
        expect(
          await accounts().find(
            DwIdentifierKind.email,
            'outer-new@example.com',
          ),
          isNull,
        );
      },
    );

    test(
      'two disjoint clears serialize and cannot jointly remove the last login',
      () async {
        final (_, target) = await harness().signedIn(
          'concurrent-clear@example.com',
        );
        await accounts().updateIdentifiers(
          target.id,
          phone: const DwFieldPatch.set('+15550007301'),
        );
        final entered = Completer<void>();
        final release = Completer<void>();
        final first = accounts().updateIdentifiers(
          target.id,
          phone: const DwFieldPatch.clear(),
          beforeChange: (_) async {
            entered.complete();
            await release.future;
          },
        );
        await entered.future;
        final second = expectLater(
          accounts().updateIdentifiers(
            target.id,
            email: const DwFieldPatch.clear(),
          ),
          refusal(DwCoreRefusal.invalid, field: 'identifiers'),
        );
        await eventually(
          () async =>
              (await harness().db.query(
                "SELECT count(*) AS n FROM pg_locks WHERE locktype = 'advisory' AND NOT granted AND database = (SELECT oid FROM pg_database WHERE datname = current_database())",
              )).single.get<int>('n') >
              0,
        );
        release.complete();
        await first;
        await second;
        expect(
          (await accounts().listIdentities(target.id)).single.value,
          'concurrent-clear@example.com',
        );
      },
    );

    String batchPhone(int id) => '+1555${id.toString().padLeft(7, '0')}';

    Future<void> queuedBehindBatch(
      int accountId,
      Future<void> Function() other,
      Future<void> Function() check,
    ) async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final batch = accounts().updateIdentifiers(
        accountId,
        phone: DwFieldPatch.set(batchPhone(accountId)),
        beforeChange: (_) async {
          entered.complete();
          await release.future;
        },
      );
      await entered.future;
      final competing = other();
      try {
        await eventually(
          () async =>
              (await harness().db.query(
                "SELECT count(*) AS n FROM pg_locks WHERE locktype = 'advisory' AND NOT granted AND database = (SELECT oid FROM pg_database WHERE datname = current_database())",
              )).single.get<int>('n') >
              0,
        );
      } finally {
        release.complete();
      }
      await batch;
      await competing;
      await check();
    }

    test(
      'confirmation queues behind a batch and keeps the same account',
      () async {
        final (caller, target) = await harness().signedIn(
          'batch-confirm@example.com',
        );
        final ticket = (await requestAttach(
          caller,
          'batch-confirm-attached@example.com',
        )).value(anyTicket);
        await queuedBehindBatch(
          target.id,
          () async {
            final answer = await confirm(
              caller,
              ticket.id,
              app().delivered['batch-confirm-attached@example.com']!,
            );
            expect(answer.value(anyConfirm).accountId, target.id);
          },
          () async {
            expect(
              (await accounts().listIdentities(target.id)).map((i) => i.value),
              containsAll([
                'batch-confirm@example.com',
                'batch-confirm-attached@example.com',
                batchPhone(target.id),
              ]),
            );
          },
        );
      },
    );

    test(
      'move queues behind a batch and retains the updated identity id',
      () async {
        final (_, target) = await harness().signedIn('batch-move@example.com');
        final (_, destination) = await harness().signedIn(
          'batch-move-dest@example.com',
        );
        await queuedBehindBatch(
          target.id,
          () async {
            await accounts().moveIdentities(
              target.id,
              destination.id,
              kinds: {DwIdentifierKind.phone},
            );
          },
          () async {
            expect(
              await accounts().find(
                DwIdentifierKind.phone,
                batchPhone(target.id),
              ),
              destination.id,
            );
            expect(
              (await accounts().listIdentities(target.id)).single.value,
              'batch-move@example.com',
            );
          },
        );
      },
    );

    test(
      'remove queues behind a batch; removing all remains available for merges',
      () async {
        final (_, target) = await harness().signedIn(
          'batch-remove@example.com',
        );
        await queuedBehindBatch(
          target.id,
          () async {
            await accounts().removeIdentities(target.id);
          },
          () async {
            expect(await accounts().listIdentities(target.id), isEmpty);
          },
        );
      },
    );

    test(
      'account deletion queues behind a batch, with no orphan identities or keys',
      () async {
        final (_, target) = await harness().signedIn(
          'batch-delete@example.com',
        );
        await queuedBehindBatch(
          target.id,
          () async {
            expect(await accounts().deleteAccount(target.id), isTrue);
          },
          () async {
            expect(await accounts().listIdentities(target.id), isEmpty);
            expect(await accounts().listKeys(target.id), isEmpty);
            expect(
              await accounts().find(
                DwIdentifierKind.phone,
                batchPhone(target.id),
              ),
              isNull,
            );
          },
        );
      },
    );

    test(
      'code sign-in re-resolves ownership after a batch and creates no ghost account',
      () async {
        final (_, target) = await harness().signedIn(
          'batch-signin-old@example.com',
        );
        const request = DwRequestCode(
          kind: DwIdentifierKind.email,
          identifier: 'batch-signin-new@example.com',
        );
        final caller = harness().caller();
        final ticket = (await caller.call(request)).value(request);
        final count = await countAccounts();
        final entered = Completer<void>();
        final release = Completer<void>();
        final batch = accounts().updateIdentifiers(
          target.id,
          email: const DwFieldPatch.set('batch-signin-new@example.com'),
          beforeChange: (_) async {
            entered.complete();
            await release.future;
          },
        );
        await entered.future;
        final command = DwVerifyCode(
          ticketId: ticket.id,
          code: app().delivered['batch-signin-new@example.com']!,
        );
        final signIn = caller.call(command);
        try {
          await eventually(
            () async =>
                (await harness().db.query(
                  "SELECT count(*) AS n FROM pg_locks WHERE locktype = 'advisory' AND NOT granted AND database = (SELECT oid FROM pg_database WHERE datname = current_database())",
                )).single.get<int>('n') >
                0,
          );
        } finally {
          release.complete();
        }
        await batch;
        final session = (await signIn).value(command);
        expect(session.id, target.id);
        expect(session.isNewAccount, isFalse);
        expect(await countAccounts(), count);
      },
    );

    test(
      'external sign-in serializes with a batch on the existing provider account',
      () async {
        final target = await accounts().signInWithExternalIdentity(
          provider: 'google',
          subject: 'batch-provider-race',
        );
        await queuedBehindBatch(
          target.id,
          () async {
            final session = await accounts().signInWithExternalIdentity(
              provider: 'google',
              subject: 'batch-provider-race',
            );
            expect(session.id, target.id);
            expect(session.isNewAccount, isFalse);
          },
          () async {
            expect(
              (await accounts().listIdentities(
                target.id,
              )).map((i) => i.kindName),
              ['google', 'phone'],
            );
          },
        );
      },
    );

    test(
      'bare database joins its own transaction and retries ownership conflicts',
      () async {
        final service = DwAccountService(harness().db, app().auth());
        final (_, target) = await harness().signedIn(
          'bare-existing@example.com',
        );
        final id = target.id;
        final count = await countAccounts();
        final entered = Completer<void>();
        final release = Completer<void>();
        final batch = accounts().updateIdentifiers(
          id,
          email: const DwFieldPatch.set('bare-concurrent@example.com'),
          beforeChange: (_) async {
            entered.complete();
            await release.future;
          },
        );
        await entered.future;
        // The uncommitted new value is still free to the seed service. It
        // waits on its identifier lock, then must retry its now-stale owner
        // resolution instead of making a ghost account or leaking 40001.
        final seed = service.ensure(
          DwIdentifierKind.email,
          'bare-concurrent@example.com',
        );
        try {
          await eventually(
            () async =>
                (await harness().db.query(
                  "SELECT count(*) AS n FROM pg_locks WHERE locktype = 'advisory' AND NOT granted AND database = (SELECT oid FROM pg_database WHERE datname = current_database())",
                )).single.get<int>('n') >
                0,
          );
        } finally {
          release.complete();
        }
        await batch;
        final ensured = await seed;
        expect(ensured.accountId, id);
        expect(ensured.created, isFalse);
        expect(await countAccounts(), count);
        final result = await service.updateIdentifiers(
          id,
          email: const DwFieldPatch.set('bare-edited@example.com'),
          beforeChange: (ctx) => rename(ctx, id, 'Bare edit'),
        );
        expect(result.single.value, 'bare-edited@example.com');
        expect(await name(id), 'Bare edit');
      },
    );

    test(
      'opposite account swaps refuse occupied identifiers without partial success',
      () async {
        final (_, first) = await harness().signedIn('swap-first@example.com');
        final (_, second) = await harness().signedIn('swap-second@example.com');
        await Future.wait([
          expectLater(
            accounts().updateIdentifiers(
              first.id,
              email: const DwFieldPatch.set('swap-second@example.com'),
            ),
            refusal(DwAuthRefusal.identifierTaken, field: 'email'),
          ),
          expectLater(
            accounts().updateIdentifiers(
              second.id,
              email: const DwFieldPatch.set('swap-first@example.com'),
            ),
            refusal(DwAuthRefusal.identifierTaken, field: 'email'),
          ),
        ]);
        expect(
          await accounts().find(
            DwIdentifierKind.email,
            'swap-first@example.com',
          ),
          first.id,
        );
        expect(
          await accounts().find(
            DwIdentifierKind.email,
            'swap-second@example.com',
          ),
          second.id,
        );
      },
    );
  });
}
