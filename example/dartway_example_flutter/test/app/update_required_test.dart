import 'package:dartway_example_flutter/core/dw_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../support/example_test_app.dart';

void main() {
  testWidgets('a build below the server minimum is told to update', (
    tester,
  ) async {
    final club = FakeClub()..server.minAppBuild = 2;
    final app = await ExampleTestApp.start(tester, club);

    final refusal = dw.client.incompatibility;
    expect(refusal?.isCode(DwCoreRefusal.updateRequired), isTrue);

    // What the app runner puts in place of the whole app.
    await tester.pumpWidget(
      ProviderScope(
        child: Builder(
          builder: (context) =>
              dw.config.updateRequiredScreen!(context, refusal!),
        ),
      ),
    );
    await app.settle(tester);
    expect(find.text('Update the app'), findsOneWidget);

    await app.stop(tester);
  });
}
