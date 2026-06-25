import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';

/// CRUD configuration for the UserProfile model.
final userProfileCrudConfig = DwCrudConfig<UserProfile>(
  table: UserProfile.t,
  saveConfig: DwSaveConfig<UserProfile>(
    // Let a signed-in user save only their own profile.
    allowSave: (session, saveContext) async =>
        session.isUser(saveContext.currentModel.id ?? -1),
  ),
);
