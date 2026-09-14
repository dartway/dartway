import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/example_test_app.dart';

const boris = PersonCard(id: 2, firstName: 'Boris');
const desk = ChatChannel(id: 1, title: 'Front desk');
const deskChannel = DwLiveChannel(ExampleChannel.staffChat, 1);
final start = DateTime.utc(2026, 9, 14, 9);

ChatMessage message(int n) => ChatMessage(
  id: n,
  channelId: desk.id,
  text: 'Note $n',
  author: boris,
  createdAt: start.add(Duration(minutes: n)),
);

/// A staff member's club with a chat of [count] messages, served by windows
/// as the real server serves them.
FakeClub staffClubWithChat(List<ChatMessage> chat) {
  final club = FakeClub(role: UserRole.staff);
  club.server
    ..onRequest<ListChatChannels>(
      (request, call) => const DwCallOk(<ChatChannel>[desk]),
    )
    ..onRequest<ListChatMessages>(
      (request, call) =>
          DwCallOk(dwFakeWindow(chat.reversed.toList(), request, call.page)),
    );
  return club;
}

void main() {
  testWidgets('the chat opens at the newest messages, loads older ones on '
      'scroll and shows a new one live', (tester) async {
    final chat = [for (var n = 1; n <= 40; n++) message(n)];
    final club = staffClubWithChat(chat);
    final app = await ExampleTestApp.start(tester, club);

    await app.tap(tester, find.text('Team chat'));
    expect(find.text('Note 40'), findsOneWidget);
    expect(app.server.requestsOf<ListChatMessages>(), hasLength(1));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 5000));
    await app.settle(tester);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 5000));
    await app.settle(tester);
    expect(find.text('Note 1'), findsOneWidget);
    expect(
      app.server.callsOf<ListChatMessages>().last.query,
      containsPair('before', isNotEmpty),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -20000));
    await app.settle(tester);
    chat.add(message(41));
    app.server.publish(deskChannel, [chat.last]);
    await app.settle(tester);
    expect(find.text('Note 41'), findsOneWidget);
    expect(app.server.requestsOf<ListChatMessages>(), hasLength(2));

    await app.stop(tester);
  });

  testWidgets('reopened, the chat stands where it was left: later messages '
      'wait below it, and one arriving live is counted', (tester) async {
    final chat = [for (var n = 1; n <= 10; n++) message(n)];
    final club = staffClubWithChat(chat);
    final app = await ExampleTestApp.start(tester, club);

    await app.tap(tester, find.text('Team chat'));
    expect(find.text('Note 10'), findsOneWidget);
    await app.tap(tester, find.text('News'));

    // Sixty messages while away: more than a reopened window and one page
    // after it read.
    chat.addAll([for (var n = 11; n <= 70; n++) message(n)]);
    await app.tap(tester, find.text('Team chat'));
    expect(
      app.server.callsOf<ListChatMessages>().last.query,
      contains('anchor'),
    );
    // The anchor is the last message on screen; the later ones lie below it.
    final list = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    expect(
      tester.getBottomLeft(find.text('Note 10')).dy,
      lessThanOrEqualTo(tester.getBottomLeft(list).dy),
    );
    expect(find.text('Note 9'), findsOneWidget);
    expect(find.text('Newer messages'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Show newer messages'),
      -300,
      scrollable: list,
    );
    // To the end of the list, past the room it keeps under the chip.
    await tester.drag(list, const Offset(0, -200));
    await app.settle(tester);
    await app.tap(tester, find.text('Show newer messages'));
    expect(
      app.server.callsOf<ListChatMessages>().last.query,
      contains('after'),
    );
    expect(find.text('Note 26'), findsOneWidget);

    chat.add(message(71));
    app.server.publish(deskChannel, [chat.last]);
    await app.settle(tester);
    expect(find.text('1 new message'), findsOneWidget);
    expect(find.text('Note 71'), findsNothing);

    await app.tap(tester, find.text('1 new message'));
    expect(app.server.callsOf<ListChatMessages>().last.query, isEmpty);
    expect(find.text('Note 71'), findsOneWidget);
    expect(find.text('Show newer messages'), findsNothing);
    expect(app.server.requestsOf<ListChatMessages>(), hasLength(4));

    await app.stop(tester);
  });
}
