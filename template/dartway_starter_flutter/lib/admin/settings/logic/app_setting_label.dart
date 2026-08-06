import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/app_settings/app_setting_key.dart';

/// The label the admin panel puts on a setting.
///
/// Kept out of [AppSettingKey] because a label is interface text and belongs to
/// the localisation, while the catalogue is storage and defaults. Kept as an
/// exhaustive switch on purpose: add a setting without a label and this stops
/// compiling, which is the only reliable reminder.
extension AppSettingLabel on AppSettingKey<Object?> {
  String label(AppLocalizations l10n) => switch (this) {
    AppSettingKey.appName => l10n.appNameLabel,
    AppSettingKey.signUpEnabled => l10n.signUpEnabledLabel,
  };
}
