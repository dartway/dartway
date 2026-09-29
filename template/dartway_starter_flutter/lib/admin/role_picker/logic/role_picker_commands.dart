import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

/// The commands the role picker sends.
abstract final class RolePickerCommands {
  /// Gives [user] [role]. The row changes when the answer carries the updated
  /// profile.
  static Future<DwCallResult<UserProfile>> changeRole(
    UserProfile user,
    UserRole role,
  ) => dw.command(ChangeUserRole(profileId: user.id, role: role));
}
