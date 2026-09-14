import 'dart:typed_data';

import 'package:dartway_core_flutter/dartway_core_flutter.dart';
import 'package:dartway_starter_flutter/app/profile/identity/widgets/identity_change_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../support/app_test_app.dart';

/// The profile: a photo goes straight to storage and onto the profile by its
/// file id; the phone and the e-mail are added and changed by a code sent to
/// the new value.
void main() {
  Future<TestApp> openProfile(
    WidgetTester tester,
    FakeApp fake, {
    DwStorageTransport? storageTransport,
  }) async {
    final app = await TestApp.start(
      tester,
      fake,
      size: const Size(390, 1400),
      storageTransport: storageTransport,
    );
    await app.tap(tester, find.text('Profile'));
    return app;
  }

  testWidgets('a picked photo uploads to storage, and the profile takes it by '
      'its file id and shows it', (tester) async {
    final fake = FakeApp();
    final storage = DwFakeStorage(fake.server);
    final picker = _FakePicker(
      XFile.fromData(
        Uint8List.fromList(List.generate(300, (i) => i % 256)),
        name: 'me.png',
        mimeType: 'image/png',
      ),
    );
    ImagePickerPlatform.instance = picker;
    final app = await openProfile(
      tester,
      fake,
      storageTransport: storage.transport,
    );
    fake.avatarUrls[1] = 'https://storage.test/avatar/1.png';

    await app.tap(tester, find.byIcon(Icons.photo_camera_outlined));
    expect(picker.picks, 1);
    expect(storage.files.single.contentType, 'image/png');
    expect(storage.files.single.byteSize, 300);
    final start =
        app.server.callsOf<DwStartUpload>().single.call as DwStartUpload;
    expect(start.purpose, DartwayStarterUpload.avatar.purposeName);
    expect(
      app.server.callsOf<UpdateMyProfile>().single.call,
      UpdateMyProfile(avatarFileId: DwFieldPatch.set(storage.files.single.id)),
    );
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(
      (avatar.foregroundImage! as NetworkImage).url,
      'https://storage.test/avatar/1.png',
    );
    expect(find.text('Photo updated'), findsOneWidget);

    await app.waitOutNotifications(tester);
    await app.tap(tester, find.text('Remove photo'));
    expect(
      app.server.callsOf<UpdateMyProfile>().last.call,
      const UpdateMyProfile(avatarFileId: DwFieldPatch.clear()),
    );
    expect(
      tester.widget<CircleAvatar>(find.byType(CircleAvatar)).foregroundImage,
      isNull,
    );

    await app.stop(tester);
  });

  testWidgets('a photo storage refuses is explained under it, and the profile '
      'is not touched', (tester) async {
    final fake = FakeApp();
    final storage = DwFakeStorage(fake.server)
      ..refuseStart = (command) => DwCallRefusal(
        DwUploadRefusal.tooLarge,
        field: 'byteSize',
        params: {'maxBytes': DartwayStarterUpload.avatarMaxBytes},
      );
    ImagePickerPlatform.instance = _FakePicker(
      XFile.fromData(Uint8List(10), name: 'big.jpg', mimeType: 'image/jpeg'),
    );
    final app = await openProfile(
      tester,
      fake,
      storageTransport: storage.transport,
    );

    await app.tap(tester, find.byIcon(Icons.photo_camera_outlined));
    expect(find.text('The file is too large: at most 5 MB.'), findsOneWidget);
    expect(app.server.callsOf<UpdateMyProfile>(), isEmpty);

    await app.stop(tester);
  });

  /// The framework's identifier commands as the real server answers them: a
  /// ticket for any identifier, [code] confirms it, an identifier in [taken]
  /// belongs to another account — told only after the right code — and a
  /// confirmed one lands on the profile, published to its channel.
  void answerIdentifierCodes(
    FakeApp fake, {
    String code = '654321',
    Set<String> taken = const {},
  }) {
    var tickets = 0;
    final requested = <String, DwRequestIdentifierCode>{};
    fake.server
      ..onCommand<DwRequestIdentifierCode>((command, call) {
        final id = 'attach-${++tickets}';
        requested[id] = command;
        return DwCallOk(
          DwCodeTicket(
            id: id,
            expiresAt: DateTime.now().add(const Duration(minutes: 10)),
            resendAfter: DateTime.now().add(const Duration(minutes: 1)),
          ),
        );
      })
      ..onCommand<DwConfirmIdentifier>((command, call) {
        final request = requested[command.ticketId]!;
        if (command.code != code) {
          return DwCallRefused<DwIdentityInfo>(
            DwCallRefusal(DwCoreRefusal.invalid, field: 'code'),
          );
        }
        if (taken.contains(request.identifier)) {
          return DwCallRefused<DwIdentityInfo>(
            DwCallRefusal(DwAuthRefusal.identifierTaken, field: 'code'),
          );
        }
        fake.profile = switch (request.kind) {
          DwIdentifierKind.phone => fake.profile.copyWith(
            phone: DwFieldPatch.set(request.identifier),
          ),
          DwIdentifierKind.email => fake.profile.copyWith(
            email: DwFieldPatch.set(request.identifier),
          ),
        };
        call.publish(profileChannel, [fake.profile]);
        return DwCallOk(
          DwIdentityInfo(
            id: 1,
            accountId: testSession.id,
            kind: request.kind,
            value: request.identifier,
            createdAt: DateTime.now(),
            verifiedAt: DateTime.now(),
          ),
        );
      });
  }

  Finder rowOf(String kind) =>
      find.ancestor(of: find.text(kind), matching: find.byType(ListTile));

  testWidgets('an e-mail is added by the code sent to it: the sheet closes and '
      'the profile shows it from the answer', (tester) async {
    final fake = FakeApp();
    answerIdentifierCodes(fake);
    final app = await openProfile(tester, fake);
    expect(find.text('Not added'), findsOneWidget);

    await app.tap(
      tester,
      find.descendant(of: rowOf('E-mail'), matching: find.text('Add')),
    );
    expect(find.byType(IdentityChangeSheet), findsOneWidget);
    final sheetField = find.descendant(
      of: find.byType(IdentityChangeSheet),
      matching: find.byType(TextField),
    );
    await app.enter(tester, sheetField, ' Vera@Example.com ');
    await app.tap(tester, find.text('Get a code'));
    expect(
      app.server.callsOf<DwRequestIdentifierCode>().single.call,
      const DwRequestIdentifierCode(
        kind: DwIdentifierKind.email,
        identifier: 'vera@example.com',
      ),
    );

    await app.enter(tester, sheetField, '654321');
    await app.tap(tester, find.text('Confirm'));
    expect(
      app.server.callsOf<DwConfirmIdentifier>().single.call,
      const DwConfirmIdentifier(ticketId: 'attach-1', code: '654321'),
    );
    expect(find.byType(IdentityChangeSheet), findsNothing);
    expect(find.text('vera@example.com'), findsOneWidget);
    expect(find.text('E-mail saved'), findsOneWidget);
    expect(
      app.server.requestsOf<GetMyProfile>(),
      hasLength(1),
      reason: 'the profile came with the answer, not by a re-read',
    );

    await app.stop(tester);
  });

  testWidgets('a phone is changed in place, and one taken by another account '
      'is refused after the code with nothing changed', (tester) async {
    final fake = FakeApp();
    answerIdentifierCodes(fake, taken: {'79990000099'});
    final app = await openProfile(tester, fake);

    Future<void> changePhoneTo(String number) async {
      await app.tap(
        tester,
        find.descendant(of: rowOf('Phone'), matching: find.text('Change')),
      );
      final sheetField = find.descendant(
        of: find.byType(IdentityChangeSheet),
        matching: find.byType(TextField),
      );
      await app.enter(tester, sheetField, number);
      await app.tap(tester, find.text('Get a code'));
      await app.enter(tester, sheetField, '654321');
      await app.tap(tester, find.text('Confirm'));
    }

    await changePhoneTo('+7 999 000-00-99');
    expect(
      (app.server.callsOf<DwConfirmIdentifier>().single.call
              as DwConfirmIdentifier)
          .replace,
      isTrue,
      reason: 'a member with a phone changes it rather than adding a second',
    );
    expect(
      find.text('This is already used by another account.'),
      findsOneWidget,
    );
    expect(find.byType(IdentityChangeSheet), findsOneWidget);
    expect(
      find.text('Get a code'),
      findsOneWidget,
      reason: 'back to the value',
    );
    expect(fake.profile.phone, '79990000002');

    await app.waitOutNotifications(tester);
    await tester.tapAt(const Offset(10, 10));
    await app.settle(tester);
    expect(find.byType(IdentityChangeSheet), findsNothing);

    await changePhoneTo('+7 999 000-00-55');
    expect(find.text('79990000055'), findsOneWidget);
    expect(find.text('Phone number saved'), findsOneWidget);

    await app.stop(tester);
  });

  testWidgets('name and gender are saved only when changed', (tester) async {
    final fake = FakeApp();
    final app = await openProfile(tester, fake);
    expect(find.text('Save changes'), findsNothing);

    await app.enter(tester, find.widgetWithText(TextField, 'Vera'), 'Vera P.');
    await app.tap(tester, find.text('Save changes'));
    expect(
      app.server.callsOf<UpdateMyProfile>().single.call,
      const UpdateMyProfile(firstName: 'Vera P.'),
    );
    expect(find.text('Save changes'), findsNothing);

    await app.stop(tester);
  });

  testWidgets('the admin panel is offered once the role is granted, live', (
    tester,
  ) async {
    final fake = FakeApp();
    final app = await openProfile(tester, fake);
    expect(find.text('Admin panel'), findsNothing);

    fake.profile = fake.profile.copyWith(role: UserRole.admin);
    app.server.publish(profileChannel, [fake.profile]);
    await app.settle(tester);
    expect(find.text('Admin panel'), findsOneWidget);

    await app.stop(tester);
  });
}

final class _FakePicker extends ImagePickerPlatform
    with MockPlatformInterfaceMixin {
  _FakePicker(this.file);

  final XFile file;
  int picks = 0;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    picks++;
    return file;
  }
}
