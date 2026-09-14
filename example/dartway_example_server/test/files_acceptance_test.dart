import 'dart:io';
import 'dart:typed_data';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:test/test.dart';

import 'support/club_harness.dart';

/// The club's uploads on real storage: a member's avatar goes to the public
/// bucket and opens for anyone by its URL. Needs `DW_STORAGE_ENDPOINT`,
/// `DW_STORAGE_ACCESS_KEY` and `DW_STORAGE_SECRET_KEY` besides the database
/// (see `../README.md`).
void main() {
  group('configuration from the environment', () {
    const credentials = {
      'DW_STORAGE_ACCESS_KEY': 'club',
      'DW_STORAGE_SECRET_KEY': 'club-secret',
    };

    test('without an endpoint there is no storage', () {
      expect(exampleStorageConfig(const {}), isNull);
      expect(
        exampleStorageConfig(const {'DW_STORAGE_ENDPOINT': '', ...credentials}),
        isNull,
      );
    });

    test('a development MinIO needs only its endpoint and keys', () {
      final config = exampleStorageConfig(const {
        'DW_STORAGE_ENDPOINT': 'http://127.0.0.1:9000',
        ...credentials,
      })!;
      expect(config.publicBucket, 'club-public');
      expect(config.privateBucket, 'club-private');
      expect(
        config.publicBaseUrl,
        Uri.parse('http://127.0.0.1:9000/club-public'),
      );
      expect(config.verifyBuckets, isTrue);
    });

    test('what the environment names wins over every default', () {
      final config = exampleStorageConfig(const {
        'DW_STORAGE_ENDPOINT': 'https://storage.yandexcloud.net',
        'DW_STORAGE_PUBLIC_BUCKET': 'club-files',
        'DW_STORAGE_PUBLIC_BASE_URL': 'https://cdn.club.example',
        'DW_STORAGE_PRIVATE_BUCKET': 'club-documents',
        'DW_STORAGE_VERIFY_BUCKETS': 'false',
        ...credentials,
      })!;
      expect(config.publicBucket, 'club-files');
      expect(config.publicBaseUrl, Uri.parse('https://cdn.club.example'));
      expect(config.privateBucket, 'club-documents');
      expect(config.verifyBuckets, isFalse);
    });
  });

  group('on real storage', () {
    late DwTestStorage storage;
    late ClubHarness club;

    setUpAll(() async {
      storage = await DwTestStorage.create(prefix: 'club-test');
      club = await ClubHarness.start(storage: storage.config);
    });
    tearDownAll(() async {
      await club.stop();
      await storage.drop();
    });

    test('an avatar lands in the public bucket and opens for anyone by its '
        'URL', () async {
      final vera = await club.member('+7 999 000-00-90', 'Vera');
      final photo = Uint8List.fromList(List.generate(128, (i) => i));
      final uploaded = await vera.client.files.upload(
        ExampleUpload.avatar,
        DwUploadSource.bytes(photo),
        fileName: 'vera.png',
        contentType: 'image/png',
      );
      final file = uploaded.valueOrThrow;
      expect(
        file.url,
        startsWith('${storage.config.publicBaseUrl}/avatar/${vera.accountId}/'),
      );

      final key = Uri.parse(
        file.url!,
      ).pathSegments.skip(1).map(Uri.decodeComponent).join('/');
      expect(await storage.keys(storage.publicBucket), contains(key));
      expect(await storage.keys(storage.privateBucket), isNot(contains(key)));

      final http = HttpClient();
      addTearDown(() => http.close(force: true));
      final response = await (await http.getUrl(Uri.parse(file.url!))).close();
      expect(response.statusCode, 200, reason: 'no credentials were sent');
      expect(await response.expand((chunk) => chunk).toList(), photo);
    });

    test('a private purpose needs nothing but its rule: the server starts on '
        'the same buckets with it', () async {
      final server = await DwTestServer.start(
        DwAppServer(
          // Nothing but the storage: the calls are the club server's.
          protocol: DwWireProtocol(const []),
          migrations: appMigrations,
          database: club.database.config,
          auth: exampleAuth,
          handlers: const [],
          files: DwFileStorage(
            storage.config,
            // The club's own rules hold a private purpose (chat
            // attachments), and nothing else is needed for it.
            rules: exampleUploadRules,
          ),
        ),
      );
      await server.stop();
    });

    test('an avatar of a type the rule does not take is refused before '
        'storage sees it', () async {
      final ivan = await club.member('+7 999 000-00-91', 'Ivan');
      final uploaded = await ivan.client.files.upload(
        ExampleUpload.avatar,
        DwUploadSource.bytes(Uint8List(16)),
        fileName: 'ivan.gif',
        contentType: 'image/gif',
      );
      expect(uploaded.valueOrNull, isNull);
      for (final bucket in [storage.publicBucket, storage.privateBucket]) {
        expect(
          await storage.keys(bucket),
          everyElement(isNot(contains('/${ivan.accountId}/'))),
        );
      }
    });
  });
}
