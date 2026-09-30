import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The commands the profile page sends.
abstract final class ProfilePageCommands {
  /// Saves [change], from [profileChangeOf].
  static Future<DwCallResult<UserProfile>> save(UpdateMyProfile change) =>
      dw.command(change);
}
