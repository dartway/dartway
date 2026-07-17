import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:dartway_example_server/src/dartway/dartway_session_extension.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';

/// CRUD configuration for the NewsPost model (club news and promotions).
/// Everyone reads the feed in realtime; only staff publishes.
final newsPostCrudConfig = DwCrudConfig<NewsPost>(
  table: NewsPost.t,
  getListConfig: DwGetModelListConfig(
    accessFilter: (session) async => null,
    include: NewsPost.include(authorProfile: UserProfile.include()),
    defaultOrderByList: [
      Order(column: NewsPost.t.createdAt, orderDescending: true),
    ],
  ),
  saveConfig: DwSaveConfig<NewsPost>(
    allowSave: (session, saveContext) async =>
        await session.isStaffMember &&
        await session.isUser(saveContext.currentModel.authorProfileId),
    validateSave: (session, saveContext) async {
      final post = saveContext.currentModel;
      if (post.title.trim().isEmpty) {
        return 'Title is required';
      }
      if (post.text.trim().isEmpty) {
        return 'Text content is required';
      }
      return null;
    },
    beforeSaveTransaction: (session, saveContext) async {
      if (saveContext.isInsert) {
        saveContext.currentModel = saveContext.currentModel.copyWith(
          createdAt: DateTime.now(),
        );
      }
      return null;
    },
  ),
  deleteConfig: DwDeleteConfig<NewsPost>(
    allowDelete: (session, model) => session.isStaffMember,
  ),
);
