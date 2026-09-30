import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The commands the settings page sends.
abstract final class SettingsCommands {
  /// Saves the settings [command] names and leaves the rest, so two admins
  /// editing different settings cannot overwrite each other.
  static Future<DwCallResult<ClubSettings>> save(SaveClubSettings command) =>
      dw.command(command);
}
