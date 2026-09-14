import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:test/test.dart';

import 'support/files.dart';
import 'support/test_app.dart';

/// The file storage declaration: checked at startup, before anything opens,
/// and read from the environment. No storage needed.
void main() {
  final app = TestApp();
  const unused = DwDatabaseConfig(
    host: '127.0.0.1',
    port: 1,
    name: 'never_opened',
    user: 'nobody',
    password: '',
    ssl: false,
  );
  final config = DwFileStorageConfig(
    endpoint: Uri.parse('http://127.0.0.1:1'),
    bucket: 'uploads',
    accessKey: 'key',
    secretKey: 'secret',
    publicBaseUrl: Uri.parse('https://cdn.example.com/files'),
  );

  Future<List<String>> problems(
    DwFileStorage files, {
    List<DwCallHandler> extraHandlers = const [],
  }) async {
    try {
      await DwTestServer.start(
        app.server(
          unused,
          protocol: filesProtocol,
          handlers: [...app.handlers(), ...fileHandlers(), ...extraHandlers],
          files: files,
        ),
      );
    } on DwStartupException catch (error) {
      return error.problems;
    }
    fail('the server started');
  }

  DwUploadRule rule(
    DwUploadPurpose purpose, {
    DwFileVisibility visibility = DwFileVisibility.private,
  }) => DwUploadRule(
    purpose,
    visibility: visibility,
    maxBytes: 10,
    contentTypes: {'image/png'},
    canUpload: (ctx) async => true,
  );

  test('every problem of the declaration is reported at once', () async {
    final found = await problems(
      DwFileStorage(
        DwFileStorageConfig(
          endpoint: Uri.parse('ftp://storage.example.com/path'),
          bucket: 'Not_A_Bucket',
          accessKey: '',
          secretKey: 'secret',
        ),
        rules: [
          rule(TestUpload.avatar, visibility: DwFileVisibility.public),
          rule(TestUpload.document),
          rule(TestUpload.document),
          rule(_OddPurpose.$weird),
        ],
        ticketLifetime: const Duration(days: 8),
        linkLifetime: Duration.zero,
        uploadGrace: const Duration(seconds: -1),
        maxPendingUploads: 0,
        cleanupInterval: Duration.zero,
      ),
      extraHandlers: [
        DwCallHandler.command<DwStartUpload, DwUploadTicket>(
          access: DwAccessRule.signedIn,
          handle: (ctx, command) async => throw UnimplementedError(),
        ),
      ],
    );
    expect(found, [
      'DwStartUpload has a built-in handler and cannot have another',
      contains('endpoint ftp://storage.example.com/path'),
      contains('bucket "Not_A_Bucket"'),
      contains('access key and secret key'),
      contains('"avatar" is public, and the file storage has no publicBaseUrl'),
      'upload purpose "document" has more than one rule',
      contains(r'upload purpose "$weird" must be an identifier'),
      contains('ticketLifetime'),
      contains('linkLifetime'),
      contains('uploadGrace'),
      contains('maxPendingUploads'),
      contains('cleanupInterval'),
    ]);
  });

  test('a rule is checked where it is declared', () {
    expect(
      () => DwUploadRule(
        TestUpload.avatar,
        visibility: DwFileVisibility.public,
        maxBytes: 0,
        contentTypes: {'image/png'},
        canUpload: (ctx) async => true,
      ),
      throwsArgumentError,
    );
    for (final types in [
      <String>{},
      {'image/PNG'},
      {'image/png; q=1'},
      {'png'},
    ]) {
      expect(
        () => DwUploadRule(
          TestUpload.avatar,
          visibility: DwFileVisibility.public,
          maxBytes: 1,
          contentTypes: types,
          canUpload: (ctx) async => true,
        ),
        throwsArgumentError,
        reason: '$types',
      );
    }
  });

  group('configuration from the environment', () {
    test('reads every key under the prefix', () {
      final read = DwFileStorageConfig.fromEnvironment({
        'APP_S3_ENDPOINT': 'https://storage.yandexcloud.net',
        'APP_S3_REGION': 'ru-central1',
        'APP_S3_BUCKET': 'molodey-files',
        'APP_S3_ACCESS_KEY': 'id',
        'APP_S3_SECRET_KEY': 'secret',
        'APP_S3_PUBLIC_BASE_URL': 'https://cdn.molodey.example/',
        'APP_S3_PATH_STYLE': 'false',
      }, prefix: 'APP_S3_');
      expect(read.endpoint, Uri.parse('https://storage.yandexcloud.net'));
      expect(read.region, 'ru-central1');
      expect(read.bucket, 'molodey-files');
      expect(read.publicBaseUrl, Uri.parse('https://cdn.molodey.example/'));
      expect(read.pathStyle, isFalse);
      expect(read.problems, isEmpty);
      expect('$read', isNot(contains('secret')));
    });

    test('defaults the region and path style, and reports every missing or '
        'malformed key at once', () {
      final defaults = DwFileStorageConfig.fromEnvironment({
        'DW_STORAGE_ENDPOINT': 'http://127.0.0.1:9000',
        'DW_STORAGE_BUCKET': 'b-1',
        'DW_STORAGE_ACCESS_KEY': 'id',
        'DW_STORAGE_SECRET_KEY': 'secret',
      });
      expect(defaults.region, 'us-east-1');
      expect(defaults.pathStyle, isTrue);
      expect(defaults.publicBaseUrl, isNull);

      expect(
        () => DwFileStorageConfig.fromEnvironment({
          'DW_STORAGE_ENDPOINT': 'storage',
          'DW_STORAGE_PATH_STYLE': 'yes',
        }),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('DW_STORAGE_ENDPOINT must be an http or https URL'),
              contains('DW_STORAGE_BUCKET is not set'),
              contains('DW_STORAGE_ACCESS_KEY is not set'),
              contains('DW_STORAGE_SECRET_KEY is not set'),
              contains('DW_STORAGE_PATH_STYLE must be "true" or "false"'),
            ),
          ),
        ),
      );
    });
  });

  test('a valid declaration has no problems', () {
    expect(
      DwFileStorage(
        config,
        rules: [rule(TestUpload.avatar, visibility: DwFileVisibility.public)],
      ).problems,
      isEmpty,
    );
  });

  group('a server without file storage', () {
    final harness = useHarness(
      build: (app, config) => app.server(
        config,
        protocol: filesProtocol,
        handlers: [...app.handlers(), ...fileHandlers()],
      ),
    );

    test('answers file calls as incidents, and ctx.files throws', () async {
      final (caller, _) = await harness().signedIn('no-files@example.com');
      final start = DwStartUpload(
        purpose: TestUpload.avatar,
        fileName: 'a.png',
        contentType: 'image/png',
        byteSize: 1,
      );
      expect((await caller.call(start)).status, 500);
      expect(
        (await caller.call(const DwFinishUpload(ticketId: 1))).status,
        500,
      );
      expect((await caller.call(const DwGetFileLink(fileId: 1))).status, 500);
      expect((await caller.call(const SetAvatar(1))).status, 500);
      final incidents = harness().app.alerts.incidents;
      expect(incidents, hasLength(4));
      expect(
        incidents.map((incident) => '${incident.error}'),
        everyElement(contains('without file storage')),
      );
    });
  });
}

enum _OddPurpose with DwUploadPurpose { $weird }
