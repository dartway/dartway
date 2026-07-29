import 'package:dartway_starter_client/dartway_starter_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/app_l10n.dart';
import '../../../ui_kit/ui_kit.dart';
import '../common/admin_scaffold.dart';
import 'widgets/admin_users_table.dart';

/// Member management: search, role filter and inline role editing over the
/// generic CRUD (admin-only list access; the server privilege guard blocks
/// non-admin role changes).
class AdminUsersPage extends HookConsumerWidget implements DwFeature {
  const AdminUsersPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'admin/users',
    title: 'Members',
    purpose:
        'An admin finds a person and changes what they are allowed to do.',
    behaviors: [
      'Typing in the search field narrows the table as you type.',
      'The role chips narrow it further; "all roles" clears that filter.',
      'A role is changed inline in the table, without opening a form.',
    ],
    requirements: [
      'Only an admin lists profiles at all — everyone else gets an empty '
          'result from the server, not a hidden screen.',
      'Only an admin changes a role: the server rejects the save even if the '
          'request comes from somewhere other than this table.',
    ],
    implementationNotes: [
      'Search and role filter are local hook state handed to the table — the '
          'narrowing happens client-side over a list the server already '
          'restricted.',
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final searchQuery = useState('');
    final roleFilter = useState<UserRole?>(null);

    return AdminScaffold(
      title: l10n.adminUsers,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextFormField(
            value: searchQuery.value,
            onChanged: (value) => searchQuery.value = value,
            labelText: l10n.searchLabel,
            hintText: l10n.searchHint,
          ),
          const Gap(12),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: Text(l10n.allRoles),
                selected: roleFilter.value == null,
                onSelected: (_) => roleFilter.value = null,
              ),
              for (final role in UserRole.values)
                FilterChip(
                  label: Text(l10n.roleName(role.name)),
                  selected: roleFilter.value == role,
                  onSelected: (_) => roleFilter.value = role,
                ),
            ],
          ),
          const Gap(12),
          Expanded(
            child: AdminUsersTable(
              searchQuery: searchQuery.value,
              roleFilter: roleFilter.value,
            ),
          ),
        ],
      ),
    );
  }
}
