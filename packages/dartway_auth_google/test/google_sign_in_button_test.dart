import 'package:dartway_auth_google/dartway_auth_google.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Outside the web the app draws the button; Google draws it only in the
/// browser (#680).
void main() {
  testWidgets('outside the web the app\'s own button is built, given the '
      'sign-in to start', (tester) async {
    VoidCallback? given;
    await tester.pumpWidget(
      MaterialApp(
        home: DwGoogleSignInButton(
          builder: (context, signIn) {
            given = signIn;
            return const Text('Continue with Google');
          },
        ),
      ),
    );
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(given, isNotNull);
  });

  testWidgets('without a builder it is a plain outlined button', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DwGoogleSignInButton()));
    expect(
      find.widgetWithText(OutlinedButton, 'Sign in with Google'),
      findsOneWidget,
    );
  });
}
