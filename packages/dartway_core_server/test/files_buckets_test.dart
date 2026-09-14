import 'dart:convert';
import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/src/files/dw_object_store.dart';
import 'package:test/test.dart';

import 'support/files.dart';
import 'support/test_app.dart';

/// The two buckets against a real S3-compatible storage: provisioning, what
/// anyone without keys can read from each, the startup check that refuses a
/// bucket more or less public than declared, and private links that expire.
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

  /// Every bucket a test here creates, removed after the file.
  final created = <String>{};
  late DwObjectStore admin;
  setUpAll(() {
    admin = DwObjectStore(
      storageConfig(),
      requestTimeout: const Duration(seconds: 10),
    );
  });
  tearDownAll(() async {
    await TestStorage.dropBuckets(admin, created);
    admin.close();
  });

  DwFileStorageConfig fresh({bool verifyBuckets = true}) {
    final config = storageConfig(
      publicBucket: testBucketName('pub'),
      privateBucket: testBucketName('prv'),
      verifyBuckets: verifyBuckets,
    );
    created.addAll([config.publicBucket!, config.privateBucket!]);
    return config;
  }

  Future<void> createBare(String bucket) async {
    created.add(bucket);
    await TestStorage.expectOk(
      await admin.send('PUT', bucket: bucket),
      'create $bucket',
    );
  }

  Future<void> setPolicy(String bucket, List<String> actions) async {
    await TestStorage.expectOk(
      await admin.send(
        'PUT',
        bucket: bucket,
        query: [('policy', '')],
        body: utf8.encode(
          jsonEncode({
            'Version': '2012-10-17',
            'Statement': [
              for (final action in actions)
                {
                  'Effect': 'Allow',
                  'Principal': {
                    'AWS': ['*'],
                  },
                  'Action': [action],
                  'Resource': [
                    action == 's3:ListBucket'
                        ? 'arn:aws:s3:::$bucket'
                        : 'arn:aws:s3:::$bucket/*',
                  ],
                },
            ],
          }),
        ),
        headers: {'content-type': 'application/json'},
      ),
      'set the policy of $bucket',
    );
  }

  Future<void> put(String bucket, String key, String text) async {
    await TestStorage.expectOk(
      await admin.send(
        'PUT',
        bucket: bucket,
        key: key,
        body: utf8.encode(text),
        headers: {'content-type': 'text/plain'},
      ),
      'put $key',
    );
  }

  /// What someone without keys gets for [key] in [bucket], and for the
  /// bucket's listing.
  Future<({int object, int listing})> anonymous(
    String bucket,
    String key,
  ) async => (
    object: (await getUrl('${admin.urlOf(bucket, key: key)}')).status,
    listing: (await getUrl(
      '${admin.urlOf(bucket, query: [('list-type', '2')])}',
    )).status,
  );

  DwFileStorage declaration(DwFileStorageConfig config) => DwFileStorage(
    config,
    rules: [
      DwUploadRule(
        TestUpload.avatar,
        visibility: DwFileVisibility.public,
        maxBytes: 64,
        contentTypes: {'image/png'},
        canUpload: (ctx) async => true,
      ),
      DwUploadRule(
        TestUpload.document,
        visibility: DwFileVisibility.private,
        maxBytes: 64,
        contentTypes: {'text/plain'},
        canUpload: (ctx) async => true,
      ),
    ],
  );

  /// The problems the server refuses to start with; fails if it starts, or
  /// gets as far as opening the database.
  Future<List<String>> refusal(DwFileStorageConfig config) async {
    try {
      await DwTestServer.start(
        app.server(
          unused,
          protocol: filesProtocol,
          handlers: [...app.handlers(), ...fileHandlers()],
          files: declaration(config),
        ),
      );
    } on DwStartupException catch (error) {
      return error.problems;
    }
    fail('the server started');
  }

  group('provisioning', () {
    test('creates both buckets: the public one reads its objects to anyone '
        'and lists to no one, the private one does neither', () async {
      final config = fresh();
      await DwFileStorageSetup.provision(config);
      await put(config.publicBucket!, 'avatar/1/a.png', 'public');
      await put(config.privateBucket!, 'document/1/a.pdf', 'private');

      final public = await anonymous(config.publicBucket!, 'avatar/1/a.png');
      expect(public.object, 200);
      expect(public.listing, 403);
      expect(
        (await getUrl('${config.publicUrlOf('avatar/1/a.png')}')).bytes,
        utf8.encode('public'),
      );
      final private = await anonymous(
        config.privateBucket!,
        'document/1/a.pdf',
      );
      expect(private.object, 403);
      expect(private.listing, 403);
    });

    test(
      'is idempotent: a second run keeps the objects and the access',
      () async {
        final config = fresh();
        await DwFileStorageSetup.provision(config);
        await put(config.publicBucket!, 'avatar/1/a.png', 'kept');
        await put(config.privateBucket!, 'document/1/a.pdf', 'kept');
        await DwFileStorageSetup.provision(config);
        await DwFileStorageSetup.provision(config);

        expect(await TestStorage.keysIn(admin, config.publicBucket!), [
          'avatar/1/a.png',
        ]);
        expect(await TestStorage.keysIn(admin, config.privateBucket!), [
          'document/1/a.pdf',
        ]);
        expect(
          (await anonymous(config.publicBucket!, 'avatar/1/a.png')).object,
          200,
        );
        expect(
          (await anonymous(config.privateBucket!, 'document/1/a.pdf')).object,
          403,
        );
      },
    );

    test('takes the anonymous access away from a private bucket that had it, '
        'and the listing from a public one', () async {
      final config = fresh();
      await createBare(config.publicBucket!);
      await createBare(config.privateBucket!);
      await setPolicy(config.publicBucket!, ['s3:GetObject', 's3:ListBucket']);
      await setPolicy(config.privateBucket!, ['s3:GetObject']);
      await put(config.publicBucket!, 'avatar/1/a.png', 'x');
      await put(config.privateBucket!, 'document/1/a.pdf', 'x');
      expect(await anonymous(config.publicBucket!, 'avatar/1/a.png'), (
        object: 200,
        listing: 200,
      ));
      expect(
        (await anonymous(config.privateBucket!, 'document/1/a.pdf')).object,
        200,
      );

      await DwFileStorageSetup.provision(config);
      expect(await anonymous(config.publicBucket!, 'avatar/1/a.png'), (
        object: 200,
        listing: 403,
      ));
      expect(await anonymous(config.privateBucket!, 'document/1/a.pdf'), (
        object: 403,
        listing: 403,
      ));
    });

    test('provisions a storage of private files alone', () async {
      final bucket = testBucketName('prv');
      created.add(bucket);
      await DwFileStorageSetup.provision(storageConfig(privateBucket: bucket));
      expect(await TestStorage.keysIn(admin, bucket), isEmpty);
    });

    test('DwTestStorage gives a test a provisioned pair and takes it away, '
        'objects and all', () async {
      final storage = await DwTestStorage.create(prefix: 'dw-helper');
      final config = storage.config;
      expect(config.publicBucket, startsWith('dw-helper-pub-'));
      expect(config.privateBucket, startsWith('dw-helper-prv-'));
      expect(config.verifyBuckets, isTrue);
      expect(config.problems, isEmpty);
      created.addAll([storage.publicBucket, storage.privateBucket]);
      await put(storage.publicBucket, 'avatar/1/a.png', 'public');
      await put(storage.privateBucket, 'document/1/a.pdf', 'private');
      expect(
        (await getUrl('${config.publicUrlOf('avatar/1/a.png')}')).status,
        200,
      );
      expect(
        (await anonymous(storage.privateBucket, 'document/1/a.pdf')).object,
        403,
      );
      expect(await storage.keys(storage.privateBucket), ['document/1/a.pdf']);

      await storage.drop();
      for (final bucket in [storage.publicBucket, storage.privateBucket]) {
        final head = await admin.send('HEAD', bucket: bucket);
        await head.drain<void>();
        expect(head.statusCode, 404, reason: '$bucket is gone');
      }
      expect(
        () => DwTestStorage.create(environment: const {}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('DW_STORAGE_ENDPOINT'),
          ),
        ),
      );
    });

    test('refuses a configuration with problems before touching storage', () {
      expect(
        () => DwFileStorageSetup.provision(
          storageConfig(
            publicBucket: 'same-bucket',
            privateBucket: 'same-bucket',
          ),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => '${e.message}',
            'message',
            contains('both "same-bucket"'),
          ),
        ),
      );
    });
  });

  group('the startup check', () {
    test('passes provisioned buckets, and the server serves', () async {
      final config = fresh();
      await DwFileStorageSetup.provision(config);
      final database = await DwTestDatabase.create(
        admin: adminConfig(),
        prefix: 'files_buckets',
      );
      addTearDown(database.drop);
      final lines = RecordingLogger.lines.length;
      final server = await DwTestServer.start(
        app.server(
          database.config,
          protocol: filesProtocol,
          handlers: [...app.handlers(), ...fileHandlers()],
          files: declaration(config),
        ),
      );
      await server.stop();
      expect(
        RecordingLogger.lines.skip(lines),
        contains(
          contains(
            'file storage buckets verified: public "${config.publicBucket}" '
            'reads anonymously, private "${config.privateBucket}" does not',
          ),
        ),
      );
      // The probe is the one object the check leaves, one per bucket.
      for (final bucket in [config.publicBucket!, config.privateBucket!]) {
        expect(await TestStorage.keysIn(admin, bucket), [
          '_dartway/visibility-probe',
        ]);
      }
    });

    test('refuses buckets that do not exist', () async {
      final config = fresh();
      expect(await refusal(config), [
        'file storage public bucket "${config.publicBucket}" does not exist '
            'at ${config.endpoint}',
        'file storage private bucket "${config.privateBucket}" does not exist '
            'at ${config.endpoint}',
      ]);
    });

    test('refuses a public bucket nobody can read and a private bucket '
        'everybody can, both at once', () async {
      final config = fresh();
      await createBare(config.publicBucket!);
      await createBare(config.privateBucket!);
      await setPolicy(config.privateBucket!, ['s3:GetObject']);
      final problems = await refusal(config);
      expect(problems, [
        allOf(
          startsWith(
            'file storage public bucket "${config.publicBucket}" is not '
            'readable anonymously: GET ${config.publicUrlOf('_dartway/visibility-probe')} '
            'without credentials answered 403',
          ),
          contains('DwFileStorageSetup.provision'),
        ),
        startsWith(
          'file storage private bucket "${config.privateBucket}" is readable '
          'anonymously',
        ),
      ]);
    });

    test('refuses a private bucket that is public while the public one is '
        'right', () async {
      final config = fresh();
      await DwFileStorageSetup.provision(config);
      await setPolicy(config.privateBucket!, ['s3:GetObject']);
      expect(await refusal(config), [
        allOf(
          contains(
            'private bucket "${config.privateBucket}" is readable anonymously',
          ),
          contains('every private file in it is public'),
        ),
      ]);
    });

    test('refuses a bucket anyone can list, public or private', () async {
      final config = fresh();
      await DwFileStorageSetup.provision(config);
      await setPolicy(config.publicBucket!, ['s3:GetObject', 's3:ListBucket']);
      await setPolicy(config.privateBucket!, ['s3:ListBucket']);
      expect(await refusal(config), [
        contains(
          'public bucket "${config.publicBucket}" lets anyone list its keys',
        ),
        contains(
          'private bucket "${config.privateBucket}" lets anyone list its keys',
        ),
      ]);
    });

    test('refuses keys the storage does not accept', () async {
      final config = fresh();
      await DwFileStorageSetup.provision(config);
      final wrong = DwFileStorageConfig(
        endpoint: config.endpoint,
        accessKey: config.accessKey,
        secretKey: 'not-the-secret',
        publicBucket: config.publicBucket,
        publicBaseUrl: config.publicBaseUrl,
        privateBucket: config.privateBucket,
      );
      expect(await refusal(wrong), [
        contains('"${config.publicBucket}" refuses the configured keys'),
        contains('"${config.privateBucket}" refuses the configured keys'),
      ]);
    });

    test('refuses a storage it cannot reach, naming the switch', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close();
      final config = DwFileStorageConfig(
        endpoint: Uri.parse('http://127.0.0.1:$port'),
        accessKey: 'key',
        secretKey: 'secret',
        publicBucket: 'nowhere-public',
        publicBaseUrl: Uri.parse('http://127.0.0.1:$port/nowhere-public'),
        privateBucket: 'nowhere-private',
      );
      final problems = await refusal(config);
      expect(problems, hasLength(2));
      expect(
        problems,
        everyElement(
          allOf(
            contains('could not be checked at http://127.0.0.1:$port'),
            contains('DW_STORAGE_VERIFY_BUCKETS=false'),
          ),
        ),
      );
    });

    test('is not run when turned off: the server starts on buckets it would '
        'refuse', () async {
      final config = fresh(verifyBuckets: false);
      final database = await DwTestDatabase.create(
        admin: adminConfig(),
        prefix: 'files_buckets',
      );
      addTearDown(database.drop);
      final server = await DwTestServer.start(
        app.server(
          database.config,
          protocol: filesProtocol,
          handlers: [...app.handlers(), ...fileHandlers()],
          files: declaration(config),
        ),
      );
      await server.stop();
      for (final bucket in [config.publicBucket!, config.privateBucket!]) {
        final head = await admin.send('HEAD', bucket: bucket);
        await head.drain<void>();
        expect(head.statusCode, 404, reason: 'nothing touched storage');
      }
    });
  });

  group('a private link', () {
    late TestStorage storage;
    setUpAll(() async => storage = await TestStorage.create());
    tearDownAll(() async => storage.drop());
    final harness = useFilesHarness(
      () => storage,
      declaration: (config) =>
          testStorage(config, linkLifetime: const Duration(seconds: 2)),
    );

    test('reads the object until it expires, and nothing after', () async {
      final (alice, _) = await harness().signedIn('links-alice@example.com');
      final body = utf8.encode('short-lived');
      final start = DwStartUpload(
        purpose: TestUpload.document,
        fileName: 'note.txt',
        contentType: 'text/plain',
        byteSize: 11,
      );
      final ticket = (await alice.call(start)).value(start);
      expect((await putToTicket(ticket, body)).status, 200);
      final finish = DwFinishUpload(ticketId: ticket.id);
      final file = (await alice.call(finish)).value(finish);

      final request = DwGetFileLink(fileId: file.id);
      final link = (await alice.call(request)).value(request);
      expect(link.expiresAt!.difference(DateTime.now()).inSeconds, lessThan(3));
      final read = await getUrl(link.url);
      expect(read.status, 200);
      expect(read.bytes, body);

      await Future<void>.delayed(
        link.expiresAt!.difference(DateTime.now()) + const Duration(seconds: 2),
      );
      final expired = await getUrl(link.url);
      expect(expired.status, 403, reason: 'the link has expired');
      expect(utf8.decode(expired.bytes), contains('expired'));

      // A new link reads it again: the file is there, the old URL is not.
      final again = (await alice.call(request)).value(request);
      expect((await getUrl(again.url)).bytes, body);
    });
  });
}
