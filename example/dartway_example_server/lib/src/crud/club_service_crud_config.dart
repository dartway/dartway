import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_example_server/src/dartway/dartway_session_extension.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';

/// CRUD configuration for the ClubService model (the club price list).
/// Anyone signed in can browse services; only the admin manages them.
final clubServiceCrudConfig = DwCrudConfig<ClubService>(
  table: ClubService.t,
  getListConfig: DwGetModelListConfig(
    accessFilter: (session) async => null,
  ),
  saveConfig: DwSaveConfig<ClubService>(
    allowSave: (session, saveContext) async => session.isClubAdmin,
    validateSave: (session, saveContext) async {
      final service = saveContext.currentModel;
      if (service.title.trim().isEmpty) {
        return 'Title is required';
      }
      if (service.durationMinutes <= 0) {
        return 'Duration must be positive';
      }
      if (service.price < 0) {
        return 'Price cannot be negative';
      }
      return null;
    },
  ),
  deleteConfig: DwDeleteConfig<ClubService>(
    allowDelete: (session, model) => session.isClubAdmin,
  ),
);
