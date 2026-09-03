import 'package:dartway_serverpod_core_server/src/business/cloud_storage/dw_cloud_storage.dart';
import 'package:test/test.dart';

/// The object key is built by the server and never by the caller, which is the
/// whole of the fix behind it: the endpoint used to sign an upload for whatever
/// key the client named, so any signed-in user who knew somebody else's key
/// could overwrite the object behind it — an overwrite object storage reports
/// on neither side.
///
/// This suite stands over the half of that guarantee which needs no database:
/// whatever the caller sends, the key that comes out sits under the caller's
/// own segment and is made of parts the caller did not choose.
void main() {
  const userId = 123;
  final at = DateTime.utc(2026, 9, 3, 14, 22, 7);

  String keyFor({
    String? folder,
    String fileExtension = '.jpg',
    String? fileName,
    int attempt = 0,
  }) => DwCloudStorage.buildObjectPath(
    userId: userId,
    folder: folder,
    fileExtension: fileExtension,
    fileName: fileName,
    attempt: attempt,
    at: at,
  );

  group("the key is the server's to build", () {
    test('it reads folder, then owner, then leaf', () {
      expect(
        keyFor(folder: 'avatars', fileName: 'photo'),
        'avatars/u123/2026-09-03T14-22-07_photo.jpg',
      );
    });

    test('the owner segment is there even when nothing was supplied', () {
      // A caller that names neither folder nor file still lands under itself:
      // ownership is a property of the key, not of what was asked for.
      expect(keyFor(), 'u123/2026-09-03T14-22-07.jpg');
    });

    test('the timestamp is 24-hour, so it names one moment', () {
      // `hh` printed the same string at 01:05 and at 13:05. Uniqueness no
      // longer rests on the stamp — the unique index does — but a name a human
      // reads off the bucket should not name two different moments.
      final afternoon = DwCloudStorage.buildObjectPath(
        userId: userId,
        fileExtension: '.jpg',
        at: DateTime.utc(2026, 9, 3, 13, 5),
      );
      final morning = DwCloudStorage.buildObjectPath(
        userId: userId,
        fileExtension: '.jpg',
        at: DateTime.utc(2026, 9, 3, 1, 5),
      );

      expect(afternoon, isNot(morning));
      expect(afternoon, contains('T13-05-00'));
    });
  });

  group('nothing the caller sends escapes its own prefix', () {
    test('a traversing folder is reduced to plain segments', () {
      expect(keyFor(folder: '../../etc'), startsWith('etc/u123/'));
    });

    test('an absolute folder does not make an absolute key', () {
      expect(keyFor(folder: '/avatars'), startsWith('avatars/u123/'));
    });

    test('a folder of nothing but traversal disappears', () {
      expect(keyFor(folder: '../..'), startsWith('u123/'));
    });

    test('a file name cannot add a path segment', () {
      // The whole attack in one line: name the leaf so that it climbs out of
      // the prefix the server has just put you in.
      final key = keyFor(folder: 'avatars', fileName: '../../u999/avatar');

      // The characters survive inside the leaf — what cannot survive is their
      // meaning: there is no second segment for them to become.
      expect(key, startsWith('avatars/u123/'));
      expect(key.split('/'), hasLength(3));
      expect(key, endsWith('_u999avatar.jpg'));
    });

    test('a backslash is a separator too', () {
      expect(keyFor(fileName: r'..\..\escape').split('/'), hasLength(2));
    });

    test('control characters do not reach the key', () {
      // A newline in a key is a header-splitting shape wherever the key is
      // echoed, and it is invisible in every log that would show it.
      final name = 'a${String.fromCharCode(10)}b${String.fromCharCode(0)}c';

      expect(keyFor(fileName: name), contains('_abc.'));
    });

    test('a folder cannot nest without limit', () {
      final key = keyFor(folder: 'a/b/c/d/e/f/g/h');

      // Four segments of folder, then the owner, then the leaf.
      expect(key.split('/'), hasLength(6));
      expect(key, startsWith('a/b/c/d/u123/'));
    });

    test('a very long name is cut rather than trusted', () {
      expect(keyFor(fileName: 'x' * 500).length, lessThan(200));
    });
  });

  group('the extension describes the bytes, not the picked file', () {
    test('it comes from its own argument', () {
      // An image picked as HEIC is uploaded as JPEG, and the recorded mime
      // type is read off this key — so taking the extension from the name
      // would record the format of the file that was picked.
      expect(
        keyFor(fileName: 'photo.heic', fileExtension: '.jpg'),
        endsWith('_photo.heic.jpg'),
      );
    });

    test('a leading dot is optional and the case is normalised', () {
      expect(keyFor(fileExtension: 'JPG'), endsWith('.jpg'));
    });

    test('something that is not an extension is dropped, not written', () {
      expect(keyFor(fileExtension: '../sh'), isNot(contains('.')));
    });
  });

  group('the discriminator is what a refused reservation retries with', () {
    test('the first attempt carries none', () {
      expect(keyFor(fileName: 'photo'), endsWith('_photo.jpg'));
    });

    test('each attempt is a key of its own', () {
      final keys = List.generate(
        5,
        (i) => keyFor(fileName: 'photo', attempt: i),
      );

      expect(keys.toSet(), hasLength(5));
      expect(keys[1], endsWith('_photo-1.jpg'));
    });
  });
}
