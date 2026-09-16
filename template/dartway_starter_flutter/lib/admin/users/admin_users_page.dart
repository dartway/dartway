import 'package:dartway_starter_flutter/core/app_l10n.dart';
import 'package:dartway_starter_flutter/shared/widgets/admin_scaffold.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

import 'widgets/admin_users_table.dart';

/// Member management: search, role filter, numbered pages, inline role
/// editing, and a card per member. Listing profiles and changing a role are
/// both admin-only on the server.
class AdminUsersPage extends HookWidget implements DwFeatureWidget {
  const AdminUsersPage({super.key});

  @override
  DwFeatureSpec get dwFeature => const DwFeatureSpec(
    id: 'admin/users',
    title: 'Members',
    purpose: 'An admin finds a person and changes what they are allowed to do.',
    behaviors: [
      'Members are listed newest first, ten to a page, with the page and the '
          'total under the table; the arrows switch pages.',
      'Typing in the search field narrows the table by name, phone or e-mail '
          'once typing pauses; the role chips narrow it further. Either '
          'returns to the first page.',
      'A role is changed inline in the table, after a confirmation; an '
          "admin's own role is not offered.",
      'Tapping a member opens their card.',
      'A role changed or a profile edited — here, by another admin or by the '
          'member — updates its row live; a member signing up anywhere updates '
          'the page and the total.',
    ],
    requirements: [
      'Only an admin lists profiles at all — the server refuses everyone '
          'else, whatever screen they reach.',
      'Only an admin changes a role, and never their own: the server refuses '
          'the command even if it comes from somewhere other than this table.',
    ],
    implementationNotes: [
      'Search, role and page are fields of the table request, so the server '
          'pages and counts; the client holds one page at a time.',
      'A pause in typing, not every keystroke, becomes a request.',
    ],
  );

  static const _searchPause = Duration(milliseconds: 350);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final searchInput = useState('');
    final search = (useDebounced(searchInput.value, _searchPause) ?? '').trim();
    final role = useState<UserRole?>(null);
    // The page belongs to the filter it was chosen under: another filter
    // starts from its first page, without asking for the old page first.
    final filter = (search, role.value);
    final chosenPage = useState((filter: filter, page: 1));
    final page = chosenPage.value.filter == filter ? chosenPage.value.page : 1;

    return AdminScaffold(
      title: l10n.adminUsers,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextFormField(
            value: searchInput.value,
            onChanged: (value) => searchInput.value = value,
            labelText: l10n.searchLabel,
            hintText: l10n.searchHint,
          ),
          const Gap(12),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: Text(l10n.allRoles),
                selected: role.value == null,
                onSelected: (_) => role.value = null,
              ),
              for (final value in UserRole.values)
                FilterChip(
                  label: Text(l10n.roleName(value.name)),
                  selected: role.value == value,
                  onSelected: (_) => role.value = value,
                ),
            ],
          ),
          const Gap(12),
          Expanded(
            child: AdminUsersTable(
              request: ListUserProfiles(
                page: page,
                search: search,
                role: role.value,
              ),
              onPage: (next) => chosenPage.value = (filter: filter, page: next),
            ),
          ),
        ],
      ),
    );
  }
}
