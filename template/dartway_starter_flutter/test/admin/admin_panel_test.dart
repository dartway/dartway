import 'package:dartway_starter_flutter/core/app_settings/app_setting_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_test_app.dart';

UserProfile member(int n, {UserRole role = UserRole.user}) => UserProfile(
  id: 100 + n,
  accountId: 1000 + n,
  phone: '7999100${n.toString().padLeft(4, '0')}',
  firstName: 'Member ${n.toString().padLeft(2, '0')}',
  role: role,
  joinedAt: DateTime.utc(2026, 9, 1),
);

/// The admin panel over a fake server: the members table, the user card and
/// the settings, live.
void main() {
  /// An admin whose server knows [members] and answers the panel's reads.
  FakeApp adminWith(List<UserProfile> members) {
    final fake = FakeApp(role: UserRole.admin, firstName: 'Anna');
    fake.server
      ..onRequest<GetAdminCounters>(
        (request, call) => DwCallOk(
          AdminCounters(
            members: members.length,
            admins: members.where((m) => m.isAdmin).length,
            marketingOptIns: 0,
          ),
        ),
      )
      ..onRequest<ListUserProfiles>(
        (request, call) => DwCallOk(dwFakeTablePage(members, request)),
      );
    return fake;
  }

  Future<TestApp> openUsers(WidgetTester tester, FakeApp fake) async {
    final app = await TestApp.start(tester, fake, size: const Size(390, 900));
    await app.tap(tester, find.text('Profile'));
    await app.tap(tester, find.text('Admin panel'));
    await app.tap(tester, find.text('Users'));
    return app;
  }

  testWidgets('the members table switches pages, and a member signing up '
      'updates the page and its total', (tester) async {
    final members = [for (var n = 1; n <= 23; n++) member(n)];
    final fake = adminWith(members);
    final app = await openUsers(tester, fake);
    expect(find.text('Page 1 of 3 · 23 members'), findsOneWidget);
    expect(find.text('Member 01'), findsOneWidget);

    await app.tap(tester, find.byTooltip('Next page'));
    expect(find.text('Page 2 of 3 · 23 members'), findsOneWidget);
    expect(find.text('Member 11'), findsOneWidget);
    expect(find.text('Member 01'), findsNothing);

    // The newcomer is not on this page, so the page is read again: only the
    // server knows the new total and where the row falls.
    members.add(member(24));
    app.server.publish(adminChannel, [members.last]);
    await app.settle(tester);
    expect(find.text('Page 2 of 3 · 24 members'), findsOneWidget);

    await app.tap(tester, find.byTooltip('Previous page'));
    final pageReads = app.server.requestsOf<ListUserProfiles>().length;

    // A member on the page changes: replaced in place, not read again.
    members[0] = members[0].copyWith(firstName: 'Member 01 renamed');
    app.server.publish(adminChannel, [members[0]]);
    await app.settle(tester);
    expect(find.text('Member 01 renamed'), findsOneWidget);
    expect(app.server.requestsOf<ListUserProfiles>(), hasLength(pageReads));

    await app.stop(tester);
  });

  testWidgets('a role is changed after a confirmation, and the row follows '
      "the answer; the admin's own role is not offered", (tester) async {
    final members = [member(1)];
    final fake = adminWith(members);
    fake.server.onCommand<ChangeUserRole>((command, call) {
      members[0] = members[0].copyWith(role: command.role);
      call.publish(adminChannel, [members[0]]);
      return DwCallOk(members[0]);
    });
    final app = await openUsers(tester, fake);

    await app.tap(tester, find.byType(DropdownButton<UserRole>).first);
    await app.tap(tester, find.text('Admin').last);
    expect(find.text('Change the role of Member 01 to Admin?'), findsOneWidget);
    expect(app.server.callsOf<ChangeUserRole>(), isEmpty);

    await app.tap(tester, find.text('OK'));
    expect(
      app.server.callsOf<ChangeUserRole>().single.call,
      const ChangeUserRole(profileId: 101, role: UserRole.admin),
    );
    expect(
      tester
          .widget<DropdownButton<UserRole>>(
            find.byType(DropdownButton<UserRole>).first,
          )
          .value,
      UserRole.admin,
    );

    await app.stop(tester);
  });

  testWidgets('a member opens as a card with how they sign in, and the card '
      'follows a change live', (tester) async {
    final members = [member(1)];
    final fake = adminWith(members);
    UserCard card() => UserCard(
      id: members[0].id,
      profile: members[0],
      identifiers: [
        UserIdentifier(
          id: 1,
          kind: DwIdentifierKind.phone,
          value: members[0].phone!,
          addedAt: DateTime.utc(2026, 9, 1),
          verifiedAt: DateTime.utc(2026, 9, 1),
        ),
      ],
      termsAcceptedAt: DateTime.utc(2026, 9, 1),
    );
    fake.server.onRequest<GetUserCard>(
      (request, call) => request.profileId == members[0].id
          ? DwCallOk(card())
          : DwCallRefused<UserCard>(DwCallRefusal(DwCoreRefusal.notFound)),
    );
    final app = await openUsers(tester, fake);

    await app.tap(tester, find.text('Member 01'));
    expect(app.server.requestsOf<GetUserCard>().single.profileId, 101);
    expect(find.text('79991000001'), findsWidgets);
    expect(find.text('Signs in with'), findsOneWidget);
    expect(find.textContaining('Terms accepted'), findsOneWidget);

    members[0] = members[0].copyWith(email: const DwFieldPatch.set('m@x.io'));
    app.server.publish(adminChannel, [
      card().copyWith(
        identifiers: [
          ...card().identifiers,
          UserIdentifier(
            id: 2,
            kind: DwIdentifierKind.email,
            value: 'm@x.io',
            addedAt: DateTime.utc(2026, 9, 2),
          ),
        ],
      ),
    ]);
    await app.settle(tester);
    expect(find.text('m@x.io'), findsOneWidget);
    expect(find.text('never confirmed'), findsOneWidget);

    await app.stop(tester);
  });

  testWidgets('a setting saves its own row, and one saved elsewhere arrives '
      'live', (tester) async {
    final fake = adminWith(const []);
    fake.server.onCommand<SaveAppSetting>((command, call) {
      final saved = AppSetting(id: command.key, value: command.value);
      fake.settings
        ..removeWhere((s) => s.id == saved.id)
        ..add(saved);
      call.publish(settingsChannel, [saved]);
      return DwCallOk(saved);
    });
    final app = await TestApp.start(tester, fake);
    await app.tap(tester, find.text('Profile'));
    await app.tap(tester, find.text('Admin panel'));
    await app.tap(tester, find.text('Settings'));

    expect(
      find.widgetWithText(TextField, AppSettingKey.appName.defaultValue),
      findsOneWidget,
    );
    await app.tap(tester, find.byType(Checkbox));
    expect(
      app.server.callsOf<SaveAppSetting>().single.call,
      const SaveAppSetting(key: AppSettingKeys.signUpEnabled, value: 'false'),
    );

    app.server.publish(settingsChannel, [
      const AppSetting(id: AppSettingKeys.appName, value: 'Acme'),
    ]);
    await app.settle(tester);
    expect(find.widgetWithText(TextField, 'Acme'), findsOneWidget);

    await app.stop(tester);
  });
}
