import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_starter_flutter/admin/users/admin_users_page.dart';
import 'package:dartway_starter_flutter/core/router/router.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_app.dart';

/// A member's card over a fake server, live.
void main() {
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
    final app = await openAdminUsers(tester, fake);

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

  testWidgets('an address naming no member says so, and is no incident', (
    tester,
  ) async {
    final fake = adminWith([member(1)]);
    fake.server.onRequest<GetUserCard>(
      (request, call) =>
          DwCallRefused<UserCard>(DwCallRefusal(DwCoreRefusal.notFound)),
    );
    final app = await openAdminUsers(tester, fake);

    GoRouter.of(tester.element(find.byType(AdminUsersPage))).goNamed(
      AdminNavigationZone.userCard.name,
      pathParameters: AdminParams.profileId.set(999),
    );
    await app.settle(tester);
    expect(app.server.requestsOf<GetUserCard>().single.profileId, 999);
    expect(find.text('There is no such user.'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);

    await app.stop(tester);
  });
}
