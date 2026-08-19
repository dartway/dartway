import 'package:dartway_starter_client/dartway_starter_client.dart';
import 'package:dartway_starter_flutter/admin/settings/widgets/admin_settings_form.dart';
import 'package:dartway_starter_flutter/core/app_settings/app_setting_key.dart';
import 'package:dartway_starter_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_core.dart';

/// The starting point for testing a feature in this project: it renders what
/// the server answered, you interact, and what leaves for the server is exactly
/// what you meant.
///
/// The form takes no callback and returns no value — it saves for itself, the
/// way a DartWay feature should. So there is nothing to spy on above it, and the
/// assertions live one level below, on the transport the core sends every write
/// through. Copy the shape of this file for your own features.
void main() {
  setUpAll(bootTestCore);
  setUp(resetTestCore);

  final admin = adminProfile();

  AppSetting storedAppName(String value) => AppSetting(
    id: 1,
    settingKey: AppSettingKey.appName.key,
    settingValue: value,
  );

  testWidgets('draws the stored value, and the default where no row exists', (
    tester,
  ) async {
    // Only one of the two settings has a row: `signUpEnabled` falls back to the
    // default in the catalogue, which is what a fresh database looks like.
    testTransport.answerGetAll = (_) async =>
        listResponse([storedAppName('Acme')]);

    await tester.pumpFeature(const AdminSettingsForm(), signedInAs: admin);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Acme'), findsOneWidget);
    expect(tester.widget<AppCheckbox>(find.byType(AppCheckbox)).value, isTrue);
    expect(testTransport.reads.single.className, 'AppSetting');
  });

  testWidgets('a toggle saves its own row and nothing else', (tester) async {
    testTransport.answerGetAll = (_) async =>
        listResponse([storedAppName('Acme')]);

    await tester.pumpFeature(const AdminSettingsForm(), signedInAs: admin);
    await tester.pumpAndSettle();

    await tester.tapAndSettle(find.byType(AppCheckbox));

    // The point of one row per setting: the write carries `signUpEnabled` and
    // says nothing about `appName`, so a second admin editing the name at the
    // same moment cannot be overwritten.
    expect(testTransport.saves, hasLength(1));
    final saved = testTransport.saves.single.model as AppSetting;
    expect(saved.settingKey, AppSettingKey.signUpEnabled.key);
    expect(saved.settingValue, 'false');
    // No row existed for it, so this is a create — the id is the server's to
    // assign.
    expect(saved.id, isNull);
  });

  testWidgets('editing a text setting updates the row it already has', (
    tester,
  ) async {
    testTransport.answerGetAll = (_) async =>
        listResponse([storedAppName('Acme')]);

    await tester.pumpFeature(const AdminSettingsForm(), signedInAs: admin);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '  Acme Corp  ');
    // Settle, not pump: `AppTextFormField` delivers `onChanged` from a
    // post-frame callback, so the form's own state — and with it whether the
    // Save button is enabled — is one frame behind the keystroke.
    await tester.pumpAndSettle();

    await tester.tapAndSettle(find.text('Save'));

    expect(testTransport.saves, hasLength(1));
    final saved = testTransport.saves.single.model as AppSetting;
    expect(saved.settingKey, AppSettingKey.appName.key);
    // Trimmed by the row, and written onto the existing id — an update, not a
    // second row for the same key.
    expect(saved.settingValue, 'Acme Corp');
    expect(saved.id, 1);
  });

  testWidgets('an unchanged text setting has nothing to save', (tester) async {
    testTransport.answerGetAll = (_) async =>
        listResponse([storedAppName('Acme')]);

    await tester.pumpFeature(const AdminSettingsForm(), signedInAs: admin);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Acme');
    await tester.pumpAndSettle();

    expect(
      tester.widget<AppButton>(find.byType(AppButton)).onTap,
      isNull,
      reason: 'the Save button is disabled while the value is the stored one',
    );
    expect(testTransport.saves, isEmpty);
  });
}
