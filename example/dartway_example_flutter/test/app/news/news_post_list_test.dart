import 'dart:async';

import 'package:dartway_example_flutter/app/news/widgets/news_post_card.dart';
import 'package:dartway_example_flutter/app/news/widgets/news_post_list.dart';
import 'package:dartway_example_flutter/shared/widgets/load_failed_message.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/example_test_core.dart';

/// The read half of the news feature, in the three states that actually break:
/// still loading, nothing to show, and the server saying no.
///
/// The list asks for nothing and is handed nothing — it watches
/// `dw.repo.modelList<NewsPost>()` and draws whatever comes back. So the only
/// place to stand is the transport, which is what the core was handed instead
/// of a Serverpod client.
void main() {
  setUpAll(bootExampleTestCore);
  setUp(resetExampleTestCore);

  testWidgets('draws a skeleton while the server has not answered', (
    tester,
  ) async {
    final answer = Completer<void>();
    exampleTransport.answerGetAll = (_) async {
      await answer.future;
      return newsPostsResponse(const []);
    };

    await tester.pumpFeature(const NewsPostList());
    await tester.pump();

    // The skeleton is built from the registered default model, so it has the
    // shape of a real card rather than a spinner.
    expect(find.byType(NewsPostCard), findsWidgets);
    expect(find.text('Pool closed on Monday'), findsNothing);

    answer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('draws every post the server answered with', (tester) async {
    exampleTransport.answerGetAll = (_) async => newsPostsResponse([
      newsPost(id: 1, title: 'Pool closed on Monday'),
      newsPost(id: 2, title: 'New yoga coach'),
    ]);

    await tester.pumpFeature(const NewsPostList());
    await tester.pumpAndSettle();

    expect(find.text('Pool closed on Monday'), findsOneWidget);
    expect(find.text('New yoga coach'), findsOneWidget);
    expect(find.byType(NewsPostCard), findsNWidgets(2));

    // The list is unfiltered on purpose — news is readable by everyone signed
    // in — and this is where that stops being a claim in a doc comment. The
    // request still carries a filter object: the list always sends one, and an
    // empty `and` is how it says "narrow nothing".
    final read = exampleTransport.reads.single;
    expect(read.operation, 'getAll');
    expect(read.className, 'NewsPost');
    expect(read.apiGroup, isNull);
    expect(read.filter!.children, isEmpty);
  });

  testWidgets('says there is no news rather than showing an empty page', (
    tester,
  ) async {
    exampleTransport.answerGetAll = (_) async => newsPostsResponse(const []);

    await tester.pumpFeature(const NewsPostList());
    await tester.pumpAndSettle();

    expect(find.byType(NewsPostCard), findsNothing);
    expect(find.text('No news yet — stay tuned!'), findsOneWidget);
  });

  testWidgets('says the read failed, and offers a way out of it', (
    tester,
  ) async {
    exampleTransport.answerGetAll = (_) async =>
        throw TimeoutException('the backend is unreachable');

    await tester.pumpFeature(const NewsPostList());
    await tester.pumpAndSettle();

    // The distinction that matters to a member: "nothing was published" and
    // "we could not ask" must not look the same, and neither may look like
    // nothing at all. `dwBuildListAsync` defaults `errorWidget` to
    // `SizedBox.shrink()`, which is right for a decoration and wrong for the
    // feed this screen exists for — so the feature passes an `errorBuilder`
    // (dartway-clean-code §1.5a). The error also goes to the dw pipeline
    // (alerting), which is the framework's business rather than this test's.
    // A failed read is retried: Riverpod 3 retries a failed provider on its
    // own, with a growing backoff, so `pumpAndSettle` drains a whole run of
    // attempts rather than the one this test asked for. Assert the shape, not
    // the count — pinning the count here would pin somebody else's default.
    expect(exampleTransport.reads, isNotEmpty);
    expect(exampleTransport.reads.map((read) => read.operation).toSet(), {
      'getAll',
    });
    expect(find.byType(NewsPostCard), findsNothing);
    expect(find.text('No news yet — stay tuned!'), findsNothing);
    expect(find.byType(LoadFailedMessage), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('the retry throws the failed read away and asks again', (
    tester,
  ) async {
    exampleTransport.answerGetAll = (_) async =>
        throw TimeoutException('the backend is unreachable');

    await tester.pumpFeature(const NewsPostList());
    await tester.pumpAndSettle();

    exampleTransport.answerGetAll = (_) async =>
        newsPostsResponse([newsPost(id: 1, title: 'Pool closed on Monday')]);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    // This is the one sanctioned `ref.invalidate` (§1.5): the user asked for
    // the state to be thrown away and fetched again, so the reset is the point
    // rather than the cost.
    expect(find.byType(LoadFailedMessage), findsNothing);
    expect(find.text('Pool closed on Monday'), findsOneWidget);
  });
}
