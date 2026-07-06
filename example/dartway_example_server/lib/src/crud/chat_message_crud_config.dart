import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_example_server/src/dartway/dartway_session_extension.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';

/// CRUD configuration for the ChatMessage model (staff chat).
/// Realtime comes from the framework: subscribed lists receive new messages
/// with no extra code. Clients are cut off by the same staff-only filter.
final chatMessageCrudConfig = DwCrudConfig<ChatMessage>(
  table: ChatMessage.t,
  getListConfig: DwGetModelListConfig(
    accessFilter: staffOnlyAccessFilter,
    include: ChatMessage.include(authorProfile: UserProfile.include()),
  ),
  saveConfig: DwSaveConfig<ChatMessage>(
    allowSave: (session, saveContext) async =>
        await session.isStaffMember &&
        await session.isUser(saveContext.currentModel.authorProfileId),
    validateSave: (session, saveContext) async =>
        saveContext.currentModel.messageText.trim().isEmpty
            ? 'Message cannot be empty'
            : null,
    beforeSaveTransaction: (session, saveContext) async {
      if (saveContext.isInsert) {
        saveContext.currentModel = saveContext.currentModel.copyWith(
          createdAt: DateTime.now(),
        );
      }
    },
  ),
);
