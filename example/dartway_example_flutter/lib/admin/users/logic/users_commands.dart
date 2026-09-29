import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// The commands the members table sends.
abstract final class UsersCommands {
  /// Gives [user] [role]. The row changes when the answer carries the updated
  /// profile.
  static Future<DwCallResult<UserProfile>> changeRole(
    UserProfile user,
    UserRole role,
  ) => dw.command(ChangeRole(profileId: user.id, role: role));
}
