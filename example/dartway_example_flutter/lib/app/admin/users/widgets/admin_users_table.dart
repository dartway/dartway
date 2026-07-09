import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// Users table over the generic CRUD: lists every profile (admin-only list
/// access on the server) and edits the role inline. The server privilege guard
/// blocks non-admins from role changes, so this UI stays simple. Search and
/// role filtering are client-side over the live list.
class AdminUsersTable extends ConsumerWidget {
  const AdminUsersTable({super.key, this.searchQuery = '', this.roleFilter});

  final String searchQuery;
  final UserRole? roleFilter;

  bool _matches(UserProfile user) {
    if (roleFilter != null && user.role != roleFilter) return false;
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    final name =
        '${user.firstName} ${user.lastName ?? ''}'.trim().toLowerCase();
    return name.contains(query) || user.phone.contains(query);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watchModelList<UserProfile>().dwBuildListAsync(
          loadingItemsCount: 4,
          childBuilder: (users) {
            final visible = [
              for (final user in users)
                if (_matches(user)) user,
            ];
            if (visible.isEmpty) {
              return AppText.body(
                users.isEmpty
                    ? context.l10n.noMembersYet
                    : context.l10n.noMembersMatch,
              );
            }
            return ListView(
              children: [for (final user in visible) _UserRow(user: user)],
            );
          },
        );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final name = '${user.firstName} ${user.lastName ?? ''}'.trim();
    final displayName = name.isEmpty ? user.phone : name;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: AppText.body(displayName),
      subtitle: AppText.body(user.phone),
      trailing: DropdownButton<UserRole>(
        value: user.role,
        underline: const SizedBox.shrink(),
        onChanged: (role) {
          if (role == null || role == user.role) return;
          // Changing someone's role is a rights change — confirm it. The
          // confirmation + label ride on the standard DwUiAction.
          DwUiAction<void>.create(
            (_) => DwRepository.saveModel(user.copyWith(role: role)),
            label: 'changeUserRole',
            confirmation: DwUiConfirmation(
              context.l10n.confirmChangeRole(
                displayName,
                context.l10n.roleName(role.name),
              ),
            ),
          )(context);
        },
        items: [
          for (final role in UserRole.values)
            DropdownMenuItem(
              value: role,
              child: Text(context.l10n.roleName(role.name)),
            ),
        ],
      ),
    );
  }
}
