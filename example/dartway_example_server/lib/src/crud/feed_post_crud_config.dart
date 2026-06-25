import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_example_server/src/generated/protocol.dart';

/// CRUD configuration for the FeedPost model.
final feedPostCrudConfig = DwCrudConfig<FeedPost>(
  table: FeedPost.t,
  getListConfig: DwGetModelListConfig<FeedPost>(
    accessFilter: (session) async => null,
    include: FeedPost.include(
      authorProfile: UserProfile.include(),
    ),
  ),
  saveConfig: DwSaveConfig<FeedPost>(
    allowSave: (session, saveContext) async {
      return session.isUser(saveContext.currentModel.authorProfileId);
    },
    validateSave: (session, saveContext) async {
      final post = saveContext.currentModel;
      if (post.title.trim().isEmpty) {
        return 'Title is required';
      }
      if (post.text.trim().isEmpty) {
        return 'Text content is required';
      }
      if (post.title.length > 200) {
        return 'Title must be 200 characters or less';
      }
      if (post.text.length > 5000) {
        return 'Text content must be 5000 characters or less';
      }
      return null;
    },
    beforeSaveTransaction: (session, saveContext) async {
      var post = saveContext.currentModel;
      if (saveContext.isInsert) {
        post = post.copyWith(createdAt: DateTime.now());
      }
      saveContext.currentModel = post.copyWith(
        title: post.title.trim(),
        text: post.text.trim(),
      );
    },
  ),
);
