import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_example_server/src/dartway/dartway_session_extension.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';

/// CRUD configuration for the ChatChannel model (staff chat).
/// Secure-by-default demo: clients never see the chat — that is a single
/// access filter line, not scattered UI checks.
final chatChannelCrudConfig = DwCrudConfig<ChatChannel>(
  table: ChatChannel.t,
  getListConfig: DwGetModelListConfig(
    accessFilter: staffOnlyAccessFilter,
  ),
  saveConfig: DwSaveConfig<ChatChannel>(
    allowSave: (session, saveContext) async => session.isClubAdmin,
    validateSave: (session, saveContext) async =>
        saveContext.currentModel.title.trim().isEmpty
            ? 'Title is required'
            : null,
  ),
);
