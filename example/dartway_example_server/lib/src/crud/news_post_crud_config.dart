import 'package:dartway_push_server/dartway_push_server.dart';
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import 'package:dartway_example_server/src/dartway/dartway_core.dart';
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
        session.isUser(saveContext.currentModel.authorProfileId),
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
    // A broadcast reaches the screens that are open; a push reaches the rest.
    // Only on insert, and only when push is configured at all — the dispatcher
    // drops everyone without a device or without marketing consent, and gives
    // the message a lifetime, so nothing here has to think about audiences.
    afterSaveSideEffects: (session, saveContext) async {
      if (!saveContext.isInsert) return;
      final post = saveContext.currentModel;
      await dwPushDispatcher?.sendToEveryone(
        session,
        page:
            (
              session, {
              required afterId,
              required limit,
              required transaction,
            }) async {
              final profiles = await UserProfile.db.find(
                session,
                where: afterId == null ? null : (table) => table.id > afterId,
                orderBy: (table) => table.id,
                limit: limit,
                transaction: transaction,
              );
              return profiles
                  .map((profile) => profile.id)
                  .whereType<int>()
                  .toList();
            },
        category: ExamplePushCategories.newsPost,
        title: post.title,
        body: post.text,
        // Where the tap lands. `dwPushLinkDataKey` is read back by the app
        // half under the same name, and on web the transport hands it to FCM a
        // second time as `webpush.fcm_options.link` — so the notification
        // opens the news screen even in a browser whose service worker never
        // took the click.
        data: {dwPushLinkDataKey: '/news', 'news_post_id': '${post.id}'},
        // Stable, so publishing the same post twice — a retried request, a
        // double tap — does not notify the club twice.
        deduplicationKey: 'news_post:${post.id}',
        excludeRecipientId: post.authorProfileId,
      );
    },
  ),
  deleteConfig: DwDeleteConfig<NewsPost>(
    allowDelete: (session, model) => session.isStaffMember,
    // A deleted post has to disappear everywhere too — without this the other
    // clients keep showing a post that is no longer there.
    broadcastTo: (session, model) => [DwCoreConst.publicUpdatesChannel],
  ),
);
