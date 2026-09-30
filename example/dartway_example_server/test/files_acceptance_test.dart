import 'dart:io';
import 'dart:typed_data';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/testing.dart';
import 'package:dartway_example_server/dartway_example_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:test/test.dart';

import 'support/app_harness.dart';

/// The club's uploads on real storage: a member's avatar goes to the public
/// bucket and opens for anyone by its URL. Needs `DW_STORAGE_ENDPOINT`,
/// `DW_STORAGE_ACCESS_KEY` and `DW_STORAGE_SECRET_KEY` besides the database
/// (see `../README.md`).
void main() {
  group('configuration from the environment', () {
    const required = {
      'DW_DATABASE_HOST': '127.0.0.1',
      'DW_DATABASE_NAME': 'club',
      'DW_DATABASE_USER': 'club',
      'DW_DATABASE_PASSWORD': 'club',
      'DW_STORAGE_ACCESS_KEY': 'club',
      'DW_STORAGE_SECRET_KEY': 'club-secret',
    };
    DwFileStorageConfig? storageOf(Map<String, String> variables) =>
        AppEnvironment.read({...required, ...variables}).server.storage;

    test('without an endpoint there is no storage', () {
      expect(storageOf(const {}), isNull);
      expect(storageOf(const {'DW_STORAGE_ENDPOINT': ''}), isNull);
    });

    test('a development storage needs only its endpoint and keys', () {
      final config = storageOf(const {
        'DW_STORAGE_ENDPOINT': 'http://127.0.0.1:9000',
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
      final config = storageOf(const {
        'DW_STORAGE_ENDPOINT': 'https://storage.yandexcloud.net',
        'DW_STORAGE_PUBLIC_BUCKET': 'club-files',
        'DW_STORAGE_PUBLIC_BASE_URL': 'https://cdn.club.example',
        'DW_STORAGE_PRIVATE_BUCKET': 'club-documents',
        'DW_STORAGE_VERIFY_BUCKETS': 'false',
      })!;
      expect(config.publicBucket, 'club-files');
      expect(config.publicBaseUrl, Uri.parse('https://cdn.club.example'));
      expect(config.privateBucket, 'club-documents');
      expect(config.verifyBuckets, isFalse);
    });

    test('RuStore push takes both of its variables or neither', () {
      expect(
        () => AppEnvironment.read({
          ...required,
          'RUSTORE_PUSH_PROJECT_ID': 'club',
        }),
        throwsA(
          isA<DwEnvironmentException>().having(
            (e) => e.problems,
            'problems',
            [contains('RUSTORE_PUSH_SERVICE_TOKEN')],
          ),
        ),
      );
      final both = AppEnvironment.read({
        ...required,
        'RUSTORE_PUSH_PROJECT_ID': 'club',
        'RUSTORE_PUSH_SERVICE_TOKEN': 'token',
      });
      expect(both.push.ruStore?.projectId, 'club');
    });
  });

  group('on real storage', () {
    late DwTestStorage storage;
    late AppHarness club;

    setUpAll(() async {
      storage = await DwTestStorage.create(prefix: 'club-test');
      club = await AppHarness.start(storage: storage.config);
    });
    tearDownAll(() async {
      await club.stop();
      await storage.drop();
    });

    test('an avatar lands in the public bucket and opens for anyone by its '
        'URL', () async {
      final vera = await club.signUp('+7 999 000-00-90', firstName: 'Vera');
      final photo = Uint8List.fromList(List.generate(128, (i) => i));
      final uploaded = await vera.client.files.upload(
        DartwayExampleUpload.avatar,
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
          auth: AppAuth.config,
          features: const [],
          files: DwFileStorage(
            storage.config,
            // The club's own rules hold a private purpose (chat
            // attachments), and nothing else is needed for it.
            rules: AppFiles.uploadRules,
          ),
        ),
      );
      await server.stop();
    });

    test('an avatar of a type the rule does not take is refused before '
        'storage sees it', () async {
      final ivan = await club.signUp('+7 999 000-00-91', firstName: 'Ivan');
      final uploaded = await ivan.client.files.upload(
        DartwayExampleUpload.avatar,
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
