import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  final harness = useHarness();

  Future<int> identities(String value) async => (await harness().db.query(
    'SELECT count(*) AS n FROM dw_identity WHERE value = @value',
    params: {'value': value},
  )).single.get<int>('n');

  DwAccountService accounts() => harness().server.server.accounts;

  group('signing in with an external identity', () {
    test(
      'creates the account and its project row once, then signs in to it',
      () async {
        const subject = 'google-subject-1';
        final first = await accounts().signInWithExternalIdentity(
          provider: 'google',
          subject: subject,
          registration: const {'name': 'Ada'},
        );
        expect(first.isNewAccount, isTrue);
        expect(harness().app.externalAccounts[first.id], 'google:$subject');
        final profile = await harness().db.query(
          'SELECT name, identifier FROM profile WHERE account_id = @id',
          params: {'id': first.id},
        );
        expect(profile.single['name'], 'Ada');

        final again = await accounts().signInWithExternalIdentity(
          provider: 'google',
          subject: subject,
        );
        expect(again.id, first.id);
        expect(again.isNewAccount, isFalse);
        expect(again.token, isNot(first.token), reason: 'a session of its own');
        expect(
          await accounts().accountOfExternalIdentity(
            provider: 'google',
            subject: subject,
          ),
          first.id,
        );

        // The same subject at another provider is another person.
        final apple = await accounts().signInWithExternalIdentity(
          provider: 'apple',
          subject: subject,
        );
        expect(apple.id, isNot(first.id));
      },
    );

    test('the identity is verified, and the account can be deleted like any '
        'other', () async {
      final session = await accounts().signInWithExternalIdentity(
        provider: 'google',
        subject: 'google-subject-2',
      );
      final verified = await harness().db.query(
        'SELECT kind, verified_at FROM dw_identity WHERE account_id = @id',
        params: {'id': session.id},
      );
      expect(verified.single['kind'], 'google');
      expect(verified.single['verified_at'], isNotNull);

      expect(await accounts().deleteAccount(session.id), isTrue);
      expect(
        await accounts().accountOfExternalIdentity(
          provider: 'google',
          subject: 'google-subject-2',
        ),
        isNull,
      );
    });

    test('a provider name or subject the store cannot take is an argument '
        'error', () async {
      expect(
        () => accounts().signInWithExternalIdentity(
          provider: 'Google Plus',
          subject: 'x',
        ),
        throwsArgumentError,
      );
      expect(
        () => accounts().signInWithExternalIdentity(
          provider: 'google',
          subject: '',
        ),
        throwsArgumentError,
      );
    });

    test(
      "a code identifier's own kind name (email, phone) is not a provider "
      'name: DwAuthStore.identityOf tells the two apart by trying the enum '
      'first, and a provider actually called "email" would read back wrong',
      () async {
        expect(
          () => accounts().signInWithExternalIdentity(
            provider: 'email',
            subject: 'x',
          ),
          throwsArgumentError,
        );
        expect(
          () => accounts().signInWithExternalIdentity(
            provider: 'phone',
            subject: 'x',
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('linking a provider identity by a verified e-mail (#356)', () {
    Future<Harness> linkingHarness() => Harness.start(
      app: TestApp(),
      build: (app, config) =>
          app.server(config, auth: app.auth(linkByVerifiedEmail: true)),
    );

    test('linkByVerifiedEmail on, the token\'s e-mail verified and matching an '
        'existing email identity: the provider identity joins that account, '
        'onIdentifierChanged fires (cause linked) and onExternalAccountCreated '
        'does not', () async {
      final linked = await linkingHarness();
      try {
        final (_, session) = await linked.signedIn('linked@example.com');
        final changes = linked.app.identifierChanges.length;
        final createdBefore = linked.app.createdAccounts.length;

        final again = await linked.server.server.accounts
            .signInWithExternalIdentity(
              provider: 'google',
              subject: 'google-link-1',
              // Normalized the same way `DwAuthConfig.normalize` would —
              // proving the match is on the normalized form, not the raw
              // one the provider happened to send.
              verifiedEmail: 'Linked@Example.com',
            );

        expect(again.id, session.id);
        expect(again.isNewAccount, isFalse);
        expect(
          linked.app.createdAccounts.length,
          createdBefore,
          reason:
              'onExternalAccountCreated must not run for a linked '
              'identity',
        );
        expect(linked.app.externalAccounts.containsKey(session.id), isFalse);

        final change = linked.app.identifierChanges.skip(changes).single;
        expect(change.accountId, session.id);
        expect(change.provider, 'google');
        expect(change.kind, isNull);
        expect(change.cause, DwIdentifierChangeCause.linked);
        expect(change.previous, isNull);
        expect(change.current, 'google-link-1');

        final all = await linked.server.server.accounts.listIdentities(
          session.id,
        );
        expect(all.map((i) => i.provider ?? i.kind!.name).toSet(), {
          'email',
          'google',
        });
        expect(
          all.firstWhere((i) => i.provider == 'google').verifiedAt,
          isNotNull,
        );
      } finally {
        await linked.stop();
      }
    });

    test('email_verified false — no verifiedEmail passed at all — never links, '
        'even with a matching identity and linking on', () async {
      final linked = await linkingHarness();
      try {
        final (_, session) = await linked.signedIn('unverified@example.com');
        final result = await linked.server.server.accounts
            .signInWithExternalIdentity(
              provider: 'google',
              subject: 'google-link-2',
              // The real module only ever passes verifiedEmail when the
              // token's own `email_verified` claim is true; omitting it
              // here is that "false or missing" case.
            );
        expect(result.isNewAccount, isTrue);
        expect(result.id, isNot(session.id));
      } finally {
        await linked.stop();
      }
    });

    test('linkByVerifiedEmail off (the default): a matching verified e-mail '
        'still makes a new account', () async {
      final (_, session) = await harness().signedIn('nolinking@example.com');
      final result = await accounts().signInWithExternalIdentity(
        provider: 'google',
        subject: 'google-link-3',
        verifiedEmail: 'nolinking@example.com',
      );
      expect(result.isNewAccount, isTrue);
      expect(result.id, isNot(session.id));
      expect(harness().app.externalAccounts[result.id], 'google:google-link-3');
    });

    test('linkByVerifiedEmail on, but no account has that e-mail identity: a '
        'new account, as usual', () async {
      final linked = await linkingHarness();
      try {
        final result = await linked.server.server.accounts
            .signInWithExternalIdentity(
              provider: 'google',
              subject: 'google-link-4',
              verifiedEmail: 'nobody-here@example.com',
            );
        expect(result.isNewAccount, isTrue);
        expect(linked.app.externalAccounts[result.id], 'google:google-link-4');
      } finally {
        await linked.stop();
      }
    });

    test(
      'the matching e-mail identity itself unverified (DwAccountService.ensure '
      '— a seed, an admin bootstrap): links anyway. An e-mail sign-in already '
      'joins that account the same way; a provider proving the same address '
      'is held to no higher a bar',
      () async {
        final linked = await linkingHarness();
        try {
          final tool = await linked.server.server.accounts.ensure(
            DwIdentifierKind.email,
            'invited@example.com',
          );
          final changes = linked.app.identifierChanges.length;
          final createdBefore = linked.app.createdAccounts.length;
          final result = await linked.server.server.accounts
              .signInWithExternalIdentity(
                provider: 'google',
                subject: 'google-link-6',
                verifiedEmail: 'invited@example.com',
              );
          expect(result.id, tool.accountId);
          expect(result.isNewAccount, isFalse);
          expect(
            linked.app.createdAccounts.length,
            createdBefore,
            reason:
                'onExternalAccountCreated must not run for a linked '
                'identity',
          );
          expect(
            linked.app.identifierChanges.skip(changes).single.cause,
            DwIdentifierChangeCause.linked,
          );
        } finally {
          await linked.stop();
        }
      },
    );

    test('the matched account already holds a different identity of this same '
        'provider: refuses to link — the shape a lapsed custom domain '
        "re-registered by someone else would take, that account's own Google "
        'identity aside', () async {
      final linked = await linkingHarness();
      try {
        // The account already signed in with Google once, under a subject
        // of its own — an identity linking must never silently join a
        // second one to.
        final owner = await linked.server.server.accounts
            .signInWithExternalIdentity(
              provider: 'google',
              subject: 'google-original-owner',
            );
        await linked.server.server.accounts.moveIdentities(
          owner.id,
          (await linked.signedIn('takeover@example.com')).$2.id,
        );
        final target = await linked.server.server.accounts.find(
          DwIdentifierKind.email,
          'takeover@example.com',
        );
        final changes = linked.app.identifierChanges.length;
        final result = await linked.server.server.accounts
            .signInWithExternalIdentity(
              provider: 'google',
              subject: 'google-new-claimant',
              verifiedEmail: 'takeover@example.com',
            );
        expect(result.id, isNot(target));
        expect(result.isNewAccount, isTrue);
        expect(
          linked.app.externalAccounts[result.id],
          'google:google-new-claimant',
        );
        expect(
          linked.app.identifierChanges.skip(changes),
          isEmpty,
          reason: 'nothing about the existing account changed',
        );
      } finally {
        await linked.stop();
      }
    });

    test(
      'linked only on the first sign-in: signing in again with the same '
      'provider identity answers the same account without re-linking',
      () async {
        final linked = await linkingHarness();
        try {
          final (_, session) = await linked.signedIn('twice@example.com');
          final first = await linked.server.server.accounts
              .signInWithExternalIdentity(
                provider: 'google',
                subject: 'google-link-5',
                verifiedEmail: 'twice@example.com',
              );
          expect(first.id, session.id);
          final changes = linked.app.identifierChanges.length;
          final second = await linked.server.server.accounts
              .signInWithExternalIdentity(
                provider: 'google',
                subject: 'google-link-5',
                verifiedEmail: 'twice@example.com',
              );
          expect(second.id, session.id);
          expect(second.isNewAccount, isFalse);
          expect(
            linked.app.identifierChanges.length,
            changes,
            reason: 'the identity already exists: nothing changed',
          );
        } finally {
          await linked.stop();
        }
      },
    );

    test("two provider identities racing to link one e-mail serialise on it: "
        "exactly one links, the other's same-provider guard sees the first's "
        "identity and refuses, making its own account — proves the e-mail's "
        "own advisory lock is actually held (not only the provider's), or both "
        "would land on the one account at once", () async {
      final linked = await linkingHarness();
      try {
        final (_, session) = await linked.signedIn('racer@example.com');
        final results = await Future.wait([
          linked.server.server.accounts.signInWithExternalIdentity(
            provider: 'google',
            subject: 'google-race-a',
            verifiedEmail: 'racer@example.com',
          ),
          linked.server.server.accounts.signInWithExternalIdentity(
            provider: 'google',
            subject: 'google-race-b',
            verifiedEmail: 'racer@example.com',
          ),
        ]);
        expect(
          results.where((r) => r.id == session.id),
          hasLength(1),
          reason: 'exactly one of the two landed on the e-mail account',
        );
        final identities = await linked.db.query(
          'SELECT count(*) AS n FROM dw_identity '
          'WHERE account_id = @id AND kind = @kind',
          params: {'id': session.id, 'kind': 'google'},
        );
        expect(
          identities.single.get<int>('n'),
          1,
          reason:
              'never two identities of the same provider on one '
              'account',
        );
      } finally {
        await linked.stop();
      }
    });
  });

  group('deleting an account', () {
    Future<int> countOf(String table, int accountId) async =>
        (await harness().db.query(
          'SELECT count(*)::int AS n FROM $table WHERE account_id = @id',
          params: {'id': accountId},
        )).single.get<int>('n');

    test('DwDeleteMyAccount removes the account, its identities, its keys and '
        "the project's rows, and ends its sessions", () async {
      const email = 'leaving@example.com';
      final session = await harness().app.signIn(harness().caller(), email);
      final member = harness().caller(token: session.token);

      final answer = await member.call(const DwDeleteMyAccount());
      expect(answer.status, 200, reason: answer.text);

      expect(await identities(email), 0);
      expect(
        await harness().db.query(
          'SELECT 1 FROM dw_code_ticket WHERE identifier = @value',
          params: {'value': email},
        ),
        isEmpty,
        reason: 'a ticket carries the identifier and must not outlive it',
      );
      expect(await countOf('dw_command_outcome', session.id), 0);
      expect(await countOf('profile', session.id), 0);
      expect(await countOf('dw_auth_key', session.id), 0);
      expect(
        await harness().db.query(
          'SELECT 1 FROM dw_account WHERE id = @id',
          params: {'id': session.id},
        ),
        isEmpty,
      );
      expect(
        (await member.call(const DwSignOut())).status,
        401,
        reason: 'the session ended with the account',
      );

      // The identifier is free: it makes a new account.
      final again = await accounts().ensure(DwIdentifierKind.email, email);
      expect(again.created, isTrue);
      expect(again.accountId, isNot(session.id));
    });

    test(
      'a refusing onAccountDeleting keeps the account and its session',
      () async {
        final session = await harness().app.signIn(
          harness().caller(),
          'staying@example.com',
        );
        harness().app.undeletable.add(session.id);
        final member = harness().caller(token: session.token);

        final answer = await member.call(const DwDeleteMyAccount());
        expect(answer.status, 403, reason: answer.text);
        expect(await countOf('profile', session.id), 1);
        expect(await identities('staying@example.com'), 1);
        expect((await member.call(const DwSignOut())).status, 200);
      },
    );

    test('byOperator refuses DwDeleteMyAccount, and server code still '
        'deletes', () async {
      final testApp = TestApp();
      final operated = await Harness.start(
        app: testApp,
        build: (app, config) => app.server(
          config,
          auth: app.auth(accountDeletion: DwAccountDeletion.byOperator),
        ),
      );
      try {
        const email = 'kept@example.com';
        final session = await testApp.signIn(operated.caller(), email);
        final member = operated.caller(token: session.token);

        final answer = await member.call(const DwDeleteMyAccount());
        expect(answer.status, 403, reason: answer.text);
        expect(answer.refusal.code, DwCoreRefusal.forbidden.code);
        expect(
          (await member.call(const DwSignOut())).status,
          200,
          reason: 'the account and its session are intact',
        );

        await operated.server.server.accounts.deleteAccount(session.id);
        expect(
          await operated.db.query(
            'SELECT 1 FROM dw_account WHERE id = @id',
            params: {'id': session.id},
          ),
          isEmpty,
        );
      } finally {
        await operated.stop();
      }
    });

    test('signed out, there is nothing to delete', () async {
      expect(
        (await harness().caller().call(const DwDeleteMyAccount())).status,
        401,
      );
    });
  });

  group('server.accounts', () {
    test('ensure creates once, normalizes, runs onAccountCreated in the same '
        'transaction; find sees it', () async {
      final created = await accounts().ensure(
        DwIdentifierKind.email,
        ' Admin@Example.com ',
      );
      expect(created.created, isTrue);
      expect(harness().app.createdAccounts, contains(created.accountId));
      expect(
        harness().app.accountOrigins[created.accountId],
        isA<DwToolOrigin>(),
        reason: 'a tool, not a sign-in without registration',
      );
      final profile = await harness().db.query(
        'SELECT name, identifier FROM profile WHERE account_id = @id',
        params: {'id': created.accountId},
      );
      expect(profile.single['identifier'], 'admin@example.com');
      expect(profile.single['name'], '', reason: 'empty registration');

      final again = await accounts().ensure(
        DwIdentifierKind.email,
        'admin@example.com',
      );
      expect(again, (accountId: created.accountId, created: false));
      expect(
        await accounts().find(DwIdentifierKind.email, 'ADMIN@example.com'),
        created.accountId,
      );
      expect(
        await accounts().find(DwIdentifierKind.email, 'nobody@example.com'),
        isNull,
      );
    });

    test('an identifier normalize rejects is an ArgumentError', () async {
      await expectLater(
        accounts().ensure(DwIdentifierKind.phone, 'not a phone'),
        throwsArgumentError,
      );
      expect(
        () => accounts().find(DwIdentifierKind.email, 'no-at-sign'),
        throwsArgumentError,
      );
    });

    test('concurrent ensures, and a sign-in of the same identifier, share '
        'one account', () async {
      const email = 'race-ensure@example.com';
      final results = await Future.wait([
        for (var i = 0; i < 4; i++)
          accounts().ensure(DwIdentifierKind.email, email),
      ]);
      expect(results.map((r) => r.accountId).toSet(), hasLength(1));
      expect(results.where((r) => r.created), hasLength(1));
      expect(await identities(email), 1);

      final session = await harness().app.signIn(harness().caller(), email);
      expect(session.id, results.first.accountId);
      expect(session.isNewAccount, isFalse);
    });

    test('revokeKeys closes the live sessions of every key of the account, '
        'and only of that account', () async {
      final (_, session) = await harness().signedIn('live-revoked@example.com');
      final first = await harness().live(token: session.token);
      final second = await harness().live(token: session.token);
      final (_, keptSession) = await harness().signedIn(
        'live-kept@example.com',
      );
      final bystander = await harness().live(token: keptSession.token);
      for (final c in [first, second, bystander]) {
        expect(await c.subscribe('notes'), isA<DwSubscribedMessage>());
      }

      await accounts().revokeKeys(session.id);

      for (final c in [first, second]) {
        expect((await c.expect<DwChannelClosedMessage>()).channel, 'notes');
        expect((await c.expect<DwAuthenticatedMessage>()).rejected, isTrue);
      }
      await bystander.expectSilence();
      expect((await first.authenticate(session.token)).rejected, isTrue);
    });
  });

  group('ctx.accounts', () {
    test('revokeKeys closes live sessions after the command commits, and not '
        'at all when it is refused', () async {
      final (admin, _) = await harness().signedIn('ctx-admin@example.com');
      final (_, session) = await harness().signedIn('ctx-victim@example.com');
      final victim = await harness().live(token: session.token);
      expect(await victim.subscribe('notes'), isA<DwSubscribedMessage>());

      expect(
        (await admin.call(RevokeSessions(session.id, ending: 'refuse'))).status,
        409,
      );
      await victim.expectSilence();

      expect((await admin.call(RevokeSessions(session.id))).status, 200);
      expect((await victim.expect<DwChannelClosedMessage>()).channel, 'notes');
      expect((await victim.expect<DwAuthenticatedMessage>()).rejected, isTrue);
    });

    test('ensure inside a command joins its transaction', () async {
      final answer = await harness().caller().call(
        const EnsureAccount('from-command@example.com'),
      );
      final id = answer.value(const EnsureAccount(''));
      expect(
        await accounts().find(
          DwIdentifierKind.email,
          'from-command@example.com',
        ),
        id,
      );
    });
  });

  group('DwAccountService over a bare database', () {
    test('creates with onAccountCreated bound to the transaction', () async {
      final service = DwAccountService(harness().db, harness().app.auth());
      final created = await service.ensure(
        DwIdentifierKind.phone,
        '+15550001111',
      );
      expect(created.created, isTrue);
      final profile = await harness().db.query(
        'SELECT identifier FROM profile WHERE account_id = @id',
        params: {'id': created.accountId},
      );
      expect(profile.single['identifier'], '+15550001111');
      expect(
        await service.find(DwIdentifierKind.phone, '+15550001111'),
        created.accountId,
      );
    });

    test('a hook that publishes throws instead of dropping it, and the '
        'account is not created', () async {
      final base = harness().app.auth();
      final auth = DwAuthConfig(
        accountDeletion: DwAccountDeletion.byMember,
        normalize: base.normalize,
        deliverCode: base.deliverCode,
        onAccountCreated: (ctx, accountId, kind, identifier, origin) async =>
            ctx.publish(
              const DwLiveChannel(TestChannel.notes),
              NoteView(id: accountId, text: 'welcome'),
            ),
      );
      final service = DwAccountService(harness().db, auth);
      await expectLater(
        service.ensure(DwIdentifierKind.email, 'detached@example.com'),
        throwsStateError,
      );
      expect(
        await service.find(DwIdentifierKind.email, 'detached@example.com'),
        isNull,
      );
    });
  });
}
