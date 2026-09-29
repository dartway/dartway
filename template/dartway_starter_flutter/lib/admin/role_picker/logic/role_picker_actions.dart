import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

/// The changes the role picker sends.
abstract final class RolePickerActions {
  /// Gives [user] [role], after a confirmation: a change of rights. The row
  /// changes when the answer carries the updated profile.
  static DwUiAction<DwCallResult<UserProfile>> changeRole(
    UserProfile user,
    UserRole role,
  ) => dw.action(
    (_) => dw.command(ChangeUserRole(profileId: user.id, role: role)),
    label: 'changeUserRole',
    confirmation: DwUiConfirmation(
      appL10n.confirmChangeRole(user.displayName, appL10n.roleName(role.name)),
    ),
  );
}
