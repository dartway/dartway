import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../../generated/dw_schema.dart';
import '../club_objects.dart';
import '../entities/content.dart';
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
      await publishAdminCounters(ctx);
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
      await publishAdminCounters(ctx);
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
