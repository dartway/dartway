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
  /// to Studio as a **language tag** (`Locale.toLanguageTag()`: `en`, `ru`,
  /// `zh-Hans`, `pt-BR`), which is what the manifest lists.
  final ProviderListenable<Locale> provider;

  /// Switches the app to [languageTag] — one of the manifest's
  /// `supportedLocales`, in the same spelling. Called when Studio asks for
  /// another language.
  ///
  /// **The tag, not the language code.** Both sides speak
  /// `Locale.toLanguageTag()`, so build the manifest's `supportedLocales`
  /// with it too; `en` and `ru` are the same either way, and the first
  /// `zh-Hans` in a project is where a `languageCode` on one side and a tag
  /// on the other stop matching and the language switcher asks for a
  /// language the app does not know.
  final void Function(String languageTag) select;
}
