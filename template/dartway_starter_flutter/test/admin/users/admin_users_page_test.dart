import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_app.dart';

/// The members table over a fake server: paged, and live.
void main() {
  testWidgets('the members table switches pages, and a member signing up '
      'updates the page and its total', (tester) async {
    final members = [for (var n = 1; n <= 23; n++) member(n)];
    final fake = adminWith(members);
    final app = await openAdminUsers(tester, fake);
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
}
