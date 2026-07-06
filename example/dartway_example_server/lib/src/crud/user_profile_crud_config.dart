import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_example_server/src/dartway/dartway_session_extension.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';

/// CRUD configuration for the UserProfile model.
final userProfileCrudConfig = DwCrudConfig<UserProfile>(
  table: UserProfile.t,
  saveConfig: DwSaveConfig<UserProfile>(
    // A signed-in user saves only their own profile; the admin saves anyone's.
    allowSave: (session, saveContext) async =>
        await session.isClubAdmin ||
        await session.isUser(saveContext.currentModel.id ?? -1),
    // Privilege escalation guard: only the admin can change roles.
    validateSave: (session, saveContext) async {
      final roleChanged =
          saveContext.initialModel?.role != saveContext.currentModel.role;
      if (roleChanged && !await session.isClubAdmin) {
        return 'Only the admin can change user roles';
      }
      return null;
    },
  ),
);
