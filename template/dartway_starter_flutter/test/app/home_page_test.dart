import 'package:flutter_test/flutter_test.dart';

import '../support/app_test_app.dart';

void main() {
  testWidgets('the app name comes from the server settings, and a name saved '
      'elsewhere arrives live', (tester) async {
    final fake = FakeApp();
    final app = await TestApp.start(tester, fake);
    expect(
      find.text('You are in DartwayStarter'),
      findsOneWidget,
      reason: 'nothing stored: the default',
    );

    app.server.publish(settingsChannel, [
      const AppSetting(id: AppSettingKeys.appName, value: 'Acme'),
    ]);
    await app.settle(tester);
    expect(find.text('You are in Acme'), findsOneWidget);
    expect(app.server.requestsOf<ListAppSettings>(), hasLength(1));

    await app.stop(tester);
  });
}
