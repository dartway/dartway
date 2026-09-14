import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/core/router/router.dart';
import 'package:dartway_starter_flutter/shared/widgets/load_failed_message.dart';
import 'package:dartway_starter_flutter/shared/widgets/role_picker.dart';
import 'package:dartway_starter_flutter/shared/widgets/user_avatar.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// One page of members, with the role editable inline and the pager under it.
/// The page is live: rows change in place, and a new member reads it again.
class AdminUsersTable extends ConsumerWidget {
  const AdminUsersTable({
    required this.request,
    required this.onPage,
    super.key,
  });

  final ListUserProfiles request;

  /// Switches to page number `page`.
  final void Function(int page) onPage;

  static final _placeholder = UserProfile(
    id: 0,
    accountId: 0,
    firstName: 'Member',
    role: UserRole.user,
    joinedAt: DateTime(2026),
    phone: '10000000000',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final table = dw.table(request);

    return ref
        .watch(table)
        .section(
          loadingValue: DwTablePage(
            List.filled(4, _placeholder),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(avatarUrl: user.avatarUrl),
      title: AppText.body(user.displayName),
      // Both identifiers: the row shows how the person signs in, and whether
      // they have a second way.
      subtitle: AppText.caption([?user.phone, ?user.email].join(' · ')),
      onTap: () => GoRouter.of(context).goNamed(
        AdminNavigationZone.userCard.name,
        pathParameters: AdminParams.profileId.set(user.id),
      ),
      trailing: RolePicker(user: user),
    );
  }
}
