import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/main.dart' as app;
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  testWidgets('startup reports the platform build as 1.0.0+521', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'DartwayStarter',
      packageName: 'com.example.dartwayStarter',
      version: '1.0.0',
      buildNumber: '521',
      buildSignature: '',
    );
    final previousFlutterError = FlutterError.onError;
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final previousPlatformError = dispatcher.onError;
    try {
      // Run the production entrypoint; replace its root before bootstrap
      // starts so this test needs neither device storage nor a backend.
      await app.main();
      FlutterError.onError = previousFlutterError;
      dispatcher.onError = previousPlatformError;
      expect(dw.config.appVersion, '1.0.0+521');
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppVersionLabel())),
      );
      expect(find.text('1.0.0+521'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await dw.dispose();
      FlutterError.onError = previousFlutterError;
      dispatcher.onError = previousPlatformError;
    }
  });
}
