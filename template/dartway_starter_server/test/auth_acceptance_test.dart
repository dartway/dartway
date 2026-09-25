import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart';
import 'package:dartway_starter_server/dartway_starter_server.dart';
import 'package:dartway_starter_server/src/profile/profile_rows.dart';
import 'package:dartway_starter_server/src/settings/settings_rows.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:test/test.dart';

import 'support/app_harness.dart';

/// Signing in: by phone and by e-mail with a one-time code, the consent a
/// sign-up needs, sign-up switched off, fixed codes, the first administrator.
void main() {
  late AppHarness app;

  setUpAll(() async => app = await AppHarness.start());
  tearDownAll(() => app.stop());

  test('signing up by phone: the code, the consent, and the profile the '
      'account starts with', () async {
    final device = await app.client();
    final (:ticket, :code) = await app.requestCode(
      device.client,
      '+7 (999) 000-00-10',
    );
    expect(code, matches(RegExp(r'^\d{6}$')));
    expect(app.delivered.keys, contains('79990000010'));

    // A sign-up that sent nothing is refused, and the right code creates
    // nothing — it stays good for the next try.
    expect(
      await device.client.command(
        DwVerifyCode(ticketId: ticket.id, code: code),
      ),
      refusedWith(DartwayStarterRefusal.consentsRequired),
    );
    expect(await app.db.userProfiles.count(), 0);

    final session = (await device.client.command(
      DwVerifyCode(
        ticketId: ticket.id,
        code: code,
        registration: consents(firstName: ' Vera ', marketing: true),
      ),
    )).valueOrThrow;
    expect(session.isNewAccount, isTrue);
    await device.client.signIn(session);

    final profile = (await device.client.fetch(
      const GetMyProfile(),
    )).valueOrThrow;
    expect(profile.phone, '79990000010');
    expect(profile.email, isNull);
    expect(profile.firstName, 'Vera');
    expect(profile.role, UserRole.user);
    expect(profile.agreedForMarketing, isTrue);
    final row = (await app.db.userProfiles.findById(profile.id))!;
    expect(row.termsAcceptedAt, isNotNull);
  });

  test('signing up by e-mail, then signing in again without the consent: an '
      'existing account gave it already', () async {
    final boris = await app.signUp(' Boris@Example.COM ', firstName: 'Boris');
    final profile = (await boris.client.fetch(
      const GetMyProfile(),
    )).valueOrThrow;
    expect(profile.email, 'boris@example.com');
    expect(profile.phone, isNull);

    final again = await app.client();
    final (:ticket, :code) = await app.requestCode(
      again.client,
      'boris@example.com',
    );
    final session = (await again.client.command(
      DwVerifyCode(ticketId: ticket.id, code: code),
    )).valueOrThrow;
    expect(session.id, boris.accountId);
    expect(session.isNewAccount, isFalse);
  });

  test('a wrong code counts down; a malformed identifier is refused on its '
      'field', () async {
    final device = await app.client();
    final (:ticket, :code) = await app.requestCode(
      device.client,
      '79990000011',
    );
    final wrong = await device.client.command(
      DwVerifyCode(
        ticketId: ticket.id,
        code: code == '000000' ? '111111' : '000000',
        registration: consents(),
      ),
    );
    expect(
      wrong,
      isA<DwCallRefused<DwAuthSession>>().having(
        (r) =>
            (r.refusal.code, r.refusal.field, r.refusal.params['attemptsLeft']),
        'refusal',
        (DwCoreRefusal.invalid.code, 'code', '4'),
      ),
    );

    for (final (kind, identifier) in [
      (DwIdentifierKind.email, 'vera@'),
      (DwIdentifierKind.phone, '12345'),
      (DwIdentifierKind.phone, 'vera@example.com'),
    ]) {
      expect(
        await device.client.command(
          DwRequestCode(kind: kind, identifier: identifier),
        ),
        isA<DwCallRefused<DwCodeTicket>>().having(
          (r) => (r.refusal.code, r.refusal.field),
          'refusal',
          (DwCoreRefusal.invalid.code, 'identifier'),
        ),
        reason: identifier,
      );
    }
  });

  test('with sign-up switched off a new identifier is refused and an existing '
      'account still signs in', () async {
    final member = await app.signUp('79990000020', firstName: 'Oleg');
    await app.db.appSettings.insert(
      const AppSettingRow(key: AppSettingKeys.signUpEnabled, value: 'false'),
    );
    addTearDown(
      () => app.db.appSettings.deleteWhere(
        where: (t) => t.key.equals(AppSettingKeys.signUpEnabled),
      ),
    );

    final stranger = await app.client();
    final newcomer = await app.requestCode(stranger.client, '79990000021');
    expect(
      await stranger.client.command(
        DwVerifyCode(
          ticketId: newcomer.ticket.id,
          code: newcomer.code,
          registration: consents(),
        ),
      ),
      refusedWith(DartwayStarterRefusal.signUpClosed),
    );

    final returning = await app.requestCode(stranger.client, '79990000020');
    final session = (await stranger.client.command(
      DwVerifyCode(ticketId: returning.ticket.id, code: returning.code),
    )).valueOrThrow;
    expect(session.id, member.accountId);
  });

  test('a fixed code on the profile signs the account in, and nothing is '
      'delivered', () async {
    final reviewer = await app.signUp('79990000030', firstName: 'Reviewer');
    final row = await reviewer.profileRow();
    await app.db.userProfiles.update(
      row.copyWith(testVerificationCode: const DwFieldPatch.set('424242')),
    );
    app.delivered.remove('79990000030');

    final store = await app.client();
    final ticket = (await store.client.command(
      const DwRequestCode(
        kind: DwIdentifierKind.phone,
        identifier: '79990000030',
      ),
    )).valueOrThrow;
    expect(app.delivered, isNot(contains('79990000030')));
    final session = (await store.client.command(
      DwVerifyCode(ticketId: ticket.id, code: '424242'),
    )).valueOrThrow;
    expect(session.id, reviewer.accountId);
  });

  test('the declared first administrator: created with the account, '
      'promoted on a later start, quiet when nothing changed', () async {
    final server = app.server.server;
    DwFirstAdministrator declaring(String identifier) => DwFirstAdministrator(
      grant: AppBootstrap.grantAdmin,
      environment: {DwFirstAdministrator.defaultVariable: identifier},
    );
    Future<void> start(String identifier) =>
        server.runInContext(declaring(identifier).run);

    // A mistyped identifier is a server that does not start, judged before
    // anything opens.
    expect(
      declaring('not an identifier').problems(AppAuth.config()),
      [contains(DwFirstAdministrator.defaultVariable)],
    );
    expect(declaring('Admin@Example.com').problems(AppAuth.config()), isEmpty);

    await start('Admin@Example.com');
    final created = (await app.db.userProfiles.findFirst(
      where: (t) => t.role.equals(UserRole.admin) & t.firstName.equals('Admin'),
    ))!;
    expect(
      created.termsAcceptedAt,
      isNull,
      reason: "a tool accepts nothing on anyone's behalf",
    );

    // The identifier is stored normalised, so the next start finds the same
    // account rather than creating a second one.
    final profiles = await app.db.userProfiles.count();
    await start('admin@example.com');
    expect(await app.db.userProfiles.count(), profiles);

    // Demoted in the panel, back on the next start.
    await app.db.userProfiles.update(created.copyWith(role: UserRole.user));
    await start('admin@example.com');
    expect(
      (await app.db.userProfiles.findById(created.id!))!.role,
      UserRole.admin,
    );

    final device = await app.client();
    final (:ticket, :code) = await app.requestCode(
      device.client,
      'admin@example.com',
    );
    final session = (await device.client.command(
      DwVerifyCode(ticketId: ticket.id, code: code),
    )).valueOrThrow;
    expect(session.id, created.accountId);
    await device.client.signIn(session);
    expect((await device.client.fetch(const GetAdminCounters())).isOk, isTrue);
  });
}
