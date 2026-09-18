import 'dart:io';
import 'dart:typed_data';

import 'package:dartway_core_server/testing.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_server/src/entities/chat.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:test/test.dart';

import 'support/chat_support.dart';
import 'support/club_harness.dart';

/// The staff chat on real clients, over real HTTP and the live socket, against
/// the real server and database — and, for attachments, real storage.
void main() {
  group('without storage', () {
    late ClubHarness club;

    setUpAll(() async => club = await ClubHarness.start());
    tearDownAll(() => club.stop());

    test(
      'a client is refused every chat call and every chat channel',
      () async {
        final vera = await club.member('79993000001', 'Vera');
        final boris = await club.staff('79993000002', 'Boris');
        final channel = await club.chatChannel('Staff only');
        final message = await boris.send(channel.id!, 'Shift starts at eight');

        final forbidden = refusedWith(DwCoreRefusal.forbidden);
        final client = vera.client;
        expect(await client.fetch(const ListChatChannels()), forbidden);
        expect(await client.fetch(const ListMyChatReadStates()), forbidden);
        expect(
          await client.fetch(ListPinnedChatMessages(channelId: channel.id!)),
          forbidden,
        );
        expect(
          await client.fetch(
            ListChatMessagesMatching(channelId: channel.id!, query: 'shift'),
          ),
          forbidden,
        );
        expect(
          await client.command(
            SendChatMessage(channelId: channel.id!, text: 'hi'),
          ),
          forbidden,
        );
        expect(
          await client.command(
            EditChatMessage(messageId: message.id, text: 'mine now'),
          ),
          forbidden,
        );
        expect(
          await client.command(DeleteChatMessage(messageId: message.id)),
          forbidden,
        );
        expect(
          await client.command(
            PinChatMessage(messageId: message.id, pinned: true),
          ),
          forbidden,
        );
        expect(
          await client.command(
            ReactToChatMessage(
              messageId: message.id,
              reaction: ChatReaction.heart,
            ),
          ),
          forbidden,
        );
        expect(
          await client.command(
            MarkChatRead(channelId: channel.id!, messageId: message.id),
          ),
          forbidden,
        );

        final window = client.watchWindow(
          ListChatMessages(channelId: channel.id!),
        );
        addTearDown(window.close);
        await eventually(() => window.state is DwRequestRefused);
        expect(
          (window.state as DwRequestRefused).refusal.isCode(
            DwCoreRefusal.forbidden,
          ),
          isTrue,
        );

        final socket = await club.server.openLive();
        addTearDown(socket.close);
        await socket.authenticate(vera.session.token);
        for (final channelOfChat in [
          DwLiveChannel(ExampleChannel.staffChat, channel.id),
          const DwLiveChannel(ExampleChannel.staffChannels),
          // Her own account's key, and still no: she is not staff.
          DwLiveChannel.forAccount(ExampleChannel.chatReads, vera.accountId),
        ]) {
          final answer =
              await socket.subscribe(channelOfChat.wireName)
                  as DwSubscriptionRefusedMessage;
          expect(
            answer.refusal?.isCode(DwCoreRefusal.forbidden),
            isTrue,
            reason: channelOfChat.wireName,
          );
        }

        // Staff hear their own read states, and nobody else's.
        final staffSocket = await club.server.openLive();
        addTearDown(staffSocket.close);
        await staffSocket.authenticate(boris.session.token);
        expect(
          await staffSocket.subscribe(
            DwLiveChannel.forAccount(
              ExampleChannel.chatReads,
              boris.accountId,
            ).wireName,
          ),
          isA<DwSubscribedMessage>(),
        );
        expect(
          await staffSocket.subscribe(
            DwLiveChannel.forAccount(
              ExampleChannel.chatReads,
              vera.accountId,
            ).wireName,
          ),
          isA<DwSubscriptionRefusedMessage>(),
        );
      },
    );

    test('the window reads older and newer messages around an anchor, and '
        'counts what arrives past it', () async {
      final boris = await club.staff('79993000011', 'Boris');
      final galina = await club.staff('79993000012', 'Galina');
      final authorId = await club.profileIdOf(boris);
      final channel = await club.chatChannel('Front desk');
      // 70 messages in 35 instants: every read boundary falls on a tie.
      final base = DateTime.utc(2026, 9, 14, 9);
      final rows = await club.db.chatMessages.insertAll([
        for (var i = 0; i < 70; i++)
          ChatMessageRow(
            channelId: channel.id!,
            authorProfileId: authorId,
            text: 'm$i',
            sentAt: base.add(Duration(minutes: i ~/ 2)),
          ),
      ]);
      final request = ListChatMessages(channelId: channel.id!);
      List<String> texts(DwWindowWatch<ChatMessage> w) => [
        for (final m in itemsOf(w)) m.text,
      ];

      // At the newest: a page, then older pages to the start.
      final newest = boris.client.watchWindow(request);
      addTearDown(newest.close);
      await eventually(() => newest.isLive);
      expect(texts(newest), [for (var i = 69; i >= 30; i--) 'm$i']);
      expect(dataOf(newest.state)!.hasNewer, isFalse);
      while (dataOf(newest.state)!.hasOlder) {
        await newest.loadOlder();
      }
      expect(texts(newest), [for (var i = 69; i >= 0; i--) 'm$i']);
      expect(boris.http.posts('ListChatMessages'), 2);

      // Around m21 (it shares its instant with m20): both ways from there.
      final anchor = DwWindowCursor.encode(rows[21].sentAt, rows[21].id!);
      final around = galina.client.watchWindow(request, anchor: anchor);
      addTearDown(around.close);
      await eventually(() => around.isLive);
      final opened = dataOf(around.state)!;
      expect(opened.items.map((m) => m.text), contains('m21'));
      expect((opened.hasOlder, opened.hasNewer), (true, true));

      // A message arriving while newer ones are not loaded is counted, not
      // shown; the window at the newest shows it at once.
      final sent = await boris.send(channel.id!, 'live one');
      expect(texts(newest).first, 'live one', reason: 'from the response');
      await eventually(() => dataOf(around.state)!.unseenNewerCount == 1);
      expect(texts(around), isNot(contains('live one')));

      while (dataOf(around.state)!.hasNewer) {
        await around.loadNewer();
      }
      while (dataOf(around.state)!.hasOlder) {
        await around.loadOlder();
      }
      expect(texts(around), ['live one', for (var i = 69; i >= 0; i--) 'm$i']);
      expect(dataOf(around.state)!.unseenNewerCount, 0);
      expect(itemsOf(around).first.id, sent.id);

      // An unknown channel is not an empty one.
      expect(
        await boris.client.fetch(
          const ListPinnedChatMessages(channelId: 987654),
        ),
        refusedWith(DwCoreRefusal.notFound),
      );
    });

    test('a reply reaches the other window live; its author edits it within '
        'the window only, an admin deletes it, and the reply quotes it as '
        'deleted', () async {
      final boris = await club.staff('79993000021', 'Boris');
      final galina = await club.staff('79993000022', 'Galina');
      final anna = await club.admin('79993000023', 'Anna');
      final channel = await club.chatChannel('Front desk');
      final other = await club.chatChannel('Coaches');

      final galinaWindow = galina.client.watchWindow(
        ListChatMessages(channelId: channel.id!),
      );
      final borisWindow = boris.client.watchWindow(
        ListChatMessages(channelId: channel.id!),
      );
      addTearDown(() {
        galinaWindow.close();
        borisWindow.close();
      });
      await eventually(() => galinaWindow.isLive && borisWindow.isLive);

      final question = await boris.send(
        channel.id!,
        '  Who has the storage key?  ',
      );
      expect(question.text, 'Who has the storage key?', reason: 'trimmed');
      expect(question.author.firstName, 'Boris');
      await eventually(
        () => itemsOf(galinaWindow).any((m) => m.id == question.id),
      );

      final reply = await galina.send(
        channel.id!,
        'I do, it is at the desk',
        replyTo: question.id,
      );
      expect(reply.replyTo?.id, question.id);
      expect(reply.replyTo?.text, 'Who has the storage key?');
      expect(reply.replyTo?.authorName, 'Boris');
      expect(reply.replyTo?.isDeleted, isFalse);
      await eventually(
        () =>
            itemsOf(borisWindow).firstOrNull?.replyTo?.id == question.id &&
            itemsOf(borisWindow).first.id == reply.id,
        reason: "the reply reached Boris's window over the socket",
      );

      // A quote comes from the same channel, or not at all.
      final elsewhere = await boris.send(other.id!, 'Coaches only');
      expect(
        await galina.client.command(
          SendChatMessage(
            channelId: channel.id!,
            text: 'about that',
            replyToMessageId: elsewhere.id,
          ),
        ),
        refusedWith(DwCoreRefusal.notFound),
      );

      // Editing: the author's own, and the quote of it follows.
      final edited = (await boris.client.command(
        EditChatMessage(messageId: question.id, text: 'Who has the pool key?'),
      )).valueOrThrow;
      expect(edited.text, 'Who has the pool key?');
      expect(edited.editedAt, isNotNull);
      await eventually(
        () =>
            itemsOf(galinaWindow).any(
              (m) => m.id == question.id && m.text == 'Who has the pool key?',
            ) &&
            itemsOf(
                  galinaWindow,
                ).firstWhere((m) => m.id == reply.id).replyTo?.text ==
                'Who has the pool key?',
        reason: 'the edited message and the quote of it, live',
      );
      expect(
        await galina.client.command(
          EditChatMessage(messageId: question.id, text: 'Mine now'),
        ),
        refusedWith(DwCoreRefusal.forbidden),
      );
      expect(
        await boris.client.command(
          EditChatMessage(messageId: question.id, text: '   '),
        ),
        refusedWith(ExampleRefusal.messageEmpty),
      );

      final old = await boris.send(channel.id!, 'Yesterday I wrote this');
      final oldRow = (await club.db.chatMessages.findById(old.id))!;
      await club.db.chatMessages.update(
        oldRow.copyWith(
          sentAt: oldRow.sentAt.subtract(
            ChatMessage.editWindow + const Duration(minutes: 1),
          ),
        ),
      );
      expect(
        await boris.client.command(
          EditChatMessage(messageId: old.id, text: 'Too late'),
        ),
        refusedWith(ExampleRefusal.editWindowClosed),
      );

      // Deleting: not someone else's, unless an admin's.
      expect(
        await galina.client.command(DeleteChatMessage(messageId: question.id)),
        refusedWith(DwCoreRefusal.forbidden),
      );
      final deleted = await anna.client.command(
        DeleteChatMessage(messageId: question.id),
      );
      expect(deleted, isA<DwCallOk<void>>());
      await eventually(
        () =>
            itemsOf(galinaWindow).every((m) => m.id != question.id) &&
            itemsOf(
                  galinaWindow,
                ).firstWhere((m) => m.id == reply.id).replyTo?.isDeleted ==
                true,
        reason: 'the message left the window; the reply quotes it as deleted',
      );
      final quote = itemsOf(
        galinaWindow,
      ).firstWhere((m) => m.id == reply.id).replyTo!;
      expect(quote.text, isEmpty);

      expect(
        await anna.client.command(DeleteChatMessage(messageId: question.id)),
        refusedWith(DwCoreRefusal.notFound),
      );
      expect(
        await galina.client.command(
          SendChatMessage(
            channelId: channel.id!,
            text: 'and another thing',
            replyToMessageId: question.id,
          ),
        ),
        refusedWith(DwCoreRefusal.notFound),
      );

      // Read again from the start, the window agrees with what it heard.
      final fresh = (await galina.client.fetch(
        ListChatMessages(channelId: channel.id!),
      )).valueOrThrow;
      expect(fresh.items.map((m) => m.id), isNot(contains(question.id)));
      expect(
        fresh.items.firstWhere((m) => m.id == reply.id).replyTo?.isDeleted,
        isTrue,
      );
    });

    test('the pinned list of another member gains and loses messages live, '
        'newest first', () async {
      final boris = await club.staff('79993000031', 'Boris');
      final galina = await club.staff('79993000032', 'Galina');
      final channel = await club.chatChannel('Front desk');
      final pinned = galina.client.watch(
        ListPinnedChatMessages(channelId: channel.id!),
      );
      addTearDown(pinned.close);
      await eventually(() => pinned.isLive);
      expect(dataOf(pinned.state), isEmpty);
      List<int> pinnedIds() => [for (final m in dataOf(pinned.state)!) m.id];

      final first = await boris.send(channel.id!, 'Pool closes at 20:00');
      final second = await boris.send(channel.id!, 'New prices from Monday');
      final pinResult = (await boris.client.command(
        PinChatMessage(messageId: first.id, pinned: true),
      )).valueOrThrow;
      expect(pinResult.isPinned, isTrue);
      await boris.client.command(
        PinChatMessage(messageId: second.id, pinned: true),
      );
      await eventually(
        () => pinnedIds().length == 2,
        reason: 'both pins arrived',
      );
      expect(pinnedIds(), [second.id, first.id]);

      final unpinned = (await galina.client.command(
        PinChatMessage(messageId: first.id, pinned: false),
      )).valueOrThrow;
      expect(unpinned.isPinned, isFalse);
      expect(pinnedIds(), [second.id], reason: 'from the response');

      await boris.client.command(DeleteChatMessage(messageId: second.id));
      await eventually(() => pinnedIds().isEmpty);
      expect(
        (await galina.client.fetch(
          ListPinnedChatMessages(channelId: channel.id!),
        )).valueOrThrow,
        isEmpty,
      );
    });

    test('read positions move only forward; unread counts follow live and '
        'the position opens the window on it', () async {
      final boris = await club.staff('79993000041', 'Boris');
      final galina = await club.staff('79993000042', 'Galina');
      final channel = await club.chatChannel('Front desk');
      final other = await club.chatChannel('Coaches');

      final states = galina.client.watch(const ListMyChatReadStates());
      addTearDown(states.close);
      await eventually(() => states.isLive);
      ChatReadState stateOf(int channelId) =>
          dataOf(states.state)!.singleWhere((s) => s.id == channelId);
      expect(stateOf(channel.id!).unreadCount, 0);
      expect(stateOf(channel.id!).lastReadCursor, isNull);

      final m1 = await boris.send(channel.id!, 'one');
      final m2 = await boris.send(channel.id!, 'two');
      final m3 = await boris.send(channel.id!, 'three');
      await eventually(
        () => stateOf(channel.id!).unreadCount == 3,
        reason: "Galina's count grew live",
      );
      final borisStates = (await boris.client.fetch(
        const ListMyChatReadStates(),
      )).valueOrThrow;
      final borisDesk = borisStates.singleWhere((s) => s.id == channel.id);
      expect(borisDesk.unreadCount, 0, reason: 'his own messages');
      expect(borisDesk.lastReadMessageId, m3.id, reason: 'sending is reading');

      final marked = (await galina.client.command(
        MarkChatRead(channelId: channel.id!, messageId: m2.id),
      )).valueOrThrow;
      expect(marked.lastReadMessageId, m2.id);
      expect(marked.unreadCount, 1);
      expect(stateOf(channel.id!).unreadCount, 1);

      final back = (await galina.client.command(
        MarkChatRead(channelId: channel.id!, messageId: m1.id),
      )).valueOrThrow;
      expect(back.lastReadMessageId, m2.id, reason: 'never backwards');
      expect(back.unreadCount, 1);
      expect(
        await galina.client.command(
          MarkChatRead(channelId: other.id!, messageId: m3.id),
        ),
        refusedWith(DwCoreRefusal.notFound),
      );

      final m4 = await boris.send(channel.id!, 'four');
      await eventually(() => stateOf(channel.id!).unreadCount == 2);

      final window = galina.client.watchWindow(
        ListChatMessages(channelId: channel.id!),
        anchor: stateOf(channel.id!).lastReadCursor,
      );
      addTearDown(window.close);
      await eventually(() => window.isLive);
      final ids = [for (final m in itemsOf(window)) m.id];
      expect(ids, [m4.id, m3.id, m2.id, m1.id]);

      // A deleted unread message is not waiting any more.
      await boris.client.command(DeleteChatMessage(messageId: m3.id));
      await eventually(() => stateOf(channel.id!).unreadCount == 1);
      // Nothing of Coaches changed along the way.
      expect(stateOf(other.id!).unreadCount, 0);
    });

    test('search finds case-insensitively and literally, newest first, '
        'without deleted messages and within its limit', () async {
      final boris = await club.staff('79993000051', 'Boris');
      final galina = await club.staff('79993000052', 'Galinochka');
      final channel = await club.chatChannel('Front desk');
      Future<List<String>> search(String query) async => [
        for (final m in (await boris.client.fetch(
          ListChatMessagesMatching(channelId: channel.id!, query: query),
        )).valueOrThrow)
          m.text,
      ];

      await boris.send(channel.id!, 'Locker 14 is jammed');
      final second = await boris.send(channel.id!, 'The LOCKER room smells');
      await boris.send(channel.id!, 'Nothing to see here');
      await boris.send(channel.id!, '100% done_ok');
      await galina.send(channel.id!, 'Morning everyone');

      expect(await search('locker'), [
        'The LOCKER room smells',
        'Locker 14 is jammed',
      ]);
      expect(await search('0%'), ['100% done_ok'], reason: '% is literal');
      expect(await search('_o'), ['100% done_ok'], reason: '_ is literal');
      expect(await search('galinoch'), ['Morning everyone'], reason: 'author');

      await boris.client.command(DeleteChatMessage(messageId: second.id));
      expect(await search('LOCKER'), ['Locker 14 is jammed']);

      expect(
        await boris.client.fetch(
          ListChatMessagesMatching(channelId: channel.id!, query: ' l '),
        ),
        refusedWith(ExampleRefusal.searchQueryTooShort),
      );

      final authorId = await club.profileIdOf(boris);
      final base = DateTime.utc(2026, 9, 1);
      await club.db.chatMessages.insertAll([
        for (var i = 0; i < ListChatMessagesMatching.maxResults + 20; i++)
          ChatMessageRow(
            channelId: channel.id!,
            authorProfileId: authorId,
            text: 'bulk note $i',
            sentAt: base.add(Duration(minutes: i)),
          ),
      ]);
      final bulk = await search('bulk note');
      expect(bulk, hasLength(ListChatMessagesMatching.maxResults));
      expect(bulk.first, 'bulk note ${ListChatMessagesMatching.maxResults + 19}');
    });

    test('one reaction per member: set, replaced, taken back — and a double '
        'tap leaves one', () async {
      final boris = await club.staff('79993000061', 'Boris');
      final galina = await club.staff('79993000062', 'Galina');
      final anna = await club.admin('79993000063', 'Anna');
      final galinaId = await club.profileIdOf(galina);
      final annaId = await club.profileIdOf(anna);
      final channel = await club.chatChannel('Front desk');
      final message = await boris.send(channel.id!, 'New mats arrived');

      final window = boris.client.watchWindow(
        ListChatMessages(channelId: channel.id!),
      );
      addTearDown(window.close);
      await eventually(() => window.isLive);

      Future<ChatMessage> react(
        ClubMember member,
        ChatReaction? reaction,
      ) async => (await member.client.command(
        ReactToChatMessage(messageId: message.id, reaction: reaction),
      )).valueOrThrow;
      Map<int, ChatReaction> reactionsOf(ChatMessage m) => {
        for (final r in m.reactions) r.id: r.reaction,
      };

      expect(reactionsOf(await react(galina, ChatReaction.heart)), {
        galinaId: ChatReaction.heart,
      });
      expect(reactionsOf(await react(galina, ChatReaction.fire)), {
        galinaId: ChatReaction.fire,
      });
      expect(reactionsOf(await react(anna, ChatReaction.thumbsUp)), {
        galinaId: ChatReaction.fire,
        annaId: ChatReaction.thumbsUp,
      });
      await eventually(
        () => reactionsOf(itemsOf(window).single).length == 2,
        reason: "Boris's window heard the reactions",
      );
      expect(reactionsOf(await react(galina, null)), {
        annaId: ChatReaction.thumbsUp,
      });
      await eventually(() => reactionsOf(itemsOf(window).single).length == 1);

      final taps = await Future.wait([
        for (final reaction in [
          ChatReaction.money,
          ChatReaction.money,
          ChatReaction.thumbsDown,
        ])
          galina.client.command(
            ReactToChatMessage(messageId: message.id, reaction: reaction),
          ),
      ]);
      expect(taps, everyElement(isA<DwCallOk<ChatMessage>>()));
      final stored = await club.db.chatMessageReactions.find(
        where: (t) =>
            t.messageId.equals(message.id) & t.profileId.equals(galinaId),
      );
      expect(stored, hasLength(1));
    });
    test('a member who deletes their account leaves their messages behind, '
        'signed by nobody', () async {
      final boris = await club.staff('79993000091', 'Boris');
      final galina = await club.staff('79993000092', 'Galina');
      final channel = await club.chatChannel('Front desk');
      final borisProfileId = await club.profileIdOf(boris);
      final mine = await boris.send(channel.id!, 'I am off to another club');
      final hers = await galina.send(channel.id!, 'Good luck!');

      expect(await boris.client.deleteAccount(), isA<DwCallOk<void>>());

      final window = galina.client.watchWindow(
        ListChatMessages(channelId: channel.id!),
      );
      addTearDown(window.close);
      await eventually(() => itemsOf(window).length == 2);
      final left = itemsOf(window).firstWhere((m) => m.id == mine.id);
      expect(left.text, 'I am off to another club');
      expect(left.author.id, borisProfileId, reason: 'the author is the same row');
      expect(left.author.isDeleted, isTrue);
      expect(left.author.firstName, isEmpty);
      expect(
        itemsOf(window).firstWhere((m) => m.id == hers.id).author.isDeleted,
        isFalse,
      );

      // Nothing of the person is left in the row that outlived them.
      final tombstone = (await club.db.userProfiles.findById(borisProfileId))!;
      expect(tombstone.accountId, isNull);
      expect(tombstone.deletedAt, isNotNull);
      expect(tombstone.phone, isEmpty);
      expect(tombstone.lastName, isNull);
      expect(tombstone.imageUrl, isNull);
      expect(
        await club.db.query(
          'SELECT 1 FROM dw_account WHERE id = @id',
          params: {'id': boris.accountId},
        ),
        isEmpty,
        reason: 'the account itself is gone, only the tombstone stays',
      );
    });

  });

  group('attachments on real storage', () {
    late DwTestStorage storage;
    late ClubHarness club;

    setUpAll(() async {
      storage = await DwTestStorage.create(prefix: 'chat-test');
      club = await ClubHarness.start(storage: storage.config);
    });
    tearDownAll(() async {
      await club.stop();
      await storage.drop();
    });

    Future<DwStoredFile> upload(
      ClubMember member,
      List<int> bytes, {
      String fileName = 'plan.png',
      String contentType = 'image/png',
    }) async => (await member.client.files.upload(
      ExampleUpload.chatAttachment,
      DwUploadSource.bytes(Uint8List.fromList(bytes)),
      fileName: fileName,
      contentType: contentType,
    )).valueOrThrow;

    Future<List<int>> download(String url) async {
      final http = HttpClient();
      try {
        final response = await (await http.getUrl(Uri.parse(url))).close();
        expect(response.statusCode, 200);
        return await response.expand((chunk) => chunk).toList();
      } finally {
        http.close(force: true);
      }
    }

    test('staff read an attachment through a link while its message exists; '
        'a client never does', () async {
      final boris = await club.staff('79993000071', 'Boris');
      final galina = await club.staff('79993000072', 'Galina');
      final vera = await club.member('79993000073', 'Vera');
      final channel = await club.chatChannel('Front desk');
      final bytes = List.generate(256, (i) => i % 251);

      final file = await upload(boris, bytes);
      expect(file.url, isNull, reason: 'private: no public URL');

      // Before it is sent, the file is its uploader's alone.
      expect(
        (await boris.client.files.getLink(file.id)).valueOrNull,
        isNotNull,
      );
      expect(
        await galina.client.files.getLink(file.id),
        refusedWith(DwCoreRefusal.forbidden),
      );

      final message = await boris.send(
        channel.id!,
        '',
        attachments: [ChatAttachmentDraft(id: file.id, width: 16, height: 16)],
      );
      final attachment = message.attachments.single;
      expect(attachment.id, file.id);
      expect(attachment.fileName, 'plan.png');
      expect(attachment.contentType, 'image/png');
      expect(attachment.byteSize, bytes.length);
      expect((attachment.width, attachment.height), (16, 16));
      expect(attachment.isImage, isTrue);

      final window = (await galina.client.fetch(
        ListChatMessages(channelId: channel.id!),
      )).valueOrThrow;
      expect(window.items.single.attachments.single.fileName, 'plan.png');

      final link = (await galina.client.files.getLink(file.id)).valueOrThrow;
      expect(await download(link.url), bytes);
      expect(
        await vera.client.files.getLink(file.id),
        refusedWith(DwCoreRefusal.forbidden),
      );

      // With an attachment, the text may go.
      expect(
        await boris.client.command(
          EditChatMessage(messageId: message.id, text: ''),
        ),
        isA<DwCallOk<ChatMessage>>(),
      );

      // A deleted message takes its files out of reach.
      await boris.client.command(DeleteChatMessage(messageId: message.id));
      expect(
        await galina.client.files.getLink(file.id),
        refusedWith(DwCoreRefusal.forbidden),
      );
    });

    test("someone else's file, a file already sent and a client's upload are "
        'refused', () async {
      final boris = await club.staff('79993000081', 'Boris');
      final galina = await club.staff('79993000082', 'Galina');
      final vera = await club.member('79993000083', 'Vera');
      final channel = await club.chatChannel('Front desk');

      final file = await upload(
        boris,
        List.filled(64, 7),
        fileName: 'notes.txt',
        contentType: 'text/plain',
      );
      final notOwned = refusedWith(DwUploadRefusal.notOwned);
      expect(
        await galina.client.command(
          SendChatMessage(
            channelId: channel.id!,
            text: 'look',
            attachments: [ChatAttachmentDraft(id: file.id)],
          ),
        ),
        notOwned,
      );
      await boris.send(
        channel.id!,
        'notes',
        attachments: [ChatAttachmentDraft(id: file.id)],
      );
      expect(
        await boris.client.command(
          SendChatMessage(
            channelId: channel.id!,
            text: 'again',
            attachments: [ChatAttachmentDraft(id: file.id)],
          ),
        ),
        notOwned,
      );

      final byClient = await vera.client.files.upload(
        ExampleUpload.chatAttachment,
        DwUploadSource.bytes(Uint8List(8)),
        fileName: 'x.png',
        contentType: 'image/png',
      );
      expect(byClient, refusedWith(DwCoreRefusal.forbidden));
      expect(
        await club.db.chatMessageAttachments.count(
          where: (t) => t.fileId.equals(file.id),
        ),
        1,
        reason: 'only the one message carries the file',
      );
    });
  });
}
