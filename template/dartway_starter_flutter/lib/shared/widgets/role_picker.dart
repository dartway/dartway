import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/core/profile/my_profile.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:flutter/material.dart';

/// A member's role, changeable by an admin after a confirmation — in the
/// members table and on the user card alike.
///
/// An admin's own role is shown, not offered: the server refuses the change
/// (`ownRoleLocked`), and a control that can only be refused is a trap.
class RolePicker extends StatelessWidget {
  const RolePicker({required this.user, super.key});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isSelf = user.id == context.profile.id;
    final picker = DropdownButton<UserRole>(
      value: user.role,
      underline: const SizedBox.shrink(),
      onChanged: isSelf
          ? null
          : (role) {
              if (role == null || role == user.role) return;
              // A rights change — confirm it. The row changes when the
              // answer carries the updated profile.
              dw.action(
                (_) =>
                    dw.command(ChangeUserRole(profileId: user.id, role: role)),
                label: 'changeUserRole',
                confirmation: DwUiConfirmation(
                  l10n.confirmChangeRole(
                    user.displayName,
                    l10n.roleName(role.name),
                  ),
                ),
              )(context);
            },
      items: [
        for (final role in UserRole.values)
          DropdownMenuItem(value: role, child: Text(l10n.roleName(role.name))),
      ],
    );
    return isSelf ? Tooltip(message: l10n.ownRoleHint, child: picker) : picker;
  }
}
