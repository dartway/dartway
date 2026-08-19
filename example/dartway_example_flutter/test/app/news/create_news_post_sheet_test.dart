import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/material.dart';
import 'package:dartway_example_flutter/app/news/widgets/create_news_post_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/example_test_core.dart';

/// The write half of the news feature: it renders, you fill it in, you tap
/// publish, and what leaves for the server is exactly what you typed.
///
/// The sheet takes no callback and returns no value — it saves for itself, the
/// way `dartway-data-layer` says a feature should. So there is nothing to spy
/// on above it, and the assertion lives one level below: on the transport the
/// core sends every write through.
void main() {
  setUpAll(bootExampleTestCore);
  setUp(resetExampleTestCore);

  final author = staffProfile(id: 7, firstName: 'Sam');

  testWidgets('publishes what was typed, under the signed-in author', (
    tester,
  ) async {
    await tester.pumpFeature(const CreateNewsPostSheet(), signedInAs: author);

    await tester.enterText(
      find.byType(TextField).first,
      '  Pool closed on Monday  ',
    );
    await tester.enterText(find.byType(TextField).last, '  Maintenance day.  ');
    // Settle, not pump: `AppTextFormField` delivers `onChanged` from a
    // post-frame callback, so the form's own state — and with it whether the
    // button is enabled — is one frame behind the keystroke.
    await tester.pumpAndSettle();

    expect(exampleTransport.saves, isEmpty, reason: 'nothing saves on typing');

    await tester.tapAndSettle(find.text('Publish'));

    expect(exampleTransport.saves, hasLength(1));
    final saved = exampleTransport.saves.single;
    expect(saved.wrappedModel.className, 'NewsPost');
    expect(saved.apiGroup, isNull);

    final post = saved.model as NewsPost;
    // Trimmed, which is the sheet's own rule and the reason the input above has
    // padding around it.
    expect(post.title, 'Pool closed on Monday');
    expect(post.text, 'Maintenance day.');
    // The author is the signed-in user, not anything the form offered.
    expect(post.authorProfileId, author.id);
    // A create, not an update: the id is the server's to assign.
    expect(post.id, isNull);
  });

  testWidgets('refuses to publish until both fields are filled', (
    tester,
  ) async {
    await tester.pumpFeature(const CreateNewsPostSheet(), signedInAs: author);

    await tester.tapAndSettle(find.text('Publish'));
    expect(exampleTransport.saves, isEmpty);

    // A title alone is not enough, and neither is whitespace in the body.
    await tester.enterText(find.byType(TextField).first, 'Pool closed');
    await tester.enterText(find.byType(TextField).last, '   ');
    await tester.pumpAndSettle();
    await tester.tapAndSettle(find.text('Publish'));
    expect(exampleTransport.saves, isEmpty);
  });

  testWidgets('tells the user when the server refuses the post', (
    tester,
  ) async {
    exampleTransport.answerSave = (_) async =>
        const DwApiResponse<DwModelWrapper>.forbidden();

    await tester.pumpFeature(const CreateNewsPostSheet(), signedInAs: author);
    await tester.enterText(find.byType(TextField).first, 'Pool closed');
    await tester.enterText(find.byType(TextField).last, 'Maintenance day.');
    await tester.pumpAndSettle();

    await tester.tapAndSettle(find.text('Publish'));

    // The write still left — the rule lives on the server, and this is the
    // client finding out. What matters is that the refusal is not swallowed.
    expect(exampleTransport.saves, hasLength(1));
    expect(find.text('Post published!'), findsNothing);
  });
}
