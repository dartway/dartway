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
    // The feed is the same for everyone, so a new post belongs on every screen
    // the moment it is published — no pull-to-refresh, no listener written in
    // the app. Whatever this save touched is routed by type into the
    // `dw.repo.modelList<NewsPost>()` the feed already watches.
    //
    // Safe here precisely because the model is public: its accessFilter grants
    // the whole audience. Broadcasting sends everything the save touched, so a
    // config whose rows belong to one person must not do this — see
    // sessionBookingCrudConfig, which picks what travels instead.
    broadcastTo: (session, saveContext) => [DwCoreConst.publicUpdatesChannel],
  ),
  deleteConfig: DwDeleteConfig<NewsPost>(
    allowDelete: (session, model) => session.isStaffMember,
    // A deleted post has to disappear everywhere too — without this the other
    // clients keep showing a post that is no longer there.
    broadcastTo: (session, model) => [DwCoreConst.publicUpdatesChannel],
  ),
);
