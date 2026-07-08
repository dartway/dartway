import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// Users table over the generic CRUD: lists every profile (admin-only list
/// access on the server) and edits the role inline. The server privilege guard
/// blocks non-admins from role changes, so this UI stays simple.
class AdminUsersTable extends ConsumerWidget {
  const AdminUsersTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watchModelList<UserProfile>().dwBuildListAsync(
          loadingItemsCount: 4,
          childBuilder: (users) {
            if (users.isEmpty) {
              return AppText.body('No members yet.');
            }
            return Column(
              children: [for (final user in users) _UserRow(user: user)],
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: AppText.body(name.isEmpty ? user.phone : name),
      subtitle: AppText.body(user.phone),
      trailing: DropdownButton<UserRole>(
        value: user.role,
        underline: const SizedBox.shrink(),
        onChanged: (role) {
          if (role == null || role == user.role) return;
          DwRepository.saveModel(user.copyWith(role: role));
        },
        items: [
          for (final role in UserRole.values)
            DropdownMenuItem(value: role, child: Text(role.name)),
        ],
      ),
    );
  }
}
