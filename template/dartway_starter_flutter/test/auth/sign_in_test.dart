import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_starter_flutter/core/router/router.dart';
import 'package:dartway_starter_flutter/dartway_starter_app.dart';
import 'package:dartway_starter_flutter/shared/widgets/load_failed_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../support/app_test_app.dart';

/// Signing in on a fake server that answers as the real one: by phone for an
/// existing account, by e-mail for a new one — which asks for the terms after
/// the right code, and verifies the same code again.
void main() {
  DwCodeTicket ticket(String id) => DwCodeTicket(
    id: id,
    expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    resendAfter: DateTime.now().add(const Duration(minutes: 1)),
  );

  testWidgets('signing out returns to the sign-in screen, quietly', (
    tester,
  ) async {
    final app = await TestApp.start(tester, FakeApp());
    expect(find.text('Hello, Vera'), findsOneWidget);

    await app.tap(tester, find.text('Profile'));
    await app.tap(tester, find.text('Sign out'));

    expect(find.text('Get a code'), findsOneWidget);
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

  testWidgets('an existing account signs in by phone and code; a wrong code '
      'says how many attempts are left', (tester) async {
    final fake = FakeApp();
    fake.server
      ..onCommand<DwRequestCode>((command, call) => DwCallOk(ticket('t-1')))
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
    final app = await TestApp.start(tester, fake, session: null);
    expect(app.server.requestsOf<GetMyProfile>(), isEmpty);

    // Not a phone number: refused before anything is sent.
    await app.enter(tester, find.byType(TextField), '12-34');
    await app.tap(tester, find.text('Get a code'));
    expect(find.text('Enter a number of 10 to 15 digits'), findsOneWidget);
    expect(app.server.callsOf<DwRequestCode>(), isEmpty);

    await app.enter(tester, find.byType(TextField), '+7 999 000-00-02');
    await app.tap(tester, find.text('Get a code'));
    expect(
      app.server.callsOf<DwRequestCode>().single.call,
      const DwRequestCode(
        kind: DwIdentifierKind.phone,
        identifier: '79990000002',
      ),
    );
    expect(find.text('We sent a code to +7 999 000-00-02'), findsOneWidget);
    expect(find.textContaining('A new code in'), findsOneWidget);

    await app.enter(tester, find.byType(TextField), '222222');
    await app.tap(tester, find.text('Continue'));
    expect(find.text('Wrong code. Attempts left: 4'), findsOneWidget);
    await app.waitOutNotifications(tester);

    await app.enter(tester, find.byType(TextField), '111111');
    await app.tap(tester, find.text('Continue'));

    final verify = app.server.callsOf<DwVerifyCode>().last.call as DwVerifyCode;
    expect(verify, const DwVerifyCode(ticketId: 't-1', code: '111111'));
    expect(verify.registration, isEmpty);
    expect(find.text('Hello, Vera'), findsOneWidget);
    expect(app.logs, isEmpty);

    await app.stop(tester);
  });

  testWidgets('a link opened without a session ends where it pointed, '
      'after signing in', (tester) async {
    final fake = FakeApp();
    fake.server
      ..onCommand<DwRequestCode>((command, call) => DwCallOk(ticket('t-1')))
      ..onCommand<DwVerifyCode>((command, call) => const DwCallOk(testSession));
    final app = await TestApp.start(tester, fake, session: null);
    final router = ProviderScope.containerOf(
      tester.element(find.byType(AppRoot)),
    ).read(appRouterProvider).router;

    router.go(AppNavigationZone.profile.fullPath);
    await app.settle(tester);
    expect(find.text('Get a code'), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.queryParameters['from'],
      AppNavigationZone.profile.fullPath,
    );

    await app.enter(tester, find.byType(TextField), '+7 999 000-00-02');
    await app.tap(tester, find.text('Get a code'));
    await app.enter(tester, find.byType(TextField), '111111');
    await app.tap(tester, find.text('Continue'));

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppNavigationZone.profile.fullPath,
    );
    expect(find.text('Sign out'), findsOneWidget);

    await app.stop(tester);
  });

  testWidgets('a new e-mail: the right code asks for a name and the terms, '
      'and the same code creates the account with them', (tester) async {
    final fake = FakeApp(firstName: 'Boris', phone: null, email: 'b@x.io');
    fake.server
      ..onCommand<DwRequestCode>((command, call) => DwCallOk(ticket('t-2')))
      ..onCommand<DwVerifyCode>(
        (command, call) =>
            command.registration[RegistrationKeys.terms] == 'true'
            ? const DwCallOk(
                DwAuthSession(id: 42, token: 'token-42', isNewAccount: true),
              )
            : DwCallRefused<DwAuthSession>(
                DwCallRefusal(
                  DartwayStarterRefusal.consentsRequired,
                  field: 'consents',
                ),
              ),
      );
    final app = await TestApp.start(tester, fake, session: null);

    await app.tap(tester, find.text('E-mail'));
    await app.enter(tester, find.byType(TextField), ' B@X.io ');
    await app.tap(tester, find.text('Get a code'));
    expect(
      app.server.callsOf<DwRequestCode>().single.call,
      const DwRequestCode(kind: DwIdentifierKind.email, identifier: 'b@x.io'),
    );

    await app.enter(tester, find.byType(TextField), '123456');
    await app.tap(tester, find.text('Continue'));
    // The refusal is a step, not a message.
    expect(find.text('New account'), findsOneWidget);
    expect(find.text('Accept the terms to create an account.'), findsNothing);

    await app.enter(tester, find.byType(TextField), 'Boris');
    await app.tap(tester, find.text('Create account'));
    expect(find.text('Accept the terms to continue'), findsOneWidget);
    expect(app.server.callsOf<DwVerifyCode>(), hasLength(1));

    await app.tap(tester, find.byType(Checkbox).first);
    await app.tap(tester, find.text('Create account'));

    final verify = app.server.callsOf<DwVerifyCode>().last.call as DwVerifyCode;
    expect(verify.code, '123456', reason: 'the same code, not typed again');
    expect(verify.registration, {
      RegistrationKeys.terms: 'true',
      RegistrationKeys.marketing: 'false',
      RegistrationKeys.firstName: 'Boris',
    });
    expect(find.text('Hello, Boris'), findsOneWidget);

    await app.stop(tester);
  });

  testWidgets('an account without a name is asked for one before the app', (
    tester,
  ) async {
    final fake = FakeApp(firstName: '');
    final app = await TestApp.start(tester, fake);

    expect(find.text('What is your name?'), findsOneWidget);
    expect(app.server.requestsOf<ListAppSettings>(), isEmpty);

    await app.enter(tester, find.byType(TextField), '  Vera ');
    await app.tap(tester, find.text('Continue'));

    expect(
      app.server.callsOf<UpdateMyProfile>().single.call,
      const UpdateMyProfile(firstName: 'Vera'),
    );
    expect(find.text('Hello, Vera'), findsOneWidget);

    await app.stop(tester);
  });

  testWidgets('an app on an older contract line than the server is told to '
      'update, over the whole app', (tester) async {
    // A server whose contract moved to a breaking line this build predates.
    final fake = FakeApp()..server.contractVersion = '99.0.0';
    // Mounted as the app runner mounts it: the framework's bootstrapper, not a
    // copy of what it does.
    final app = await TestApp.start(tester, fake, bootstrap: true);

    expect(
      app.core.client.incompatibility?.isCode(DwCoreRefusal.updateRequired),
      isTrue,
    );
    expect(find.text('Update the app'), findsOneWidget);
    expect(find.text('Get a code'), findsNothing);
    expect(find.text('Home'), findsNothing);

    await app.stop(tester);
  });
}
