import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_server/dartway_server.dart';

import '../../generated/dw_schema.dart';
import '../entities/content.dart';
import '../example_context.dart';
import '../projections.dart';
import 'admin_handlers.dart';

const _news = DwChannel(ExampleChannel.news);

/// The settings the app declares. A key outside this set is refused: settings
/// are configuration the app reads, not a free-form store.
const exampleSettingKeys = {'clubName', 'bookingEnabled', 'supportPhone'};

final contentHandlers = <DwHandler>[
  DwHandler.request<ListNews, List<NewsPostView>>(
    access: DwAccess.signedIn,
    handle: (ctx, request) async => Views.news(
      ctx.db,
      await ctx.db.newsPosts.find(
        orderBy: (t) => [t.createdAt.desc(), t.id.desc()],
      ),
    ),
  ),

  DwHandler.command<PublishNews, NewsPostView>(
    access: ExampleAccess.staff,
    handle: (ctx, command) async {
      if (command.title.trim().isEmpty) {
        ctx.refuse(ExampleRefusal.titleRequired, field: 'title');
      }
      if (command.text.trim().isEmpty) {
        ctx.refuse(ExampleRefusal.textRequired, field: 'text');
      }
      final post = await ctx.db.newsPosts.insert(
        NewsPost(
          authorProfileId: (await ctx.profile).id!,
          title: command.title.trim(),
          text: command.text.trim(),
          createdAt: DateTime.now(),
        ),
      );
      final view = (await Views.news(ctx.db, [post])).single;
      ctx.publish(_news, view);
      await publishAdminCounters(ctx);
      return view;
    },
  ),

  DwHandler.command<RemoveNews, void>(
    access: ExampleAccess.staff,
    handle: (ctx, command) async {
      if (await ctx.db.newsPosts.delete(command.postId) == 0) {
        ctx.refuse(DwCoreRefusal.notFound);
      }
      ctx.publish(_news, DwDeleted.of<NewsPostView>(command.postId, ctx.protocol));
      await publishAdminCounters(ctx);
    },
  ),

  DwHandler.request<ListChatChannels, List<ChatChannelView>>(
    access: ExampleAccess.staff,
    handle: (ctx, request) async => [
      for (final c in await ctx.db.chatChannels.find(
        orderBy: (t) => [t.title.asc(), t.id.asc()],
      ))
        ChatChannelView(id: c.id!, title: c.title),
    ],
  ),

  DwHandler.page<ListChatMessages, ChatMessageView>(
    access: ExampleAccess.staff,
    handle: (ctx, request, page) async {
      final before = page.before as int?;
      return Views.messages(
        ctx.db,
        await ctx.db.chatMessages.find(
          where: (t) => before == null
              ? t.channelId.equals(request.channelId)
              : t.channelId.equals(request.channelId) & t.id.lt(before),
          orderBy: (t) => [t.id.desc()],
          limit: page.fetchLimit,
        ),
      );
    },
  ),

  DwHandler.command<SendChatMessage, ChatMessageView>(
    access: ExampleAccess.staff,
    handle: (ctx, command) async {
      final text = command.text.trim();
      if (text.isEmpty) ctx.refuse(ExampleRefusal.messageEmpty, field: 'text');
      if (await ctx.db.chatChannels.findById(command.channelId) == null) {
        ctx.refuse(DwCoreRefusal.notFound);
      }
      final message = await ctx.db.chatMessages.insert(
        ChatMessage(
          channelId: command.channelId,
          authorProfileId: (await ctx.profile).id!,
          text: text,
          createdAt: DateTime.now(),
        ),
      );
      final view = (await Views.messages(ctx.db, [message])).single;
      ctx.publish(DwChannel(ExampleChannel.staffChat, command.channelId), view);
      return view;
    },
  ),

  DwHandler.request<ListAppSettings, List<AppSettingView>>(
    access: DwAccess.signedIn,
    handle: (ctx, request) async => [
      for (final s in await ctx.db.appSettings.find(
        orderBy: (t) => [t.key.asc()],
      ))
        AppSettingView(id: s.key, value: s.value),
    ],
  ),

  DwHandler.command<SaveAppSetting, AppSettingView>(
    access: ExampleAccess.admin,
    handle: (ctx, command) async {
      if (!exampleSettingKeys.contains(command.key)) {
        ctx.refuse(ExampleRefusal.settingKeyUnknown, field: 'key');
      }
      final existing = await ctx.db.appSettings.findFirst(
        where: (t) => t.key.equals(command.key),
        lock: DwLock.forUpdate,
      );
      final saved = existing == null
          ? await ctx.db.appSettings.insert(
              AppSetting(key: command.key, value: command.value),
            )
          : await ctx.db.appSettings.update(
              existing.copyWith(value: command.value),
            );
      final view = AppSettingView(id: saved.key, value: saved.value);
      ctx.publish(const DwChannel(ExampleChannel.settings), view);
      return view;
    },
  ),
];
