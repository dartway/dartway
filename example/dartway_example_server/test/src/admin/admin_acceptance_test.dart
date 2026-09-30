import 'package:dartway_core_server/testing.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:test/test.dart';

import '../../support/app_harness.dart';

/// The admin panel's members and roles, on real clients against the real
/// server.
void main() {
  late AppHarness club;

  setUpAll(() async => club = await AppHarness.start());
  tearDownAll(() => club.stop());

  test("an admin changing a member's role: the member's own profile follows "
      "live, and the admin's own profile is not touched by it", () async {
    final admin = await club.withRole('79990000023', 'Anna', UserRole.admin);
    final member = await club.signUp('79990000024', firstName: 'Pavel');
    final adminProfile = admin.client.watch(const GetMyProfile());
    final memberProfile = member.client.watch(const GetMyProfile());
    addTearDown(() {
      adminProfile.close();
      memberProfile.close();
    });
    await dwWaitUntil(() => adminProfile.isLive && memberProfile.isLive);
    final before = dataOf(adminProfile.state)!;
    expect(before.role, UserRole.admin);

    final changed = await admin.client.command(
      ChangeRole(
        profileId: dataOf(memberProfile.state)!.id,
        role: UserRole.staff,
      ),
    );
    expect(changed.valueOrThrow.accountId, member.accountId);
    await dwWaitUntil(
      () => dataOf(memberProfile.state)?.role == UserRole.staff,
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      dataOf(adminProfile.state),
      before,
      reason:
          "a UserProfile went to profile:${member.accountId}, which the "
          "admin's own profile does not declare",
    );
  });

  test('the members table pages with its total', () async {
    final admin = await club.withRole('79990000016', 'Admin', UserRole.admin);
    for (var i = 1; i <= 5; i++) {
      await club.signUp('7999002000$i', firstName: 'Pager $i');
    }
    Future<DwTablePage<UserProfile>> page(int number) async =>
        (await admin.client.fetch(
          ListUserProfiles(page: number, pageSize: 2, search: 'pager'),
        )).valueOrThrow;

    final first = await page(1);
    expect(first.total, 5);
    expect(first.pageCount, 3);
    expect(first.items.map((p) => p.firstName), ['Pager 1', 'Pager 2']);
    final last = await page(3);
    expect(last.items.map((p) => p.firstName), ['Pager 5']);
    expect(last.total, 5);

    final staff = await club.withRole('79990000017', 'Staff', UserRole.staff);
    final refused = await staff.client.fetch(const ListUserProfiles());
    expect(
      refused,
      isA<DwCallRefused<DwTablePage<UserProfile>>>().having(
        (r) => r.refusal.isCode(DwCoreRefusal.forbidden),
        'forbidden',
        isTrue,
      ),
    );
  });

  test('a new member reaches the admin table live; a role change updates its '
      'row in place', () async {
    final admin = await club.withRole('79990000018', 'Admin', UserRole.admin);
    await club.signUp('79990000019', firstName: 'Newcomer A');
    const request = ListUserProfiles(search: 'newcomer');
    final table = admin.client.watchTable(request);
    addTearDown(table.close);
    await dwWaitUntil(() => table.isLive);
    expect(dataOf(table.state)!.total, 1);
    expect(admin.http.posts('ListUserProfiles'), 1);

    await club.signUp('79990000020', firstName: 'Newcomer B');
    await dwWaitUntil(() => dataOf(table.state)?.total == 2);
    expect(dataOf(table.state)!.items.map((p) => p.firstName), [
      'Newcomer A',
      'Newcomer B',
    ]);
    expect(admin.http.posts('ListUserProfiles'), 2, reason: 'read once more');

    final newcomer = dataOf(table.state)!.items.last;
    final changed = await admin.client.command(
      ChangeRole(profileId: newcomer.id, role: UserRole.staff),
    );
    expect(changed.valueOrThrow.role, UserRole.staff);
    expect(dataOf(table.state)!.items.last.role, UserRole.staff);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      admin.http.posts('ListUserProfiles'),
      2,
      reason: 'the row came in the response; the page was not read again',
    );
  });
}
