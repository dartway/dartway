import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'dw_google_sign_in.dart';
import 'google_button_stub.dart'
    if (dart.library.js_interop) 'google_button_web.dart';

/// The look of the button Google draws on the web.
enum DwGoogleButtonTheme { outline, filledBlue, filledBlack }

/// The button a person signs in with Google by, on every platform. Its
/// sign-ins arrive in [DwGoogleAuth.signInCommands], not from here.
///
/// On the web the button is Google's own: Google Identity Services signs a
/// person in only from a button it draws, so [builder] is not used there and
/// [theme] and [width] shape Google's. Elsewhere [builder] makes the app's
/// own button from the sign-in to start; without it a plain outlined button
/// says «Sign in with Google».
///
/// Shown after [DwGoogleAuth.initialize] has completed: before that the SDK
/// can neither draw its button nor sign in.
class DwGoogleSignInButton extends StatelessWidget {
  const DwGoogleSignInButton({
    super.key,
    this.builder,
    this.theme = DwGoogleButtonTheme.outline,
    this.width,
  });

  /// The app's own button outside the web, given the sign-in to start.
  final Widget Function(BuildContext context, VoidCallback signIn)? builder;

  /// The web button's look.
  final DwGoogleButtonTheme theme;

  /// The web button's width in logical pixels; Google caps it at 400.
  final double? width;

  @override
  Widget build(BuildContext context) {
    if (googleDrawsTheButton) return googleButton(theme: theme, width: width);
    final make = builder ?? _plain;
    return make(context, _signIn);
  }

  // The outcome, a cancel included, reaches `DwGoogleAuth.signInCommands`:
  // the SDK reports it there, so it is not handled twice here.
  static void _signIn() => unawaited(
    GoogleSignIn.instance.authenticate().then<void>(
      (_) {},
      onError: (Object _) {},
    ),
  );

  static Widget _plain(BuildContext context, VoidCallback signIn) =>
      OutlinedButton(
        onPressed: signIn,
        child: const Text('Sign in with Google'),
      );
}
