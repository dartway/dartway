import 'dart:typed_data';

import 'package:dartway_core_server/testing.dart';
import 'package:dartway_starter_server/dartway_starter_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:test/test.dart';

import 'support/app_harness.dart';

/// A profile photo: uploaded by the real client straight to the storage, set
/// on the profile by its file id, shown by its public URL. Runs against an
/// S3-compatible storage named by `DW_STORAGE_ENDPOINT`,
/// `DW_STORAGE_ACCESS_KEY` and `DW_STORAGE_SECRET_KEY` — `dartway test`
/// starts a MinIO for the run — on a public and a private bucket of its own
/// that the server verifies at startup as in production.
void main() {
  group('configuration from the environment', () {
    const credentials = {
      'DW_STORAGE_ACCESS_KEY': 'app',
      'DW_STORAGE_SECRET_KEY': 'app-secret',
    };

    test('without an endpoint there is no storage', () {
      expect(AppFiles.storageConfig(const {}), isNull);
      expect(
        AppFiles.storageConfig(const {
          'DW_STORAGE_ENDPOINT': '',
          ...credentials,
        }),
        isNull,
      );
    });

    test('a development MinIO needs only its endpoint and keys', () {
      final config = AppFiles.storageConfig(const {
        'DW_STORAGE_ENDPOINT': 'http://127.0.0.1:8100/',
        ...credentials,
      })!;
      expect(config.publicBucket, AppFiles.defaultPublicBucket);
      expect(config.privateBucket, AppFiles.defaultPrivateBucket);
      expect(
        config.publicBaseUrl,
        Uri.parse('http://127.0.0.1:8100/${AppFiles.defaultPublicBucket}'),
      );
      expect(config.verifyBuckets, isTrue);
    });

    test('what the environment names wins over every default', () {
      final config = AppFiles.storageConfig(const {
        'DW_STORAGE_ENDPOINT': 'https://storage.example.net',
        'DW_STORAGE_PUBLIC_BUCKET': 'files',
        'DW_STORAGE_PUBLIC_BASE_URL': 'https://cdn.example.net',
        'DW_STORAGE_PRIVATE_BUCKET': 'documents',
        'DW_STORAGE_VERIFY_BUCKETS': 'false',
        ...credentials,
      })!;
      expect(config.publicBucket, 'files');
      expect(config.publicBaseUrl, Uri.parse('https://cdn.example.net'));
      expect(config.privateBucket, 'documents');
      expect(config.verifyBuckets, isFalse);
    });
  });

  group('on real storage', () {
    late DwTestStorage storage;
    late AppHarness app;

    setUpAll(() async {
      storage = await DwTestStorage.create(prefix: 'app-test');
      app = await AppHarness.start(storage: storage.config);
    });
    tearDownAll(() async {
      await app.stop();
      await storage.drop();
    });

    Uint8List image(int size, int seed) =>
        Uint8List.fromList([for (var i = 0; i < size; i++) (i * seed) & 0xff]);

    test(
      'a member uploads a photo and sets it: the profile carries its public '
      'URL, live; a replaced photo and a cleared one leave the storage',
      () async {
        final admin = await app.admin('79990004001', 'Anna');
        final vera = await app.signUp('79990004002', firstName: 'Vera');
        final profile = await vera.watch(const GetMyProfile());
        final card = await admin.watch(
          GetUserCard(profileId: await vera.profileId),
        );

        final bytes = image(2048, 7);
        final file = (await vera.client.files.upload(
          DartwayStarterUpload.avatar,
          DwUploadSource.bytes(bytes),
          fileName: 'me.png',
          contentType: 'image/png',
        )).valueOrThrow;
        expect(
          file.url,
          startsWith(
            '${storage.config.publicBaseUrl}/avatar/${vera.accountId}/',
          ),
          reason: 'a public purpose lands in the public bucket',
        );
        final avatarPrefix = '${DartwayStarterUpload.avatar.purposeName}/';
        expect(
          await storage.keys(storage.publicBucket),
          contains(startsWith(avatarPrefix)),
        );
        expect(
          await storage.keys(storage.privateBucket),
          isNot(contains(startsWith(avatarPrefix))),
        );

        final updated = (await vera.client.command(
          UpdateMyProfile(avatarFileId: DwFieldPatch.set(file.id)),
        )).valueOrThrow;
        expect(updated.avatarUrl, file.url);
        expect(dataOf(profile.state)!.avatarUrl, file.url);
        await dwWaitUntil(
          () => dataOf(card.state)!.profile.avatarUrl == file.url,
        );
        final read = await getAnonymously(updated.avatarUrl!);
        expect(read.status, 200, reason: 'no credentials were sent');
        expect(read.bytes, bytes);

        // Someone else's file is not a photo anyone may set.
        final oleg = await app.signUp('79990004003', firstName: 'Oleg');
        expect(
          await oleg.client.command(
            UpdateMyProfile(avatarFileId: DwFieldPatch.set(file.id)),
          ),
          refusedWith(DwUploadRefusal.notOwned),
        );

        // A type the purpose does not take is refused before storage sees it.
        expect(
          await vera.client.files.upload(
            DartwayStarterUpload.avatar,
            DwUploadSource.bytes(image(10, 3)),
            fileName: 'me.gif',
            contentType: 'image/gif',
          ),
          refusedWith(DwUploadRefusal.typeRejected),
        );

        final second = (await vera.client.files.upload(
          DartwayStarterUpload.avatar,
          DwUploadSource.bytes(image(1024, 11)),
          fileName: 'me2.jpg',
          contentType: 'image/jpeg',
        )).valueOrThrow;
        await vera.client.command(
          UpdateMyProfile(avatarFileId: DwFieldPatch.set(second.id)),
        );
        expect(dataOf(profile.state)!.avatarUrl, second.url);
        app.server.wakeJobs();
        await dwWaitUntil(
          () async => (await getAnonymously(file.url!)).status == 404,
          reason: 'the replaced photo is deleted once the change commits',
        );
        expect((await getAnonymously(second.url!)).status, 200);

        final cleared = (await vera.client.command(
          const UpdateMyProfile(avatarFileId: DwFieldPatch.clear()),
        )).valueOrThrow;
        expect(cleared.avatarUrl, isNull);
        expect(dataOf(profile.state)!.avatarUrl, isNull);
        app.server.wakeJobs();
        await dwWaitUntil(
          () async => (await getAnonymously(second.url!)).status != 200,
        );
      },
    );

    test('deleting the account removes the profile and the photo, and ends the '
        'session', () async {
      final nina = await app.signUp('79990004010', firstName: 'Nina');
      final file = (await nina.client.files.upload(
        DartwayStarterUpload.avatar,
        DwUploadSource.bytes(image(512, 5)),
        fileName: 'nina.png',
        contentType: 'image/png',
      )).valueOrThrow;
      await nina.client.command(
        UpdateMyProfile(avatarFileId: DwFieldPatch.set(file.id)),
      );

      expect(await nina.client.deleteAccount(), isA<DwCallOk<void>>());
      expect(nina.client.accountId, isNull);
      expect(
        await app.db.query(
          'SELECT 1 FROM user_profile WHERE account_id = @id',
          params: {'id': nina.accountId},
        ),
        isEmpty,
      );
      app.server.wakeJobs();
      await dwWaitUntil(
        () async => (await getAnonymously(file.url!)).status != 200,
        reason: 'the photo leaves the storage with the account',
      );
    });
  });
}
