import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_server/dartway_push_server.dart';

import '../../generated/dw_schema.dart';
import '../admin/admin_publications.dart';
import '../core/call_context.dart';
import '../core/channels.dart';
import '../profile/profile_rows.dart';
import 'content_objects.dart';
import 'content_rows.dart';

final contentHandlers = <DwCallHandler>[
  /// The news feed, newest first. Every signed-in member.
  DwCallHandler.list<ListNews, NewsPost>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async => ContentObjects.news(
      ctx.db,
      await ctx.db.newsPosts.find(
        orderBy: (t) => [t.createdAt.desc(), t.id.desc()],
      ),
    ),
  ),

  /// Publishes a news post by the caller. Staff only. The post goes to the
  /// feed and the admin counters, and a push to every member but the author.
  DwCallHandler.command<PublishNews, NewsPost>(
    access: AppAccess.staff,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final row = await ctx.db.newsPosts.insert(
        NewsPostRow(
          authorProfileId: me.id!,
          title: command.title.trim(),
          text: command.text.trim(),
          createdAt: DateTime.now(),
        ),
      );
      final post = (await ContentObjects.news(ctx.db, [
        row,
      ], author: me)).single;
      ctx.publish(AppChannels.news, post);
      await AdminPublications.counters(ctx);
      // Queued in this transaction: a refused or failed publication notifies
      // nobody. Who of the members receives it is the push eligibility rule's
      // decision (marketing consent), taken when the delivery is due.
      // Everyone but the author, and nobody who left: a tombstone profile
      // has no account to push to.
      final members = await ctx.db.userProfiles.find(
        where: (t) =>
            t.accountId.isNotNull() & t.accountId.notEquals(me.ownerAccountId),
      );
      await ctx.push.send(
        [for (final member in members) member.ownerAccountId],
        message: DwPushMessage(
          title: post.title,
          body: post.text.length > 140
              ? '${post.text.substring(0, 139)}…'
              : post.text,
          data: NewsAlert(id: post.id),
          link: '/news',
        ),
        category: DartwayExamplePushCategory.news,
        dedupKey: 'news:${post.id}',
      );
      return post;
    },
  ),

  /// Removes a news post. Staff only; gone from the feed and the counters.
  DwCallHandler.command<RemoveNews, void>(
    access: AppAccess.staff,
    handle: (ctx, command) async {
      if (await ctx.db.newsPosts.delete(command.postId) == 0) {
        ctx.refuse(DwCoreRefusal.notFound);
      }
      ctx.publish(
        AppChannels.news,
        DwDeletedObject.of<NewsPost>(command.postId, ctx.protocol),
      );
      await AdminPublications.counters(ctx);
    },
  ),

  /// The club's settings, their defaults while nobody has saved them. Every
  /// signed-in member.
  DwCallHandler.single<GetClubSettings, ClubSettings>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) => ctx.settings.read<ClubSettings>(),
  ),

  /// Changes the settings the command names, the rest as they are. Admins
  /// only; published to every member.
  DwCallHandler.command<SaveClubSettings, ClubSettings>(
    access: AppAccess.admin,
    handle: (ctx, command) async {
      final saved = await ctx.settings.update<ClubSettings>(
        (current) => current.copyWith(
          clubName: command.clubName?.trim(),
          bookingEnabled: command.bookingEnabled,
          supportPhone: command.supportPhone.trimmedOrCleared,
        ),
      );
      ctx.publish(AppChannels.settings, saved);
      return saved;
    },
  ),
];
