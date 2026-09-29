import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../../support/app_test_app.dart';

/// The profile: a photo goes straight to storage and onto the profile by its
/// file id; name and gender are saved when they change.
void main() {
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
