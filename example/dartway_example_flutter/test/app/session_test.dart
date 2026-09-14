import 'package:dartway_example_flutter/shared/widgets/load_failed_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/example_test_app.dart';

void main() {
  testWidgets('signing out returns to the sign-in screen, quietly', (
    tester,
  ) async {
    final app = await ExampleTestApp.start(tester, FakeClub());
    expect(find.text('Hello, Vera'), findsOneWidget);

    await app.tap(tester, find.text('Profile'));
    await app.tap(tester, find.text('Sign out'));

    expect(find.text('Welcome!'), findsOneWidget);
    expect(find.text('Registration'), findsOneWidget);
    expect(app.core.client.accountId, isNull);
    expect(app.server.isTokenValid(testSession.token), isFalse);
    expect(find.byType(LoadFailedMessage), findsNothing);
    expect(
      app.logs,
      isEmpty,
      reason:
          'the reads answered not-authenticated on their way out are not '
          'incidents',
    );

    await app.stop(tester);
  });

  testWidgets('signing in by phone and code opens the app', (tester) async {
    final club = FakeClub();
    final ticket = DwCodeTicket(
      id: 'ticket-1',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      resendAfter: DateTime.now().add(const Duration(minutes: 1)),
    );
    club.server
      ..onCommand<DwRequestCode>((command, call) => DwCallOk(ticket))
      ..onCommand<DwVerifyCode>(
        (command, call) => command.code == '111111'
            ? const DwCallOk(testSession)
            : DwCallRefused<DwAuthSession>(
                DwCallRefusal(
                  DwCoreRefusal.invalid,
                  field: 'code',
                  params: {'attemptsLeft': 4},
                ),
              ),
      );
    final app = await ExampleTestApp.start(tester, club, session: null);
    expect(find.text('Welcome!'), findsOneWidget);
    expect(app.server.requestsOf<GetMyProfile>(), isEmpty);

    await app.tap(tester, find.text('Login'));
    await tester.enterText(find.byType(TextField), '9990000003');
    await app.settle(tester);
    await app.tap(tester, find.text('Continue'));

    expect(
      app.server.callsOf<DwRequestCode>().single.call,
      const DwRequestCode(
        kind: DwIdentifierKind.phone,
        identifier: '79990000003',
      ),
    );
    expect(find.text('Enter the code from SMS'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '222222');
    await app.settle(tester);
    await app.tap(tester, find.text('Continue'));
    expect(find.text('Wrong code. Attempts left: 4'), findsOneWidget);
    await app.waitOutNotifications(tester);

    await tester.enterText(find.byType(TextField), '111111');
    await app.settle(tester);
    await app.tap(tester, find.text('Continue'));

    final verify = app.server.callsOf<DwVerifyCode>().last.call;
    expect(verify, const DwVerifyCode(ticketId: 'ticket-1', code: '111111'));
    expect(
      (verify as DwVerifyCode).registration,
      isEmpty,
      reason: 'the login step collects nothing to register with',
    );
    expect(find.text('Hello, Vera'), findsOneWidget);
    expect(app.logs, isEmpty);

    await app.stop(tester);
  });

  testWidgets('an account without a name is asked for one before the app', (
    tester,
  ) async {
    final club = FakeClub(firstName: '');
    club.server.onCommand<UpdateMyProfile>((command, call) {
      club.profile = club.profile.copyWith(firstName: command.firstName);
      call.publish(club.profileChannel, [club.profile]);
      return DwCallOk(club.profile);
    });
    final app = await ExampleTestApp.start(tester, club);

    expect(find.text('What is your name?'), findsOneWidget);
    expect(app.server.requestsOf<ListUpcomingSessions>(), isEmpty);

    await tester.enterText(find.byType(TextField), '  Vera ');
    await app.settle(tester);
    await app.tap(tester, find.text('Continue'));

    expect(
      app.server.callsOf<UpdateMyProfile>().single.call,
      const UpdateMyProfile(firstName: 'Vera'),
    );
    expect(find.text('Hello, Vera'), findsOneWidget);

    await app.stop(tester);
  });
}
