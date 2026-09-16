import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/refusal_text.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    final l10n = lookupAppLocalizations(locale);

    test('every refusal code has its own text in ${locale.languageCode}', () {
      final codes = <DwRefusalCode>[
        ...DartwayStarterRefusal.values,
        ...DwCoreRefusal.values,
        ...DwAuthRefusal.values,
        ...DwUploadRefusal.values,
      ];
      for (final code in codes) {
        expect(
          l10n.refusalText(DwCallRefusal(code)),
          isNot(l10n.refusalGeneric),
          reason: code.code,
        );
      }
    });
  }

  final en = lookupAppLocalizations(const Locale('en'));

  test('a code the app does not know still reads as a sentence', () {
    expect(
      en.refusalText(const DwCallRefusal.raw('fromANewerServer')),
      en.refusalGeneric,
    );
  });

  test('refusals use their parameters', () {
    expect(
      en.refusalText(
        DwCallRefusal(
          DwCoreRefusal.invalid,
          field: 'code',
          params: {'attemptsLeft': 2},
        ),
      ),
      'Wrong code. Attempts left: 2',
    );
    expect(
      en.refusalText(DwCallRefusal(DwCoreRefusal.invalid, field: 'identifier')),
      'Enter a valid phone number or e-mail.',
    );
    expect(
      en.refusalText(
        DwCallRefusal.tooManyRequests(const Duration(seconds: 30)),
      ),
      'Too many attempts. Try again in 30 s.',
    );
    expect(
      en.refusalText(
        DwCallRefusal(
          DwUploadRefusal.tooLarge,
          field: 'byteSize',
          params: {'maxBytes': DartwayStarterUpload.avatarMaxBytes},
        ),
      ),
      'The file is too large: at most 5 MB.',
    );
  });
}
