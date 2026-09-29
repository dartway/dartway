import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The commands the settings page sends.
abstract final class SettingsCommands {
  /// Saves the setting [key] alone. Two admins editing different settings
  /// therefore cannot overwrite each other.
  static Future<DwCallResult<AppSetting>> save(String key, String rawValue) =>
      dw.command(SaveAppSetting(key: key, value: rawValue));
}
