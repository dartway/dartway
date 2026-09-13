import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/shared/placeholder_views.dart';
import 'package:dartway_example_flutter/shared/widgets/load_failed_message.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Every profile, with the role editable inline. Search and role filtering
/// are client-side over the live list.
class AdminUsersTable extends ConsumerWidget {
  const AdminUsersTable({super.key, this.searchQuery = '', this.roleFilter});

  final String searchQuery;
  final UserRole? roleFilter;

  bool _matches(ProfileView user) {
    if (roleFilter != null && user.role != roleFilter) return false;
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    final name = '${user.firstName} ${user.lastName ?? ''}'
        .trim()
        .toLowerCase();
    return name.contains(query) || user.phone.contains(query);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(dw.request(const ListProfiles()))
        .section(
          loadingValue: PlaceholderViews.listOf(PlaceholderViews.profile, 4),
          onRetry: () =>
              ref.read(dw.request(const ListProfiles()).notifier).refetch(),
          builder: (users) {
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

  final ProfileView user;

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
          // Changing someone's role is a rights change — confirm it. The row
          // changes when the server publishes the updated profile.
          dw.action(
            (_) => dw.command(ChangeRole(profileId: user.id, role: role)),
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
