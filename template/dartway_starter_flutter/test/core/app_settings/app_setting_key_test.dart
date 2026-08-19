import 'package:dartway_starter_flutter/core/app_settings/app_setting_key.dart';
import 'package:flutter_test/flutter_test.dart';

/// The other layer a project tests: rules that are plain logic.
///
/// `AppSettingKey.parse` decides what a stored string means, and it has the one
/// property worth pinning — **there is no failure path**. A setting nobody has
/// touched, or one somebody hand-edited into nonsense, must not be able to break
/// a screen. That is a claim about behaviour, and a unit test is the cheapest
/// place to hold it: no core, no widget, no transport.
void main() {
  test('an absent row reads as the declared default', () {
    expect(AppSettingKey.appName.parse(null), 'DartWay');
    expect(AppSettingKey.signUpEnabled.parse(null), isTrue);
  });

  test('a boolean accepts what a checkbox, a config and a hand edit write', () {
    for (final written in ['true', 'TRUE', '1', 'yes', ' true ']) {
      expect(
        AppSettingKey.signUpEnabled.parse(written),
        isTrue,
        reason: written,
      );
    }
    for (final written in ['false', 'FALSE', '0', 'no']) {
      expect(
        AppSettingKey.signUpEnabled.parse(written),
        isFalse,
        reason: written,
      );
    }
  });

  test('nonsense falls back to the default instead of failing', () {
    expect(AppSettingKey.signUpEnabled.parse('perhaps'), isTrue);
    expect(AppSettingKey.signUpEnabled.parse(''), isTrue);
  });

  test('a text value survives a round trip through storage, trimmed', () {
    for (final value in ['Acme', ' spaced ']) {
      expect(
        AppSettingKey.appName.parse(AppSettingKey.appName.format(value)),
        value.trim(),
      );
    }
  });

  test('an empty text value is a value, not an absent row', () {
    // Only `null` means "nobody has set this". A stored empty string is
    // something an admin did, and the default does not quietly undo it — which
    // is why the Save button, not the parser, is what refuses a blank name.
    expect(AppSettingKey.appName.parse(''), '');
    expect(AppSettingKey.appName.parse(null), 'DartWay');
  });
}
