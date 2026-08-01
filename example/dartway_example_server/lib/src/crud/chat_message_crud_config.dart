import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_example_server/src/dartway/dartway_session_extension.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';

/// CRUD configuration for the ChatMessage model (staff chat).
/// Clients are cut off by the staff-only filter, on read and on write alike.
///
/// No `broadcastTo`, so a new message reaches the author's own list and nobody
/// else's until they refetch. Making it live means naming a channel per chat,
/// broadcasting to it here, and declaring it in `DwCore.init` so the server
/// will let a subscriber in.
final chatMessageCrudConfig = DwCrudConfig<ChatMessage>(
  table: ChatMessage.t,
  getListConfig: DwGetModelListConfig(
    accessFilter: staffOnlyAccessFilter,
    include: ChatMessage.include(authorProfile: UserProfile.include()),
  ),
  saveConfig: DwSaveConfig<ChatMessage>(
    allowSave: (session, saveContext) async =>
        await session.isStaffMember &&
        session.isUser(saveContext.currentModel.authorProfileId),
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
      return null;
    },
  ),
);
