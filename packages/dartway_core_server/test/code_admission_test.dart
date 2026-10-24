import 'package:test/test.dart';

import 'support/test_app.dart';

/// Admission is checked for each verified code, inside the key transaction.
void main() {
  final denied = <String>{};
  final observed = <({int account, String identifier, bool transaction})>[];
  final harness = useHarness(
    build: (app, database) => app.server(
      database,
      auth: app.auth(
        resendDelay: Duration.zero,
        beforeCodeSignIn: (ctx, account, kind, identifier) async {
          observed.add((
            account: account,
            identifier: identifier,
            transaction: ctx.db.inTransaction,
          ));
          if (denied.contains(identifier)) {
            ctx.refuse(DwCoreRefusal.forbidden);
          }
        },
      ),
    ),
  );
  const request = DwRequestCode(kind: DwIdentifierKind.email, identifier: '');
  const verify = DwVerifyCode(ticketId: '', code: '');

  test('denied first sign-in creates neither account nor key', () async {
    const email = 'admission-new@example.com';
    denied.add(email);
    final caller = harness().caller();
    final ticket = (await caller.call(
      const DwRequestCode(kind: DwIdentifierKind.email, identifier: email),
    )).value(request);
    final code = harness().app.delivered[email]!;
    expect(
      (await caller.call(
        DwVerifyCode(ticketId: ticket.id, code: code),
      )).refusal.code,
      'dw.forbidden',
    );
    expect(
      await harness().server.runInContext(
        (ctx) => ctx.accounts.find(DwIdentifierKind.email, email),
      ),
      isNull,
    );
    expect(observed.last.identifier, email);
    expect(observed.last.transaction, isTrue);
    denied.remove(email);
    // Refusal rolled back consumption: the same code can be used after admission.
    final session = (await caller.call(
      DwVerifyCode(ticketId: ticket.id, code: code),
    )).value(verify);
    expect(session.isNewAccount, isTrue);
    final signed = harness().caller(token: session.token);
    expect(
      (await signed.call(const NeedsAccount())).value(const NeedsAccount()),
      session.id,
    );
  });

  test(
    'code issued before denial cannot issue a key for an existing account',
    () async {
      const email = 'admission-existing@example.com';
      final caller = harness().caller();
      final first = await harness().app.signIn(caller, email);
      final ticket = (await caller.call(
        const DwRequestCode(kind: DwIdentifierKind.email, identifier: email),
      )).value(request);
      final code = harness().app.delivered[email]!;
      final keys = await harness().server.runInContext(
        (ctx) => ctx.accounts.listKeys(first.id),
      );
      denied.add(email);
      expect(
        (await caller.call(
          DwVerifyCode(ticketId: ticket.id, code: code),
        )).refusal.code,
        'dw.forbidden',
      );
      expect(observed.last.account, first.id);
      expect(observed.last.transaction, isTrue);
      expect(
        await harness().server.runInContext(
          (ctx) => ctx.accounts.listKeys(first.id),
        ),
        keys,
      );
      denied.remove(email);
      final next = (await caller.call(
        DwVerifyCode(ticketId: ticket.id, code: code),
      )).value(verify);
      expect(next.id, first.id);
      expect(next.isNewAccount, isFalse);
      expect(next.token, isNot(first.token));
    },
  );
}
