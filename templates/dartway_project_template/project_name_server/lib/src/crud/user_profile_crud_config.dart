import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:project_name_server/src/generated/protocol.dart';

/// CRUD configuration for UserProfile model
final userProfileCrudConfig = DwCrudConfig<UserProfile>(
  table: UserProfile.t,
  saveConfig: DwSaveConfig<UserProfile>(
    allowSave: (session, initialModel, newModel) async => true,
    // allowSave: (session, initial, updated) async {
    //   // Allow users to save their own profile
    //   return updated.id != null && await session.isUser(updated.id!);
    // },
    // validateSave: (session, initial, updated) async {
    //   // Basic validation
    //   if (updated.firstName.trim().isEmpty) {
    //     return 'First name is required';
    //   }
    //   if (updated.phone.trim().isEmpty) {
    //     return 'Phone number is required';
    //   }
    //   return null;
    // },
    // beforeSave: (session, transaction, initial, updated) async {
    //   // Trim whitespace from text fields
    //   final processed = updated.copyWith(
    //     firstName: updated.firstName.trim(),
    //     phone: updated.phone.trim(),
    //   );
    //   return DwPreSaveResult(model: processed);
    // },
    // afterSave: (session, transaction, initialModel, savedModel,
    //     {beforeUpdates}) async {
    //   return [];
    // },
    // afterSaveSideEffects: (session, initialModel, savedModel,
    //     {afterUpdates, beforeUpdates}) async {},
  ),
);
