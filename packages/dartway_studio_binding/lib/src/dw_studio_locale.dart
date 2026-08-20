import 'dart:ui';

import 'package:flutter_riverpod/misc.dart';

/// The app's UI language, as far as Studio needs to reach it: something to
/// watch for changes, and a way to switch.
///
/// Localization is the app's own — generated `AppLocalizations`, a controller
/// of its own shape — so the binding takes these two ends rather than an
/// interface the app would have to implement. Omit it entirely and Studio's
/// language switcher stays inert, which is the right behaviour for an app that
/// ships one language.
class DwStudioLocale {
  const DwStudioLocale({required this.provider, required this.select});

  /// The app's current locale, watched for changes — every change is reported
  /// to Studio.
  final ProviderListenable<Locale> provider;

  /// Switches the app to [languageCode], a tag from the manifest's
  /// `supportedLocales`. Called when Studio asks for another language.
  final void Function(String languageCode) select;
}
