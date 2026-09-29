import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_app.dart';

/// Changing a member's role from the members table.
void main() {
  testWidgets('a role is changed after a confirmation, and the row follows '
      "the answer; the admin's own role is not offered", (tester) async {
    final members = [member(1)];
    final fake = adminWith(members);
    fake.server.onCommand<ChangeUserRole>((command, call) {
      members[0] = members[0].copyWith(role: command.role);
      call.publish(adminChannel, [members[0]]);
      return DwCallOk(members[0]);
    });
    final app = await openAdminUsers(tester, fake);

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
}
