import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/refusal_text.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    final l10n = lookupAppLocalizations(locale);

    test('every refusal code has its own text in ${locale.languageCode}', () {
      final codes = <DwRefusalCode>[
        ...ExampleRefusal.values,
        ...DwCoreRefusal.values,
      ];
      for (final code in codes) {
        expect(
          refusalText(l10n, DwCallRefusal(code)),
          isNot(l10n.refusalGeneric),
          reason: code.code,
        );
      }
    });
  }

  final en = lookupAppLocalizations(const Locale('en'));

  test('a code the app does not know still reads as a sentence', () {
    expect(
      refusalText(en, const DwCallRefusal.raw('fromANewerServer')),
      en.refusalGeneric,
    );
  });

  test('sign-in refusals use their parameters', () {
    expect(
      refusalText(
        en,
        DwCallRefusal(
          DwCoreRefusal.invalid,
          field: 'code',
          params: {'attemptsLeft': 2},
        ),
      ),
      'Wrong code. Attempts left: 2',
    );
    expect(
      refusalText(
        en,
        DwCallRefusal(DwCoreRefusal.invalid, field: 'identifier'),
      ),
      'Enter a valid phone number.',
    );
    expect(
      refusalText(
        en,
        DwCallRefusal.tooManyRequests(const Duration(seconds: 30)),
      ),
      'Too many attempts. Try again in 30 s.',
    );
  });
}
