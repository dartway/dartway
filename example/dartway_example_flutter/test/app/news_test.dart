import 'package:dartway_example_flutter/app/news/widgets/news_post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/example_test_app.dart';

const coach = PersonCard(id: 2, firstName: 'Boris');

NewsPost post(int id, String title, DateTime createdAt) => NewsPost(
  id: id,
  title: title,
  text: 'Details inside.',
  author: coach,
  createdAt: createdAt,
);

void main() {
  testWidgets(
    'a post published anywhere appears at the top, without a refetch',
    (tester) async {
      final club = FakeClub()
        ..news.add(post(1, 'Pool closed on Monday', DateTime.utc(2026, 9, 1)));
      final app = await ExampleTestApp.start(tester, club);

      await app.tap(tester, find.text('News'));
      expect(find.text('Pool closed on Monday'), findsOneWidget);

      app.server.publish(newsChannel, [
        post(2, 'New yoga coach', DateTime.utc(2026, 9, 2)),
      ]);
      await app.settle(tester);

      final titles = tester
          .widgetList<NewsPostCard>(find.byType(NewsPostCard))
          .map((card) => card.post.title);
      expect(titles, ['New yoga coach', 'Pool closed on Monday']);
      expect(
        app.server.requestsOf<ListNews>(),
        hasLength(1),
        reason: 'the post arrived on the channel, not by asking again',
      );

      await app.stop(tester);
    },
  );

  testWidgets('a refused post is explained in the user\'s language', (
    tester,
  ) async {
    final club = FakeClub(role: UserRole.staff);
    club.server.onCommand<PublishNews>(
      (command, call) =>
          DwCallRefused<NewsPost>(DwCallRefusal(DwCoreRefusal.forbidden)),
    );
    final app = await ExampleTestApp.start(tester, club);

    await app.tap(tester, find.text('News'));
    await app.tap(tester, find.byType(FloatingActionButton));
    await tester.enterText(find.byType(TextField).first, '  Pool closed  ');
    await tester.enterText(find.byType(TextField).last, 'Maintenance day.');
    await app.settle(tester);
    await app.tap(tester, find.text('Publish'));

    final sent = app.server.callsOf<PublishNews>().single.call;
    expect(
      sent,
      const PublishNews(title: 'Pool closed', text: 'Maintenance day.'),
    );
    expect(find.text('You are not allowed to do this.'), findsOneWidget);
    expect(find.text('Post published!'), findsNothing);
    expect(find.text('New club post'), findsOneWidget, reason: 'sheet stays');
    expect(
      app.logs,
      isEmpty,
      reason: 'a refusal is an answer, not an incident',
    );

    await app.stop(tester);
  });
}
