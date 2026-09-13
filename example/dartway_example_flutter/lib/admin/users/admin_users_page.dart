import 'package:dartway_example_flutter/core/app_l10n.dart';
import 'package:dartway_example_flutter/shared/widgets/admin_scaffold.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

import 'widgets/admin_users_table.dart';

/// Member management: search, role filter and inline role editing. Listing
/// profiles and changing a role are both admin-only on the server.
class AdminUsersPage extends HookWidget implements DwFeature {
  const AdminUsersPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'admin/users',
    title: 'Members',
    purpose: 'An admin finds a person and changes what they are allowed to do.',
    behaviors: [
      'Typing in the search field narrows the table as you type.',
      'The role chips narrow it further; "all roles" clears that filter.',
      'A role is changed inline in the table, without opening a form, and the '
          'change is confirmed before it is applied.',
      'A role changed or a profile edited — here, by another admin or by the '
          'member — updates its row live.',
    ],
    requirements: [
      'Only an admin lists profiles at all — the server refuses everyone '
          'else, whatever screen they reach.',
      'Only an admin changes a role: the server refuses the command even if '
          'it comes from somewhere other than this table.',
    ],
    implementationNotes: [
      'Search and role narrowing happen client-side over the one live list: '
          'a request per keystroke would buy a club-sized table nothing.',
    ],
  );

  @override
  Widget build(BuildContext context) {
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
