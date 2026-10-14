import 'dart:async';
import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';
import 'support/test_app.dart';

final class LinkClock extends DwServerClock {
  DateTime value = DateTime.now().toUtc();
  @override
  DateTime now() => value;
}

void main() {
  test('link policies validate trusted absolute templates and lifetime', () {
    Future<void> delivery(
      DwCallContext ctx,
      DwIdentifierKind kind,
      String identifier,
      Uri link,
    ) async {}
    for (final template in [
      'relative/{token}',
      'https://example.com/no-token',
      'https://example.com/{token}/{token}',
      'https://user:password@example.com/{token}',
      'javascript:{token}',
    ]) {
      expect(
        () => DwIdentifierLinkPolicy(
          urlTemplate: template,
          deliverLink: delivery,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => DwIdentifierLinkPolicy(
        urlTemplate: 'https://example.com/{token}',
        lifetime: Duration.zero,
        deliverLink: delivery,
      ),
      throwsArgumentError,
    );
    expect(
      DwIdentifierLinkPolicy(
        urlTemplate: 'app://confirm/{token}',
        deliverLink: delivery,
      ).lifetime,
      const Duration(hours: 24),
    );
  });
  final clock = LinkClock();
  final links = <String, Uri>{};
  var deliveries = 0;
  var failDelivery = false;
  Completer<void>? entered;
  Completer<void>? release;
  final harness = useHarness(
    build: (app, config) => app.server(
      config,
      clock: clock,
      auth: app.auth(
        resendDelay: Duration.zero,
        maxRequestsPerWindow: 20,
        attachDelivery: {
          DwIdentifierKind.email: DwIdentifierLinkPolicy(
            urlTemplate: 'https://example.com/#/confirm?token={token}',
            replace: true,
            deliverLink: (ctx, kind, identifier, link) async {
              final rows = await ctx.db.query(
                "SELECT id FROM dw_code_ticket WHERE identifier = @id AND delivery = 'link'",
                params: {'id': identifier},
              );
              expect(
                rows,
                isNotEmpty,
                reason: 'delivery observes committed ticket',
              );
              deliveries++;
              links[identifier] = link;
              entered?.complete();
              if (release != null) await release!.future;
              if (failDelivery) throw StateError('provider unavailable');
            },
          ),
        },
      ),
    ),
  );
  late DwTestCaller owner;
  late DwAuthSession account;
  setUp(() async {
    clock.value = DateTime.now().toUtc();
    owner = harness().caller();
    account = await harness().app.signIn(owner, 'owner$deliveries@example.com');
    owner.token = account.token;
  });
  Future<DwCodeTicket> request(String address, {String? key}) async {
    final command = DwRequestIdentifierCode(
      kind: DwIdentifierKind.email,
      identifier: address,
    );
    return (await owner.call(command, key: key)).value(command);
  }

  String token(String address) =>
      Uri.parse(links[address]!.fragment).queryParameters['token']!;
  Future<DwTestAnswer> confirm(
    String address, {
    DwTestCaller? caller,
    String? key,
  }) => (caller ?? harness().caller()).call(
    DwConfirmIdentifierLink(token: token(address)),
    key: key,
  );
  Future<List<DwIdentityInfo>> identities() =>
      harness().server.server.accounts.listIdentities(account.id);
  void invalid(DwTestAnswer answer) => expect(
    answer.refusal,
    DwCallRefusal(DwCoreRefusal.invalid, field: 'token'),
  );

  test(
    'anonymous confirmation binds account, replaces stably, returns no session, single use',
    () async {
      final before = await identities();
      final ticket = await request('new@example.com');
      expect((await identities()).first.value, before.first.value);
      expect(
        ticket.expiresAt.difference(clock.value),
        const Duration(hours: 24),
      );
      final answer = await confirm('new@example.com', key: 'confirm-once');
      expect(answer.status, 200);
      final after = await identities();
      expect(after.single.id, before.single.id);
      expect(after.single.value, 'new@example.com');
      expect(after.single.verifiedAt, isNotNull);
      invalid(await confirm('new@example.com', key: 'confirm-once'));
      expect(owner.token, account.token);
      final secret = token('new@example.com');
      expect(secret.length, 22);
      final dump = await harness().db.query(
        'SELECT row_to_json(t)::text AS value FROM dw_code_ticket t UNION ALL SELECT row_to_json(o)::text AS value FROM dw_command_outcome o',
      );
      expect(
        dump.map((r) => r.get<String>('value')).join(),
        isNot(contains(secret)),
      );
      expect(RecordingLogger.lines.join(), isNot(contains(secret)));
      expect(
        DwConfirmIdentifierLink(token: secret).toString(),
        isNot(contains(secret)),
      );
    },
  );
  test(
    'foreign session stays foreign; latest request invalidates across destinations, preserves history',
    () async {
      final foreign = harness().caller();
      final other = await harness().app.signIn(foreign, 'foreign@example.com');
      foreign.token = other.token;
      await request('old-link@example.com');
      await request('latest-link@example.com');
      invalid(await confirm('old-link@example.com'));
      expect(
        (await confirm('latest-link@example.com', caller: foreign)).status,
        200,
      );
      expect(foreign.token, other.token);
      expect(
        (await harness().server.server.accounts.listIdentities(
          other.id,
        )).single.value,
        'foreign@example.com',
      );
      final rows = await harness().db.query(
        "SELECT id FROM dw_code_ticket WHERE account_id = @id AND delivery = 'link'",
        params: {'id': account.id},
      );
      expect(rows, hasLength(2));
    },
  );
  test(
    'expiry, occupied address, unknown and code downgrade are generic',
    () async {
      await request('expired@example.com');
      clock.value = clock.value.add(const Duration(hours: 24));
      invalid(await confirm('expired@example.com'));
      clock.value = DateTime.now().toUtc();
      final foreign = harness().caller();
      await harness().app.signIn(foreign, 'taken@example.com');
      final free = await request('free-shape@example.com');
      final ticket = await request('taken@example.com');
      expect(ticket.toJson().keys, free.toJson().keys);
      expect(ticket.expiresAt, free.expiresAt);
      expect(ticket.resendAfter, free.resendAfter);
      final code = await owner.call(
        DwConfirmIdentifier(ticketId: ticket.id, code: '123456', replace: true),
      );
      expect(code.refusal.code, 'dw.codeExpired');
      invalid(await confirm('taken@example.com'));
      invalid(await confirm('taken@example.com'));
      invalid(
        await harness().caller().call(
          const DwConfirmIdentifierLink(token: 'unknown'),
        ),
      );
    },
  );
  test(
    'concurrent confirmations perform exactly one confirmed change',
    () async {
      await request('race@example.com');
      final answers = await Future.wait([
        confirm('race@example.com'),
        confirm('race@example.com'),
      ]);
      expect(answers.where((a) => a.status == 200), hasLength(1));
      invalid(answers.singleWhere((a) => a.status != 200));
      expect(
        harness().app.identifierChanges.where(
          (c) => c.current == 'race@example.com',
        ),
        hasLength(1),
      );
    },
  );
  test(
    'duplicate request during delivery replays metadata and delivers once; failure keeps ticket',
    () async {
      entered = Completer();
      release = Completer();
      final count = deliveries;
      final pending = request('gated@example.com', key: 'gated-request');
      await entered!.future;
      final replay = await request('gated@example.com', key: 'gated-request');
      release!.complete();
      expect(await pending, replay);
      expect(deliveries, count + 1);
      entered = null;
      release = null;
      failDelivery = true;
      final command = DwRequestIdentifierCode(
        kind: DwIdentifierKind.email,
        identifier: 'failed@example.com',
      );
      final failed = await owner.call(command);
      expect(failed.status, 500);
      failDelivery = false;
      expect((await confirm('failed@example.com')).status, 200);
    },
  );
  test(
    'throwing confirmed hook rolls back identity and consumption; retry succeeds',
    () async {
      await request('rollback@example.com');
      final before = await identities();
      harness().app.failingIdentifierChanges.add('rollback@example.com');
      expect((await confirm('rollback@example.com')).status, 500);
      final secret = token('rollback@example.com');
      expect(
        harness().app.alerts.incidents
            .map((i) => '${i.where} ${i.error} ${i.stackTrace}')
            .join(),
        isNot(contains(secret)),
      );
      expect(RecordingLogger.lines.join(), isNot(contains(secret)));
      expect(await identities(), before);
      final rows = await harness().db.query(
        "SELECT consumed_at FROM dw_code_ticket WHERE identifier = 'rollback@example.com'",
      );
      expect(rows.single['consumed_at'], isNull);
      harness().app.failingIdentifierChanges.clear();
      expect((await confirm('rollback@example.com')).status, 200);
    },
  );
  test(
    'parallel requests across destinations keep exactly one usable link',
    () async {
      await Future.wait([
        request('parallel-one@example.com'),
        request('parallel-two@example.com'),
      ]);
      final answers = await Future.wait([
        confirm('parallel-one@example.com'),
        confirm('parallel-two@example.com'),
      ]);
      expect(answers.where((a) => a.status == 200), hasLength(1));
      invalid(answers.singleWhere((a) => a.status != 200));
    },
  );
  test(
    'request racing confirm has a serial outcome and leaves the newest link usable',
    () async {
      await request('before-race@example.com');
      final pendingConfirm = confirm('before-race@example.com');
      await request('after-race@example.com');
      final answer = await pendingConfirm;
      if (answer.status != 200) invalid(answer);
      expect((await confirm('after-race@example.com')).status, 200);
      expect((await identities()).single.value, 'after-race@example.com');
    },
  );
  test(
    'account deletion removes links, landing gives generic invalid without changing foreign session',
    () async {
      await request('deleted@example.com');
      await harness().server.server.accounts.deleteAccount(account.id);
      invalid(await confirm('deleted@example.com'));
    },
  );
  test('resend history remains counted after supersession', () async {
    for (var i = 0; i < 20; i++) {
      await request('limited@example.com');
    }
    final answer = await owner.call(
      const DwRequestIdentifierCode(
        kind: DwIdentifierKind.email,
        identifier: 'limited@example.com',
      ),
    );
    expect(answer.refusal.code, 'dw.tooManyRequests');
    expect((await confirm('limited@example.com')).status, 200);
  });
  test('phone still uses code and cannot be confirmed as a link', () async {
    const requestPhone = DwRequestIdentifierCode(
      kind: DwIdentifierKind.phone,
      identifier: '+79990000111',
    );
    final ticket = (await owner.call(requestPhone)).value(requestPhone);
    final code = harness().app.delivered[requestPhone.identifier]!;
    final confirmation = DwConfirmIdentifier(ticketId: ticket.id, code: code);
    expect(
      (await owner.call(confirmation)).value(confirmation).value,
      requestPhone.identifier,
    );
  });
  test(
    'a confirmation queued behind deletion revalidates its bound account',
    () async {
      await request('deletion-race@example.com');
      final entered = Completer<void>();
      final release = Completer<void>();
      harness().app.gatedAccountDeletion.add(account.id);
      harness().app.accountDeletingEntered = entered;
      harness().app.accountDeletingGate = release;
      final batch = harness().server.server.accounts.deleteAccount(account.id);
      await entered.future;
      final landing = confirm('deletion-race@example.com');
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
      invalid(await landing);
      harness().app.gatedAccountDeletion.remove(account.id);
    },
  );
}
