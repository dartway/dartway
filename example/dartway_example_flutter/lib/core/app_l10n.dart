import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';

export '../l10n/gen/app_localizations.dart';

/// Current translations for code that runs outside the widget tree (refusal
/// texts and error toasts, which the core renders). Kept in sync by
/// [AppLocaleController]; widgets use `context.l10n` instead.
AppLocalizations appL10n = lookupAppLocalizations(const Locale('en'));

/// The app UI locale: the system language when supported, English otherwise.
class AppLocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final locale = _supportedOrDefault(PlatformDispatcher.instance.locale);
    _apply(locale);
    return locale;
  }

  static Locale _supportedOrDefault(Locale wanted) =>
      AppLocalizations.supportedLocales.firstWhere(
        (locale) => locale.languageCode == wanted.languageCode,
        orElse: () => AppLocalizations.supportedLocales.first,
      );

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
