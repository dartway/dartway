import 'package:dartway_example_flutter/app/news/news_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/example_test_app.dart';

void main() {
  testWidgets('a signed-in member\'s device is registered once', (
    tester,
  ) async {
    final transport = DwFakePushTransport(issuedToken: 'device-token');
    final app = await ExampleTestApp.start(
      tester,
      FakeClub(),
      pushTransports: [transport],
    );

    final calls = app.server.callsOf<DwRegisterPushToken>();
    expect(calls, hasLength(1));
    expect(
      calls.single.call,
      isA<DwRegisterPushToken>()
          .having((c) => c.token, 'token', 'device-token')
          .having((c) => c.transport, 'transport', DwPushTransport.fcm),
    );
    expect(calls.single.authorization, 'Bearer ${testSession.token}');

    // Moving around the app registers nothing more.
    await app.tap(tester, find.text('News'));
    expect(app.server.callsOf<DwRegisterPushToken>(), hasLength(1));

    await app.stop(tester);
  });

  testWidgets('opening a news notification opens the news', (tester) async {
    final transport = DwFakePushTransport(issuedToken: 'device-token');
    final app = await ExampleTestApp.start(
      tester,
      FakeClub(),
      pushTransports: [transport],
    );
    expect(find.byType(NewsPage), findsNothing);

    transport.open(const DwPushData(payload: NewsAlert(id: 1), link: '/news'));
    await app.settle(tester);

    expect(find.byType(NewsPage), findsOneWidget);
    await app.stop(tester);
  });

  testWidgets('a news notification that started the app lands on the news', (
    tester,
  ) async {
    final transport = DwFakePushTransport(
      issuedToken: 'device-token',
      initialOpen: const DwPushData(payload: NewsAlert(id: 1)).toWire(),
    );
    final app = await ExampleTestApp.start(
      tester,
      FakeClub(),
      pushTransports: [transport],
    );

    expect(find.byType(NewsPage), findsOneWidget);
    await app.stop(tester);
  });
}
