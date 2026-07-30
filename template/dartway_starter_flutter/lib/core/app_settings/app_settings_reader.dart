import 'package:collection/collection.dart';
import 'package:dartway_starter_client/dartway_starter_client.dart';
import 'package:dartway_starter_flutter/core/app_settings/app_setting_key.dart';

/// Reads a typed setting out of the rows the generic CRUD delivered.
///
/// One row per setting, on purpose: saving a setting writes only its own row,
/// so two admins editing different settings cannot overwrite each other. The
/// alternative — the whole map in a single row — loses one of the two edits,
/// silently, and the one who saved second wins.
extension AppSettingsReader on List<AppSetting> {
  T valueOf<T>(AppSettingKey<T> setting) =>
      setting.parse(rowFor(setting)?.settingValue);

  /// The row holding this setting, or `null` while nobody has changed it — the
  /// value then comes from [AppSettingKey.defaultValue].
  AppSetting? rowFor(AppSettingKey<Object?> setting) =>
      firstWhereOrNull((row) => row.settingKey == setting.key);
}
