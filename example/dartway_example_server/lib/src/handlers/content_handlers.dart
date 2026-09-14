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

  DwCallHandler.list<ListChatChannels, ChatChannel>(
    access: ExampleAccess.staff,
    handle: (ctx, request) async => [
      for (final row in await ctx.db.chatChannels.find(
        orderBy: (t) => [t.title.asc(), t.id.asc()],
      ))
        ChatChannel(id: row.id!, title: row.title),
    ],
  ),

  DwCallHandler.window<ListChatMessages, ChatMessage, DateTime, int>(
    access: ExampleAccess.staff,
    handle: (ctx, request, window) async {
      final position = window.position;
      final older = window.direction == DwWindowDirection.older;
      final rows = await ctx.db.chatMessages.find(
        where: (t) {
          final inChannel = t.channelId.equals(request.channelId);
          if (position == null) return inChannel;
          final (:sortValue, :id) = position;
          // `(createdAt, id)` compared as a pair. The bound on `createdAt`
          // alone is what the index range scan starts from; the pair decides
          // among messages sent at the same instant.
          return older
              ? inChannel &
                    t.createdAt.lte(sortValue) &
                    (t.createdAt.lt(sortValue) |
                        (window.includesPosition ? t.id.lte(id) : t.id.lt(id)))
              : inChannel &
                    t.createdAt.gte(sortValue) &
                    (t.createdAt.gt(sortValue) | t.id.gt(id));
        },
        orderBy: (t) => older
            ? [t.createdAt.desc(), t.id.desc()]
            : [t.createdAt.asc(), t.id.asc()],
        limit: window.fetchLimit,
      );
      return ClubObjects.messages(ctx.db, rows);
    },
  ),

  DwCallHandler.command<SendChatMessage, ChatMessage>(
    access: ExampleAccess.staff,
    handle: (ctx, command) async {
      final me = await ctx.profile;
      final ChatMessageRow row;
      try {
        row = await ctx.db.chatMessages.insert(
          ChatMessageRow(
            channelId: command.channelId,
            authorProfileId: me.id!,
            text: command.text.trim(),
            createdAt: DateTime.now(),
          ),
        );
      } on DwForeignKeyViolation {
        ctx.refuse(DwCoreRefusal.notFound);
      }
      final message = (await ClubObjects.messages(ctx.db, [
        row,
      ], author: me)).single;
      ctx.publish(
        DwLiveChannel(ExampleChannel.staffChat, command.channelId),
        message,
      );
      return message;
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
