import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart';

import 'dw_google_sign_in_button.dart';

/// On the web Google signs a person in only from the button it draws.
const bool googleDrawsTheButton = true;

Widget googleButton({required DwGoogleButtonTheme theme, double? width}) =>
    renderButton(
      configuration: GSIButtonConfiguration(
        theme: switch (theme) {
          DwGoogleButtonTheme.outline => GSIButtonTheme.outline,
          DwGoogleButtonTheme.filledBlue => GSIButtonTheme.filledBlue,
          DwGoogleButtonTheme.filledBlack => GSIButtonTheme.filledBlack,
        },
        size: GSIButtonSize.large,
        text: GSIButtonText.signinWith,
        shape: GSIButtonShape.rectangular,
        minimumWidth: width,
      ),
    );
