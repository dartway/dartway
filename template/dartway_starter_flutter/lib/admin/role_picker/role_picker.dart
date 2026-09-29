import 'package:dartway_starter_flutter/admin/role_picker/logic/role_picker_commands.dart';
import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/core/profile/my_profile.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:flutter/material.dart';

/// A member's role, changeable by an admin — in the members table and on the
/// user card alike.
class RolePicker extends StatelessWidget implements DwFeatureWidget {
  const RolePicker({required this.user, super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'role_picker/role',
    title: 'Role picker',
    behaviors: [
      'Shows the member\'s role; choosing another asks to confirm the change '
          'of rights, and the row changes when the server answers.',
      'An admin\'s own role is shown, not offered, with a hint why.',
    ],
    requirements: [
      'Nobody changes their own role: the server refuses it '
          '(`ownRoleLocked`), and a control that can only be refused is a '
          'trap.',
    ],
  );

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
              // A change of rights: confirmed first.
              dw.action(
                (_) => RolePickerCommands.changeRole(user, role),
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
