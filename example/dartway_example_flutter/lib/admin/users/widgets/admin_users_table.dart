import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:dartway_example_flutter/shared/placeholder_objects.dart';
import 'package:dartway_example_flutter/shared/widgets/load_failed_message.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// One page of members, with the role editable inline and the pager under
/// it. The page is live: rows change in place, and a new member reads it
/// again.
class AdminUsersTable extends ConsumerWidget {
  const AdminUsersTable({
    required this.request,
    required this.onPage,
    super.key,
  });

  final ListUserProfiles request;

  /// Switches to page number `page`.
  final void Function(int page) onPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final table = dw.table(request);

    return ref
        .watch(table)
        .section(
          loadingValue: DwTablePage(
            PlaceholderObjects.listOf(PlaceholderObjects.profile, 4),
            total: 4,
            page: 1,
            pageSize: request.pageSize,
          ),
          onRetry: () => ref.read(table.notifier).refetch(),
          builder: (page) {
            if (page.items.isEmpty) {
              return AppText.body(
                request.search.isEmpty && request.role == null
                    ? l10n.noMembersYet
                    : l10n.noMembersMatch,
              );
            }
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      for (final user in page.items) _UserRow(user: user),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: l10n.previousPage,
                      icon: const Icon(Icons.chevron_left),
                      onPressed: page.page > 1
                          ? () => onPage(page.page - 1)
                          : null,
                    ),
                    Flexible(
                      child: AppText.body(
                        l10n.membersPage(page.page, page.pageCount, page.total),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.nextPage,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: page.page < page.pageCount
                          ? () => onPage(page.page + 1)
                          : null,
                    ),
                  ],
                ),
              ],
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
          // Changing someone's role is a rights change — confirm it. The row
          // changes when the answer carries the updated profile.
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
