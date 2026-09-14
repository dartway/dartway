import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// Session keys: made on purpose (personal) or by signing in (app), listed,
/// revoked with immediate effect, and known to every context that
/// authenticated with one (`ctx.sessionKey`).
void main() {
  final harness = useHarness(
    build: (app, config) => app.server(
      config,
      // An hour: every "at once" below is the revocation's doing, never an
      // expired cache entry.
      settings: const DwServerSettings(tokenCacheTtl: Duration(hours: 1)),
      routes: [
        for (final (path, auth) in [
          ('/key/none', DwRouteAuth.none),
          ('/key/optional', DwRouteAuth.optional),
          ('/key/required', DwRouteAuth.required),
        ])
          DwRoute.get(
            path,
            (ctx, request) => DwHttpResponse.json({
              'account': ctx.accountId,
              'key': ctx.sessionKey?.toJson(),
            }),
            auth: auth,
          ),
      ],
    ),
  );

  DwAccountService accounts() => harness().server.server.accounts;

  Future<Uint8List> storedHash(int keyId) async => (await harness().db.query(
    'SELECT token_hash FROM dw_auth_key WHERE id = @id',
    params: {'id': keyId},
  )).single.get<Uint8List>('token_hash');

  group('issueKey', () {
    test('answers the token once; the database keeps only its hash and '
        'nothing logs it; the token signs calls in as a personal key', () async {
      final (_, session) = await harness().signedIn('issue@example.com');
      final (:key, :token) = await accounts().issueKey(
        session.id,
        label: '  Claude Code on the laptop ',
      );
      expect(key.accountId, session.id);
      expect(key.kind, DwSessionKeyKind.personal);
      expect(key.label, 'Claude Code on the laptop');
      expect(key.revokedAt, isNull);
      expect(token, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(
        await storedHash(key.id),
        sha256.convert(utf8.encode(token)).bytes,
      );

      final tool = harness().caller(token: token);
      final seen = (await tool.call(const WhichKey())).value(const WhichKey());
      expect(
        (seen!.id, seen.kind, seen.label),
        (key.id, DwSessionKeyKind.personal, 'Claude Code on the laptop'),
      );
      expect(RecordingLogger.lines.join('\n'), isNot(contains(token)));
      final everything = await harness().db.query(
        "SELECT count(*) AS n FROM dw_command_outcome WHERE result::text LIKE '%' || @token || '%'",
        params: {'token': token},
      );
      expect(everything.single['n'], 0);
    });

    test('a command answering the token stores no outcome, so a retry runs '
        'again; a refused one leaves no key', () async {
      final (caller, session) = await harness().signedIn('cmd-key@example.com');
      const key = 'issue-key-once';
      final first = (await caller.call(
        const IssueKey('ci'),
        key: key,
      )).value(const IssueKey(''));
      final outcomes = await harness().db.query(
        'SELECT count(*) AS n FROM dw_command_outcome WHERE key = @key',
        params: {'key': key},
      );
      expect(outcomes.single['n'], 0, reason: 'the token must not be stored');
      expect(
        (await harness().caller(token: first.token).call(const MyNotes()))
            .status,
        200,
      );

      final retried = (await caller.call(
        const IssueKey('ci'),
        key: key,
      )).value(const IssueKey(''));
      expect(retried.id, isNot(first.id));

      expect(
        (await caller.call(
          const IssueKey('rolled back', ending: 'refuse'),
        )).status,
        409,
      );
      final labels = [
        for (final k in await accounts().listKeys(session.id)) k.label,
      ];
      expect(labels, isNot(contains('rolled back')));
      expect(labels.where((l) => l == 'ci'), hasLength(2));
    });

    test('a label that is empty, too long or has control characters, and an '
        'account that does not exist, are ArgumentErrors', () async {
      final (_, session) = await harness().signedIn('bad-label@example.com');
      for (final label in ['', '   ', 'x' * 201, 'line\nbreak']) {
        await expectLater(
          accounts().issueKey(session.id, label: label),
          throwsArgumentError,
          reason: jsonEncode(label),
        );
      }
      await expectLater(
        accounts().issueKey(session.id, label: 'x' * 200),
        completes,
      );
      await expectLater(
        accounts().issueKey(987654321, label: 'nobody'),
        throwsArgumentError,
      );
    });
  });

  group('listKeys', () {
    test('lists app keys made by signing in — labelled with what the app '
        'said about itself — and personal keys, newest first, with their '
        'revocation', () async {
      final (_, session) = await harness().signedIn('list@example.com');
      final personal = await accounts().issueKey(session.id, label: 'script');
      await accounts().revokeKey(personal.key.id);
      final keys = await accounts().listKeys(session.id);
      expect(keys, hasLength(2));
      expect(keys.first.id, personal.key.id);
      expect(keys.last.id, lessThan(personal.key.id));
      final app = keys.last;
      expect(app.kind, DwSessionKeyKind.app);
      expect(
        app.label,
        startsWith('${DwTestCaller.defaultAppVersion} · Dart/'),
      );
      expect(app.revokedAt, isNull);
      expect(keys.first.kind, DwSessionKeyKind.personal);
      expect(keys.first.revokedAt, isNotNull);
      expect(await accounts().listKeys(987654321), isEmpty);
    });

    test('an app label is made safe: control characters folded, cut to the '
        'maximum length', () async {
      final caller = harness().caller();
      const request = DwRequestCode(
        kind: DwIdentifierKind.email,
        identifier: 'label@example.com',
      );
      final ticket = (await caller.call(request)).value(request);
      final verify = DwVerifyCode(
        ticketId: ticket.id,
        code: harness().app.delivered['label@example.com']!,
      );
      final session = (await caller.call(
        verify,
        headers: {
          DwHttpContract.appVersionHeader: null,
          'user-agent': 'Agent\t\twith  tabs ${'y' * 300}',
        },
      )).value(verify);
      final key = (await accounts().listKeys(session.id)).single;
      expect(key.label, startsWith('Agent with tabs yyy'));
      expect(key.label, hasLength(DwSessionKeyInfo.maxLabelLength));
    });
  });

  group('revokeKey', () {
    test('ends one key at once in this process: the next call is 401 though '
        'the token is cached, live sockets on the key lose their '
        'subscriptions; the account\'s other keys stay', () async {
      final (app, session) = await harness().signedIn('revoke-one@example.com');
      final personal = await accounts().issueKey(session.id, label: 'tool');
      final tool = harness().caller(token: personal.token);
      expect((await tool.call(const MyNotes())).status, 200, reason: 'cached');
      final toolSocket = await harness().live(token: personal.token);
      final appSocket = await harness().live(token: session.token);
      expect(await toolSocket.subscribe('tools'), isA<DwSubscribedMessage>());
      expect(await appSocket.subscribe('notes'), isA<DwSubscribedMessage>());

      expect(await accounts().revokeKey(personal.key.id), isTrue);

      expect((await tool.call(const MyNotes())).status, 401);
      expect(
        (await toolSocket.expect<DwChannelClosedMessage>()).channel,
        'tools',
      );
      expect(
        (await toolSocket.expect<DwAuthenticatedMessage>()).rejected,
        isTrue,
      );
      await appSocket.expectSilence();
      expect((await app.call(const MyNotes())).status, 200);
      expect(await accounts().revokeKey(personal.key.id), isFalse);
      expect(await accounts().revokeKey(987654321), isFalse);
    });

    test('from a handler: only the caller\'s own key, after commit', () async {
      final (alice, aliceSession) = await harness().signedIn(
        'alice-keys@example.com',
      );
      final (_, bobSession) = await harness().signedIn('bob-keys@example.com');
      final bobKey = await accounts().issueKey(bobSession.id, label: 'bob');
      final bob = harness().caller(token: bobKey.token);
      expect((await bob.call(const MyNotes())).status, 200);

      expect(
        (await alice.call(
          RevokeMyKey(bobKey.key.id),
        )).value(RevokeMyKey(bobKey.key.id)),
        isFalse,
      );
      expect((await bob.call(const MyNotes())).status, 200);

      final aliceKey = await accounts().issueKey(aliceSession.id, label: 'a');
      final aliceTool = harness().caller(token: aliceKey.token);
      expect((await aliceTool.call(const MyNotes())).status, 200);
      expect(
        (await alice.call(
          RevokeMyKey(aliceKey.key.id),
        )).value(RevokeMyKey(aliceKey.key.id)),
        isTrue,
      );
      expect((await aliceTool.call(const MyNotes())).status, 401);
    });

    test('over a bare database the revocation is written, and a running '
        'server notices only when its cache entry expires', () async {
      final (_, session) = await harness().signedIn('detached@example.com');
      final personal = await accounts().issueKey(session.id, label: 'seed');
      final tool = harness().caller(token: personal.token);
      expect((await tool.call(const MyNotes())).status, 200);
      final detached = DwAccountService(harness().db, harness().app.auth());
      expect(await detached.revokeKey(personal.key.id), isTrue);
      expect((await detached.listKeys(session.id)).first.revokedAt, isNotNull);
      expect(
        (await tool.call(const MyNotes())).status,
        200,
        reason: 'within DwServerSettings.tokenCacheTtl',
      );
      final socket = await harness().live();
      expect(
        (await socket.authenticate(personal.token)).rejected,
        isFalse,
        reason: 'the socket reads the same cache',
      );
    });
  });

  group('ctx.sessionKey', () {
    test('on HTTP requests and commands: the key and its kind; null when '
        'anonymous', () async {
      final (app, session) = await harness().signedIn('ctx-key@example.com');
      final current = (await app.call(
        const CurrentKey(),
      )).value(const CurrentKey());
      expect(current.accountId, session.id);
      expect(current.kind, DwSessionKeyKind.app);
      expect(
        (await harness().caller().call(
          const WhichKey(),
        )).value(const WhichKey()),
        isNull,
      );
    });

    test(
      'in a subscription check: the key the socket authenticated with',
      () async {
        final (_, session) = await harness().signedIn('ctx-live@example.com');
        final personal = await accounts().issueKey(session.id, label: 'mcp');
        final appSocket = await harness().live(token: session.token);
        final refused = await appSocket.subscribe('tools');
        expect(
          (refused as DwSubscriptionRefusedMessage).refusal?.code,
          DwCoreRefusal.forbidden.code,
        );
        final toolSocket = await harness().live(token: personal.token);
        expect(await toolSocket.subscribe('tools'), isA<DwSubscribedMessage>());
      },
    );

    test('on routes that authenticate; a route that does not reads no '
        'header', () async {
      final (_, session) = await harness().signedIn('ctx-route@example.com');
      final personal = await accounts().issueKey(session.id, label: 'door');
      final caller = harness().caller();
      Future<DwTestAnswer> get(String path, [String? authorization]) =>
          caller.raw('GET', path, headers: {'authorization': authorization});
      final bearer = 'Bearer ${personal.token}';

      final signed = await get('/key/required', bearer);
      expect(signed.status, 200);
      final body = signed.json! as Map<String, Object?>;
      expect(body['account'], session.id);
      expect(
        DwSessionKeyInfo.fromJson(body['key']! as Map<String, Object?>).kind,
        DwSessionKeyKind.personal,
      );
      expect((await get('/key/optional', bearer)).json, body);
      expect((await get('/key/none', bearer)).json, {
        'account': null,
        'key': null,
      });

      final missing = await get('/key/required');
      expect(missing.status, 401);
      expect(missing.headers.value('www-authenticate'), 'Bearer');
      expect((await get('/key/optional')).json, {'account': null, 'key': null});
      expect((await get('/key/optional', 'Bearer unknown-token')).status, 401);
      expect((await get('/key/optional', 'Basic abc')).status, 400);

      await accounts().revokeKey(personal.key.id);
      expect((await get('/key/required', bearer)).status, 401);
    });
  });
}
