import 'package:dartway_core_server/testing.dart';
import 'package:dartway_starter_server/src/profile/profile_objects.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:test/test.dart';

import '../../support/app_harness.dart';

/// A signed-in member attaches or changes the phone and the e-mail they sign
/// in with, by a code sent to the new one — without signing in again. The
/// framework keeps the identifiers; the app shows them on the profile and
/// republishes it on every change.
void main() {
  late AppHarness app;

  setUpAll(() async => app = await AppHarness.start());
  tearDownAll(() => app.stop());

  test(
    'user cards share one identity read with their profiles, for one or many rows',
    () async {
      final member = await app.signUp('79990005030', firstName: 'Batch member');
      final row = await member.profileRow();
      final other = await app.signUp(
        'batch5031@example.com',
        firstName: 'Other member',
      );
      final otherRow = await other.profileRow();
      await app.server.runInContext((ctx) async {
        // Count actual reads on this transaction's connection, independent of
        // other clients and of whether Postgres would otherwise choose an index.
        await ctx.db.execute(
          'SET LOCAL enable_indexscan = off; '
          'SET LOCAL enable_bitmapscan = off',
        );
        final card = await ProfileObjects.card(ctx, row);
        expect(card.profile.phone, '79990005030');
        expect(card.identifiers.map((identity) => identity.value), [
          '79990005030',
        ]);
        final stats = await ctx.db.query(
          "SELECT seq_scan FROM pg_stat_xact_user_tables WHERE relname = 'dw_identity'",
        );
        expect(
          stats.single.get<int>('seq_scan'),
          1,
          reason: 'the card and its nested profile share one identity read',
        );
        final cards = await ProfileObjects.cards(ctx, [otherRow, row]);
        expect(cards.map((card) => card.id), [otherRow.id, row.id]);
        expect(cards.first.profile.email, 'batch5031@example.com');
        expect(cards.first.profile.phone, isNull);
        expect(cards.first.identifiers.map((identity) => identity.value), [
          'batch5031@example.com',
        ]);
        expect(cards.last, card);
        expect(cards.first.termsAcceptedAt, otherRow.termsAcceptedAt);
        expect(await ProfileObjects.cards(ctx, []), isEmpty);
        final afterBatch = await ctx.db.query(
          "SELECT seq_scan FROM pg_stat_xact_user_tables WHERE relname = 'dw_identity'",
        );
        expect(
          afterBatch.single.get<int>('seq_scan'),
          2,
          reason:
              'one more read for the whole batch and none for an empty batch',
        );
      });
    },
  );

  /// Asks for a code to attach [identifier] as [member] and answers the ticket
  /// and the code that arrived.
  Future<({DwCodeTicket ticket, String code})> requestAttachCode(
    AppMember member,
    String identifier,
  ) async {
    final kind = DwIdentifierKind.of(identifier);
    final ticket = (await member.client.command(
      DwRequestIdentifierCode(kind: kind, identifier: identifier),
    )).valueOrThrow;
    return (
      ticket: ticket,
      code: app.delivered[AuthIdentifier.normalize(kind, identifier)]!,
    );
  }

  test('a member signed up by phone attaches an e-mail by code: their own '
      "profile and the admin's user card follow live, and the e-mail then "
      'signs in to the same account', () async {
    final admin = await app.admin('79990005001', 'Anna');
    final vera = await app.signUp('79990005002', firstName: 'Vera');
    final profile = await vera.watch(const GetMyProfile());
    final card = await admin.watch(
      GetUserCard(profileId: await vera.profileId),
    );
    expect(dataOf(profile.state)!.email, isNull);
    expect(dataOf(card.state)!.identifiers, hasLength(1));

    final (:ticket, :code) = await requestAttachCode(
      vera,
      ' Vera.New@Example.com ',
    );
    // A wrong code counts against the ticket and attaches nothing.
    expect(
      await vera.client.command(
        DwConfirmIdentifier(
          ticketId: ticket.id,
          code: code == '000000' ? '111111' : '000000',
        ),
      ),
      refusedWith(DwCoreRefusal.invalid),
    );
    final identity = (await vera.client.command(
      DwConfirmIdentifier(ticketId: ticket.id, code: code),
    )).valueOrThrow;
    expect(identity.accountId, vera.accountId);
    expect(identity.kind, DwIdentifierKind.email);
    expect(identity.value, 'vera.new@example.com');
    expect(identity.verifiedAt, isNotNull);

    // From the answer alone, for the author; over the socket, for the admin.
    expect(dataOf(profile.state)!.email, 'vera.new@example.com');
    expect(dataOf(profile.state)!.phone, '79990005002');
    await dwWaitUntil(
      () => dataOf(card.state)!.profile.email == 'vera.new@example.com',
    );
    expect(dataOf(card.state)!.identifiers.map((i) => (i.kind, i.value)), [
      (DwIdentifierKind.phone, '79990005002'),
      (DwIdentifierKind.email, 'vera.new@example.com'),
    ]);

    final again = await app.client();
    final signIn = await app.requestCode(again.client, 'vera.new@example.com');
    final session = (await again.client.command(
      DwVerifyCode(ticketId: signIn.ticket.id, code: signIn.code),
    )).valueOrThrow;
    expect(session.id, vera.accountId);
    expect(session.isNewAccount, isFalse);
  });

  test('changing the phone replaces it in place: the old number is free, the '
      'members table finds the new one', () async {
    final admin = await app.admin('79990005010', 'Anna');
    final oleg = await app.signUp('79990005011', firstName: 'Oleg');
    final profile = await oleg.watch(const GetMyProfile());
    final accounts = app.server.server.accounts;
    final before = (await accounts.listIdentities(oleg.accountId)).single;

    final (:ticket, :code) = await requestAttachCode(oleg, '+7 999 000-50-12');
    final identity = (await oleg.client.command(
      DwConfirmIdentifier(ticketId: ticket.id, code: code, replace: true),
    )).valueOrThrow;
    expect(identity.value, '79990005012');
    expect(identity.id, before.id, reason: 'replaced in place');
    expect(dataOf(profile.state)!.phone, '79990005012');

    expect(
      await accounts.find(DwIdentifierKind.phone, '79990005012'),
      oleg.accountId,
    );
    expect(await accounts.find(DwIdentifierKind.phone, '79990005011'), isNull);
    expect(await accounts.listIdentities(oleg.accountId), hasLength(1));

    final found = (await admin.client.fetch(
      const ListUserProfiles(search: '5012'),
    )).valueOrThrow;
    expect(found.items.single.accountId, oleg.accountId);
    expect(
      (await admin.client.fetch(
        const ListUserProfiles(search: '5011'),
      )).valueOrThrow.items,
      isEmpty,
    );
  });

  test("another account's identifier: the code is sent as for a free one, and "
      'only the right code learns it is taken — on the code field, with '
      'nothing changed', () async {
    final boris = await app.signUp('boris5020@example.com');
    final nina = await app.signUp('79990005021', firstName: 'Nina');
    final profile = await nina.watch(const GetMyProfile());

    final (:ticket, :code) = await requestAttachCode(
      nina,
      'boris5020@example.com',
    );
    final taken = await nina.client.command(
      DwConfirmIdentifier(ticketId: ticket.id, code: code),
    );
    expect(taken, refusedWith(DwAuthRefusal.identifierTaken));
    expect((taken as DwCallRefused).refusal.field, 'code');

    final accounts = app.server.server.accounts;
    expect(
      await accounts.find(DwIdentifierKind.email, 'boris5020@example.com'),
      boris.accountId,
    );
    expect(await accounts.listIdentities(nina.accountId), hasLength(1));
    expect(dataOf(profile.state)!.email, isNull);
  });
}
