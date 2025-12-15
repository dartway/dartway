import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:project_name_server/src/generated/protocol.dart';

/// CRUD configuration for FeedPost model
final feedPostCrudConfig = DwCrudConfig<FeedPost>(
  table: FeedPost.t,
  getListConfig: DwGetListConfig(
    include: FeedPost.include(
      authorProfile: UserProfile.include(),
    ),
  ),
  saveConfig: DwSaveConfig<FeedPost>(
    allowSave: (session, initial, updated) async {
      return await session.isUser(updated.authorProfileId);
    },
    validateSave: (session, initial, updated) async {
      // Basic validation
      if (updated.title.trim().isEmpty) {
        return 'Title is required';
      }
      if (updated.text.trim().isEmpty) {
        return 'Text content is required';
      }
      if (updated.title.length > 200) {
        return 'Title must be 200 characters or less';
      }
      if (updated.text.length > 5000) {
        return 'Text content must be 5000 characters or less';
      }
      return null;
    },
    beforeSave: (session, transaction, initial, updated) async {
      // Set createdAt for new posts
      final processed = initial == null
          ? updated.copyWith(createdAt: DateTime.now())
          : updated;

      // Trim whitespace from text fields
      final finalProcessed = processed.copyWith(
        title: processed.title.trim(),
        text: processed.text.trim(),
      );

      return DwPreSaveResult(model: finalProcessed);
    },
  ),
);
