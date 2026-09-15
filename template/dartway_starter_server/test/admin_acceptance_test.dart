import 'dart:convert';

import 'package:dartway_core_server/testing.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:test/test.dart';

import 'support/app_harness.dart';

/// The admin panel on real clients: a role changed arrives live at the member
/// it concerns and at every admin screen, the table pages and filters on the
/// server, and settings reach every signed-in member.
void main() {
  late AppHarness app;

  setUpAll(() async => app = await AppHarness.start());
  tearDownAll(() => app.stop());

  const adminChannel = DwLiveChannel(DartwayStarterChannel.admin);

  test(
    'a role change is live: the member hears their own new role and gains '
    'the panel, loses it again on demotion, and the counters follow',
    () async {
      final anna = await app.admin('79990006001', 'Anna');
      final vera = await app.signUp('79990006002', firstName: 'Vera');
      final veraProfile = await vera.watch(const GetMyProfile());
      final counters = await anna.watch(const GetAdminCounters());
      final admins = dataOf(counters.state)!.admins;

      expect(
        await vera.client.fetch(const GetAdminCounters()),
        refusedWith(DwCoreRefusal.forbidden),
      );
      expect(
        await vera.client.command(
          ChangeUserRole(profileId: await vera.profileId, role: UserRole.admin),
        ),
        refusedWith(DwCoreRefusal.forbidden),
      );

      final promoted = (await anna.client.command(
        ChangeUserRole(profileId: await vera.profileId, role: UserRole.admin),
      )).valueOrThrow;
      expect(promoted.role, UserRole.admin);
      // The author's dashboard from the answer; the member's own profile over
      // their socket, without asking.
      expect(dataOf(counters.state)!.admins, admins + 1);
      await eventually(
        () => dataOf(veraProfile.state)!.role == UserRole.admin,
        reason: "Vera's profile hears the promotion",
      );
      expect(
        vera.http.posts('GetMyProfile'),
        1,
        reason: 'the change arrived live, not by a re-read',
      );

      final veraCounters = await vera.watch(const GetAdminCounters());
      expect(dataOf(veraCounters.state)!.admins, admins + 1);

      (await anna.client.command(
        ChangeUserRole(profileId: await vera.profileId, role: UserRole.user),
      )).valueOrThrow;
      await eventually(
        () => dataOf(veraProfile.state)!.role == UserRole.user,
        reason: "Vera's profile hears the demotion",
      );
      // Access is checked at subscription: the channel it opened is closed.
      await eventually(
        () => vera.live.closuresOf(adminChannel).isNotEmpty,
        reason: 'the admin channel is revoked',
      );
      expect(
        await vera.client.fetch(const GetAdminCounters()),
        refusedWith(DwCoreRefusal.forbidden),
      );
      expect(dataOf(counters.state)!.admins, admins);
    },
  );

  test('an admin cannot change their own role', () async {
    final anna = await app.admin('79990006010', 'Anna');
    expect(
      await anna.client.command(
        ChangeUserRole(profileId: await anna.profileId, role: UserRole.user),
      ),
      refusedWith(DartwayStarterRefusal.ownRoleLocked),
    );
    expect((await anna.profileRow()).role, UserRole.admin);
  });

  test('the members table pages, searches by name, phone and e-mail and '
      'filters by role on the server; a newcomer moves the page and the '
      'total live', () async {
    final anna = await app.admin('79990006020', 'Anna');
    await app.signUp('table.one@example.com', firstName: 'Tabitha');
    await app.signUp('79990006022', firstName: 'Timur');

    final byEmail = (await anna.client.fetch(
      const ListUserProfiles(search: 'TABLE.ONE'),
    )).valueOrThrow;
    expect(byEmail.items.single.firstName, 'Tabitha');
    final byPhone = (await anna.client.fetch(
      const ListUserProfiles(search: '6022'),
    )).valueOrThrow;
    expect(byPhone.items.single.firstName, 'Timur');
    final byName = (await anna.client.fetch(
      const ListUserProfiles(search: 'tim'),
    )).valueOrThrow;
    expect(byName.items.single.phone, '79990006022');
    final adminsOnly = (await anna.client.fetch(
      const ListUserProfiles(role: UserRole.admin),
    )).valueOrThrow;
    expect(adminsOnly.items.map((p) => p.role).toSet(), {UserRole.admin});

    final table = await anna.watchTable(const ListUserProfiles(pageSize: 2));
    final before = dataOf(table.state)!;
    expect(before.items, hasLength(2));
    final counters = await anna.watch(const GetAdminCounters());
    final members = dataOf(counters.state)!.members;

    final newcomer = await app.signUp('79990006023', firstName: 'Newcomer');
    await eventually(
      () => dataOf(table.state)!.total == before.total + 1,
      reason: 'the page reads itself again',
    );
    expect(
      dataOf(table.state)!.items.first.accountId,
      newcomer.accountId,
      reason: 'newest first',
    );
    await eventually(() => dataOf(counters.state)!.members == members + 1);
  });

  test("a member's own change: the member's screens update from the response, "
      "which never carries the admins' copy published with it; the admins "
      'hear it over the socket', () async {
    final anna = await app.admin('79990006040', 'Anna');
    final vera = await app.signUp('79990006041', firstName: 'Vera');
    final veraProfile = await vera.watch(const GetMyProfile());
    await anna.watch(const GetAdminCounters());

    (await vera.client.command(
      const UpdateMyProfile(firstName: 'Veronika'),
    )).valueOrThrow;
    expect(
      dataOf(veraProfile.state)!.firstName,
      'Veronika',
      reason: 'applied from the response before the command completed',
    );
    final updates = vera.http.lastReply('UpdateMyProfile')['updates']! as Map;
    expect(updates.keys, ['profile:${vera.accountId}']);

    await eventually(
      () => anna.live.received.any(
        (frame) =>
            frame['k'] == 'upd' &&
            frame['ch'] == adminChannel.wireName &&
            jsonEncode(frame).contains('Veronika'),
      ),
      reason: 'the admin table hears the change',
    );
  });

  test('settings: an admin saves one and every signed-in member hears it; '
      'nobody else may, and an unknown key never leaves the client', () async {
    final anna = await app.admin('79990006030', 'Anna');
    final vera = await app.signUp('79990006031', firstName: 'Vera');
    final settings = await vera.watch(const ListAppSettings());

    (await anna.client.command(
      const SaveAppSetting(key: AppSettingKeys.appName, value: 'Acme'),
    )).valueOrThrow;
    await eventually(
      () => dataOf(settings.state)!.any(
        (setting) =>
            setting.id == AppSettingKeys.appName && setting.value == 'Acme',
      ),
    );

    expect(
      await vera.client.command(
        const SaveAppSetting(key: AppSettingKeys.appName, value: 'Mine'),
      ),
      refusedWith(DwCoreRefusal.forbidden),
    );
    expect(
      await anna.client.command(
        const SaveAppSetting(key: 'colour', value: 'red'),
      ),
      refusedWith(DartwayStarterRefusal.settingKeyUnknown),
    );
    expect(
      anna.http.posts('SaveAppSetting'),
      1,
      reason: 'refused before sending',
    );
  });
}
