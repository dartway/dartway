import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/example_test_app.dart';

const boris = PersonCard(id: 2, firstName: 'Boris');
const desk = ChatChannel(id: 1, title: 'Front desk');
const coaches = ChatChannel(id: 2, title: 'Coaches');
const deskChannel = DwLiveChannel(ExampleChannel.staffChat, 1);
final start = DateTime.utc(2026, 9, 14, 9);

ChatMessage message(int n, {String? text, DateTime? pinnedAt}) => ChatMessage(
  id: n,
  channelId: desk.id,
  text: text ?? 'Note $n',
  author: boris,
  sentAt: start.add(Duration(minutes: n)),
  pinnedAt: pinnedAt,
);

String cursorOf(int n) =>
    DwWindowCursor.encode(start.add(Duration(minutes: n)), n);

/// A staff member's club with a front desk chat of [count] messages, served
/// by windows as the real server serves them, and what the chat's commands
/// were sent.
final class ChatClub {
  ChatClub(int count, {this.readUpTo, List<int> pinned = const []})
    : chat = [
        for (var n = 1; n <= count; n++)
          message(
            n,
            text: n == 7 ? 'Towels are out at the pool' : null,
            pinnedAt: pinned.contains(n) ? start : null,
          ),
      ] {
    club.server
      ..onRequest<ListChatChannels>(
        (request, call) => const DwCallOk(<ChatChannel>[desk, coaches]),
      )
      ..onRequest<ListMyChatReadStates>(
        (request, call) => DwCallOk(<ChatReadState>[
          ChatReadState(
            id: desk.id,
            unreadCount: readUpTo == null ? 0 : chat.length - readUpTo!,
            lastReadMessageId: readUpTo,
            lastReadSentAt: readUpTo == null
                ? null
                : start.add(Duration(minutes: readUpTo!)),
          ),
          const ChatReadState(id: 2, unreadCount: 4),
        ]),
      )
      ..onRequest<ListChatMessages>(
        (request, call) =>
            DwCallOk(dwFakeWindow(chat.reversed.toList(), request, call.page)),
      )
      ..onRequest<ListPinnedChatMessages>(
        (request, call) => DwCallOk([
          for (final m in chat.reversed)
            if (m.isPinned) m,
        ]),
      )
      ..onRequest<ListChatMessagesMatching>(
        (request, call) => DwCallOk([
          for (final m in chat.reversed)
            if (m.text.toLowerCase().contains(request.query.toLowerCase())) m,
        ]),
      )
      ..onCommand<MarkChatRead>((command, call) {
        marks.add(command.messageId);
        return DwCallOk(
          ChatReadState(
            id: command.channelId,
            unreadCount: 0,
            lastReadMessageId: command.messageId,
          ),
        );
      })
      ..onCommand<SendChatMessage>((command, call) {
        sent.add(command);
        final next = ChatMessage(
          id: chat.length + 1,
          channelId: command.channelId,
          text: command.text,
          author: const PersonCard(id: 7, firstName: 'Vera'),
          sentAt: start.add(Duration(minutes: chat.length + 1)),
        );
        chat.add(next);
        call.publish(deskChannel, [next]);
        return DwCallOk(next);
      });
  }

  final club = FakeClub(role: UserRole.staff);
  final List<ChatMessage> chat;
  final int? readUpTo;
  final marks = <int>[];
  final sent = <SendChatMessage>[];

  List<Map<String, String>> get windowQueries => [
    for (final call in club.server.callsOf<ListChatMessages>()) call.query,
  ];
}

Finder get messageList => find.byKey(const ValueKey('chat-message-list'));

void main() {
  testWidgets('the chat opens where the member stopped reading, under the '
      'unread divider, and marks read what comes on screen', (tester) async {
    final world = ChatClub(120, readUpTo: 80);
    final app = await ExampleTestApp.start(tester, world.club);

    await app.tap(tester, find.text('Team chat'));
    expect(world.windowQueries.first, containsPair('anchor', cursorOf(80)));
    expect(find.text('Unread messages'), findsOneWidget);
    expect(find.text('Note 80'), findsOneWidget);
    expect(find.text('Note 81'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Unread messages')).dy,
      lessThan(tester.getTopLeft(find.text('Note 81')).dy),
    );
    // The other channel's unread count stands on its chip.
    expect(find.text('4'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await app.settle(tester);
    expect(world.marks, isNotEmpty);
    expect(world.marks.last, greaterThan(80));
    final marked = world.marks.last;

    // Scrolling back up marks nothing older.
    await tester.drag(messageList, const Offset(0, 400));
    await tester.pump(const Duration(seconds: 2));
    await app.settle(tester);
    expect(world.marks.last, marked);

    await app.stop(tester);
  });

  testWidgets('scrolled up, a new message moves nothing and is counted on the '
      'arrow, which goes to it', (tester) async {
    final world = ChatClub(60);
    final app = await ExampleTestApp.start(tester, world.club);
    await app.tap(tester, find.text('Team chat'));
    expect(world.windowQueries.first, isEmpty, reason: 'at the newest');
    expect(find.text('Note 60'), findsOneWidget);

    await tester.drag(messageList, const Offset(0, 1200));
    await app.settle(tester);
    final anchor = find.text(
      tester.widgetList<Text>(find.textContaining('Note ')).first.data!,
    );
    final y = tester.getTopLeft(anchor).dy;

    world.chat.add(message(61));
    app.server.publish(deskChannel, [world.chat.last]);
    await app.settle(tester);
    expect(tester.getTopLeft(anchor).dy, moreOrLessEquals(y, epsilon: 1));
    expect(find.text('Note 61'), findsNothing);
    expect(find.text('1'), findsOneWidget, reason: 'the arrow counts it');

    await app.tap(tester, find.byKey(const ValueKey('chat-jump-to-newest')));
    await tester.pump(const Duration(milliseconds: 500));
    await app.settle(tester);
    expect(find.text('Note 61'), findsOneWidget);

    await app.stop(tester);
  });

  testWidgets('the pinned bar goes to a pinned message far back in the '
      'history', (tester) async {
    final world = ChatClub(300, pinned: [5]);
    final app = await ExampleTestApp.start(tester, world.club);
    await app.tap(tester, find.text('Team chat'));
    expect(find.text('Pinned message'), findsOneWidget);
    expect(find.text('Note 5'), findsOneWidget, reason: 'on the bar');

    await app.tap(tester, find.byKey(const ValueKey('chat-pinned-bar')));
    await app.settle(tester);
    expect(world.windowQueries, contains(containsPair('anchor', cursorOf(5))));
    expect(find.text('Note 5'), findsNWidgets(2), reason: 'bar and list');
    expect(find.text('Note 6'), findsOneWidget);

    await app.stop(tester);
  });

  testWidgets('a reply is sent with the message it answers', (tester) async {
    final world = ChatClub(20);
    final app = await ExampleTestApp.start(tester, world.club);
    await app.tap(tester, find.text('Team chat'));

    await tester.longPress(find.text('Note 19'));
    await app.settle(tester);
    await app.tap(tester, find.text('Reply'));
    expect(find.text('Reply to Boris'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('chat-message-field')),
      'On it',
    );
    await tester.pump();
    await app.tap(tester, find.byKey(const ValueKey('chat-send')));
    expect(world.sent.single.replyToMessageId, 19);
    expect(world.sent.single.text, 'On it');
    expect(find.text('Reply to Boris'), findsNothing);
    expect(find.text('On it'), findsOneWidget);

    await app.stop(tester);
  });

  testWidgets('a search goes to its match, however far back', (tester) async {
    final world = ChatClub(200);
    final app = await ExampleTestApp.start(tester, world.club);
    await app.tap(tester, find.text('Team chat'));
    expect(find.textContaining('are out at the pool'), findsNothing);

    await app.tap(tester, find.byKey(const ValueKey('chat-search-toggle')));
    await tester.enterText(
      find.byKey(const ValueKey('chat-search-field')),
      'towels',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await app.settle(tester);
    await app.settle(tester);
    expect(find.text('1 of 1'), findsOneWidget);
    expect(world.windowQueries, contains(containsPair('anchor', cursorOf(7))));
    expect(find.textContaining('are out at the pool'), findsOneWidget);

    await app.stop(tester);
  });
}
