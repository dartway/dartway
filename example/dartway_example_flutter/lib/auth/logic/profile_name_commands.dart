import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The command the name step sends.
abstract final class ProfileNameCommands {
  /// Names the new member. The gate lets the app through once the updated
  /// profile arrives with the answer.
  static Future<DwCallResult<UserProfile>> saveName(String name) =>
      dw.command(UpdateMyProfile(firstName: name.trim()));
}
