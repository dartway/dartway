import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';

export '../l10n/gen/app_localizations.dart';

/// Current translations for code that runs outside the widget tree (refusal
/// texts and error toasts, which the core renders). Kept in sync by
/// [AppLocaleController]; widgets use `context.l10n` instead.
AppLocalizations appL10n = lookupAppLocalizations(
  AppLocaleController.productLocale,
);

/// The app UI locale: the language the product speaks.
///
/// Stated, not derived. Taken from the phone, the build's language was a
/// property of whose device opened it — a Russian product showed its client
/// English screens from an English laptop — and the fallback was whichever
/// `.arb` sorted first (#230). `dartway create --language` writes it; a
/// project that adds a language switch sets the state from its own setting.
class AppLocaleController extends Notifier<Locale> {
  static const Locale productLocale = Locale('en');

  @override
  Locale build() {
    _apply(productLocale);
    return productLocale;
  }

  /// Keeps the out-of-tree consumers in sync: [appL10n] for notification
  /// texts and `Intl.defaultLocale` for date formatting.
  static void _apply(Locale locale) {
    Intl.defaultLocale = locale.toLanguageTag();
    appL10n = lookupAppLocalizations(locale);
  }
}

final appLocaleProvider = NotifierProvider<AppLocaleController, Locale>(
  AppLocaleController.new,
);

extension AppL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
