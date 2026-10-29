import 'package:flutter/widgets.dart';

import 'dw_google_sign_in_button.dart';

/// Outside the web the app draws its own button.
const bool googleDrawsTheButton = false;

Widget googleButton({required DwGoogleButtonTheme theme, double? width}) =>
    throw UnsupportedError('Google draws its sign-in button only on the web');
