import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_app.dart';

/// The app settings over a fake server: a row saves its own field, and a
/// value saved elsewhere arrives live.
void main() {
  testWidgets('a setting saves its own field, and one saved elsewhere arrives '
      'live', (tester) async {
    final fake = adminWith(const []);
    fake.server.onCommand<SaveAppSettings>((command, call) {
      final saved = fake.settings.copyWith(
        appName: command.appName,
        signUpEnabled: command.signUpEnabled,
      );
      fake.settings = saved;
      call.publish(settingsChannel, [saved]);
      return DwCallOk(saved);
    });
    final app = await TestApp.start(tester, fake);
    await app.tap(tester, find.text('Profile'));
    await app.tap(tester, find.text('Admin panel'));
    await app.tap(tester, find.text('Settings'));

    expect(
      find.widgetWithText(TextField, const AppSettings().appName),
      findsOneWidget,
      reason: 'nothing saved: the default',
    );
    await app.tap(tester, find.byType(Checkbox));
    expect(
      app.server.callsOf<SaveAppSettings>().single.call,
      const SaveAppSettings(signUpEnabled: false),
    );

    app.server.publish(settingsChannel, [
      const AppSettings(appName: 'Acme', signUpEnabled: false),
    ]);
    await app.settle(tester);
    expect(find.widgetWithText(TextField, 'Acme'), findsOneWidget);

    await app.stop(tester);
  });
}
