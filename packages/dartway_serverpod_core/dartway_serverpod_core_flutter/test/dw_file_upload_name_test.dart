import 'package:dartway_serverpod_core_flutter/src/utils/dw_file_upload_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// The object name is the whole of the protection here: the bucket serves
/// anonymous `GetObject`, so a key that can be guessed is a key that can be
/// read, and a key that can collide is a file that can be overwritten with no
/// trace on either side. Both properties are asserted against the two
/// templates, because those are what every upload goes through.
void main() {
  final xFile = XFile('/tmp/photo.heic');
  final platformFile = PlatformFile(
    name: 'photo.png',
    size: 1,
    path: '/tmp/photo.png',
  );

  group('the default object name does not come from the clock', () {
    test('a thousand names taken back to back are all different', () {
      // A calendar second was the whole key: two uploads inside one second
      // addressed one object, and the later one replaced the earlier.
      final names = List.generate(1000, (_) => DwFileUploadHandler.defaultUploadNameTemplate(xFile));

      expect(names.toSet(), hasLength(names.length));
    });

    test('the PlatformFile template is unique on the same terms', () {
      final names = List.generate(
        1000,
        (_) => DwFileUploadHandler.defaultPlatformUploadNameTemplate(platformFile),
      );

      expect(names.toSet(), hasLength(names.length));
    });

    test('neither template carries the extension — the upload appends it', () {
      // Split deliberately: `uploadXFileToServer` converts most images to
      // JPEG, so only it knows what the uploaded bytes are.
      expect(DwFileUploadHandler.defaultUploadNameTemplate(xFile), isNot(contains('.')));
      expect(
        DwFileUploadHandler.defaultPlatformUploadNameTemplate(platformFile),
        isNot(contains('.')),
      );
    });
  });

  test('the readable prefix is a 24-hour timestamp of now', () {
    // `hh` printed the same string at 01:05 and at 13:05. Uniqueness no longer
    // rests on this — the random segment carries it — but a name a human reads
    // off the bucket should not name two different moments.
    final name = DwFileUploadHandler.defaultUploadNameTemplate(xFile);
    final stamp = DateFormat('yyyy-MM-dd HH:mm:ss').parse(name.substring(0, 19));

    expect(DateTime.now().difference(stamp).inMinutes, lessThan(5));
  });
}
