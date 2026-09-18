import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_server/dartway_push_server.dart';

import '../../generated/dw_schema.dart';
import '../club_objects.dart';
import '../entities/content.dart';
import '../entities/people.dart';
import '../example_context.dart';
import 'admin_handlers.dart';

const _news = DwLiveChannel(ExampleChannel.news);

final contentHandlers = <DwCallHandler>[
  DwCallHandler.list<ListNews, NewsPost>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async => ClubObjects.news(
      ctx.db,
      await ctx.db.newsPosts.find(
        orderBy: (t) => [t.createdAt.desc(), t.id.desc()],
      ),
    ),
  ),

  DwCallHandler.command<PublishNews, NewsPost>(
    access: ExampleAccess.staff,
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
      final post = (await ClubObjects.news(ctx.db, [row], author: me)).single;
      ctx.publish(_news, post);
      await ctx.publishAdminCounters();
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
        category: ExamplePushCategory.news,
        dedupKey: 'news:${post.id}',
      );
      return post;
    },
  ),

  DwCallHandler.command<RemoveNews, void>(
    access: ExampleAccess.staff,
    handle: (ctx, command) async {
      if (await ctx.db.newsPosts.delete(command.postId) == 0) {
        ctx.refuse(DwCoreRefusal.notFound);
      }
      ctx.publish(
        _news,
        DwDeletedObject.of<NewsPost>(command.postId, ctx.protocol),
      );
      await ctx.publishAdminCounters();
    },
  ),

  DwCallHandler.list<ListAppSettings, AppSetting>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async => [
      for (final row in await ctx.db.appSettings.find(
        orderBy: (t) => [t.key.asc()],
      ))
        AppSetting(id: row.key, value: row.value),
    ],
  ),

  DwCallHandler.command<SaveAppSetting, AppSetting>(
    access: ExampleAccess.admin,
    handle: (ctx, command) async {
      final existing = await ctx.db.appSettings.findFirst(
        where: (t) => t.key.equals(command.key),
        lock: DwRowLock.forUpdate,
      );
      final saved = existing == null
          ? await ctx.db.appSettings.insert(
              AppSettingRow(key: command.key, value: command.value),
            )
          : await ctx.db.appSettings.update(
              existing.copyWith(value: command.value),
            );
      final setting = AppSetting(id: saved.key, value: saved.value);
      ctx.publish(const DwLiveChannel(ExampleChannel.settings), setting);
      return setting;
    },
  ),
];
