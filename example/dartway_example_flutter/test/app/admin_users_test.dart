import 'package:flutter_test/flutter_test.dart';

import '../support/example_test_app.dart';

UserProfile member(int n) => UserProfile(
  id: 100 + n,
  accountId: 1000 + n,
  phone: '7999100${n.toString().padLeft(4, '0')}',
  firstName: 'Member ${n.toString().padLeft(2, '0')}',
  role: UserRole.client,
  agreedForMarketing: false,
);

void main() {
  testWidgets('the members table switches pages, and a member signing up '
      'updates the page and its total', (tester) async {
    final members = [for (var n = 1; n <= 23; n++) member(n)];
    final club = FakeClub(role: UserRole.admin, firstName: 'Anna');
    club.server
      ..onRequest<GetAdminCounters>(
        (request, call) => DwCallOk(
          AdminCounters(
            members: members.length,
            upcomingSessions: 0,
            newsPosts: 0,
          ),
        ),
      )
      ..onRequest<ListUserProfiles>(
        (request, call) => DwCallOk(dwFakeTablePage(members, request)),
      );
    final app = await ExampleTestApp.start(tester, club);

    await app.tap(tester, find.text('Profile'));
    await app.tap(tester, find.text('Admin panel'));
    await app.tap(tester, find.text('Users'));
    expect(find.text('Page 1 of 3 · 23 members'), findsOneWidget);
    expect(find.text('Member 01'), findsOneWidget);

    await app.tap(tester, find.byTooltip('Next page'));
    expect(find.text('Page 2 of 3 · 23 members'), findsOneWidget);
    expect(find.text('Member 11'), findsOneWidget);
    expect(find.text('Member 01'), findsNothing);
    expect(
      [
        for (final request in app.server.requestsOf<ListUserProfiles>())
          request.page,
      ],
      [1, 2],
    );

    members.add(member(24));
    app.server.publish(adminChannel, [MemberCount(count: members.length)]);
    await app.settle(tester);
    expect(find.text('Page 2 of 3 · 24 members'), findsOneWidget);
    expect(app.server.requestsOf<ListUserProfiles>(), hasLength(3));

    await app.tap(tester, find.byTooltip('Previous page'));
    expect(find.text('Page 1 of 3 · 24 members'), findsOneWidget);

    await app.stop(tester);
  });
}
