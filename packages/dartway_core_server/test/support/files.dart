// File uploads in the server suites: a real S3-compatible storage (MinIO in
// development), a bucket per test file, and a small project on top of
// `ctx.files`.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_core_server/src/files/dw_object_store.dart';

import 'test_app.dart';

/// The purposes of the test project.
enum TestUpload with DwUploadPurpose { avatar, document, locked, unruled }

/// The storage the suites run against: `DW_STORAGE_ENDPOINT`,
/// `DW_STORAGE_ACCESS_KEY` and `DW_STORAGE_SECRET_KEY` (and optionally
/// `DW_STORAGE_REGION`) from the environment, with a bucket of [bucket]'s
/// name. A missing variable fails the suite loudly, as the database does.
///
/// ```
/// docker run -d --name dw10-minio -p 127.0.0.1:55470:9000 \
///   -e MINIO_ROOT_USER=dartway -e MINIO_ROOT_PASSWORD=dartway-secret \
///   minio/minio server /data
/// DW_STORAGE_ENDPOINT=http://127.0.0.1:55470 DW_STORAGE_ACCESS_KEY=dartway \
///   DW_STORAGE_SECRET_KEY=dartway-secret dart test
/// ```
DwFileStorageConfig storageConfig(String bucket, {bool public = true}) {
  final environment = {...Platform.environment, 'DW_STORAGE_BUCKET': bucket};
  try {
    final config = DwFileStorageConfig.fromEnvironment(environment);
    return DwFileStorageConfig(
      endpoint: config.endpoint,
      region: config.region,
      bucket: bucket,
      accessKey: config.accessKey,
      secretKey: config.secretKey,
      pathStyle: true,
      // The bucket itself, with anonymous reads allowed for `avatar/` by the
      // policy [TestBucket.create] sets: the smallest real "public prefix".
      publicBaseUrl: public ? config.endpoint.replace(path: '/$bucket') : null,
    );
  } on ArgumentError catch (error) {
    throw StateError(
      'The file suites need an S3-compatible storage: set '
      'DW_STORAGE_ENDPOINT, DW_STORAGE_ACCESS_KEY and DW_STORAGE_SECRET_KEY '
      '(${error.message})',
    );
  }
}

/// A bucket created for one test file and removed, objects and all, after it.
final class TestBucket {
  TestBucket._(this.config, this.store);

  final DwFileStorageConfig config;

  /// The framework's own client of the bucket, with the server's keys: for
  /// looking at objects the way the server does.
  final DwObjectStore store;

  static Future<TestBucket> create() async {
    final random = Random.secure();
    final name =
        'dw-test-${List.generate(12, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[random.nextInt(36)]).join()}';
    final config = storageConfig(name);
    final store = DwObjectStore(
      config,
      requestTimeout: const Duration(seconds: 10),
    );
    await _expectOk(await store.send('PUT'), 'create bucket $name');
    final policy = jsonEncode({
      'Version': '2012-10-17',
      'Statement': [
        {
          'Effect': 'Allow',
          'Principal': {
            'AWS': ['*'],
          },
          'Action': ['s3:GetObject'],
          'Resource': ['arn:aws:s3:::$name/${TestUpload.avatar.name}/*'],
        },
      ],
    });
    await _expectOk(
      await store.send(
        'PUT',
        query: [('policy', '')],
        body: utf8.encode(policy),
        headers: {'content-type': 'application/json'},
      ),
      'set the bucket policy',
    );
    return TestBucket._(config, store);
  }

  static Future<void> _expectOk(
    HttpClientResponse response,
    String what,
  ) async {
    final body = await utf8.decodeStream(response);
    if (response.statusCode >= 300) {
      throw StateError('could not $what: ${response.statusCode} $body');
    }
  }

  /// Every key in the bucket.
  Future<List<String>> keys() async {
    final response = await store.send('GET', query: [('list-type', '2')]);
    final body = await utf8.decodeStream(response);
    return [
      for (final match in RegExp(r'<Key>([^<]+)</Key>').allMatches(body))
        match.group(1)!,
    ];
  }

  /// Puts an object with the server's keys, around every ticket.
  Future<void> putDirectly(String key, List<int> bytes, String type) async {
    await _expectOk(
      await store.send(
        'PUT',
        key: key,
        body: bytes,
        headers: {'content-type': type},
      ),
      'put $key',
    );
  }

  Future<void> drop() async {
    for (final key in await keys()) {
      await store.delete(key);
    }
    await (await store.send('DELETE')).drain<void>();
    store.close();
  }
}

/// The storage declaration of the test project.
DwFileStorage testStorage(
  DwFileStorageConfig config, {
  Future<bool> Function(DwCallContext ctx, DwFileRecord file)? canRead,
  int maxPendingUploads = 50,
  Duration ticketLifetime = const Duration(minutes: 5),
  Duration uploadGrace = const Duration(minutes: 5),
  Duration cleanupInterval = const Duration(minutes: 10),
}) => DwFileStorage(
  config,
  rules: [
    DwUploadRule(
      TestUpload.avatar,
      visibility: DwFileVisibility.public,
      maxBytes: 64,
      contentTypes: {'image/png', 'image/jpeg'},
      canUpload: (ctx) async => true,
    ),
    DwUploadRule(
      TestUpload.document,
      visibility: DwFileVisibility.private,
      maxBytes: 1 << 20,
      contentTypes: {'application/pdf', 'text/plain'},
      canUpload: (ctx) async => true,
    ),
    DwUploadRule(
      TestUpload.locked,
      visibility: DwFileVisibility.private,
      maxBytes: 64,
      contentTypes: {'text/plain'},
      canUpload: (ctx) async => false,
    ),
  ],
  canRead: canRead,
  maxPendingUploads: maxPendingUploads,
  ticketLifetime: ticketLifetime,
  uploadGrace: uploadGrace,
  cleanupInterval: cleanupInterval,
);

/// Sends [bytes] to a ticket's URL as a client would: exactly the ticket's
/// headers, the length of the body. [headers] overrides them, a `null`
/// value leaving one out.
Future<({int status, String body})> putToTicket(
  DwUploadTicket ticket,
  List<int> bytes, {
  Map<String, String?> headers = const {},
  int? contentLength,
}) async {
  final client = HttpClient();
  try {
    final request = await client.putUrl(Uri.parse(ticket.uploadUrl));
    for (final MapEntry(:key, :value) in {
      ...ticket.headers,
      ...headers,
    }.entries) {
      if (value != null) request.headers.set(key, value);
    }
    request.contentLength = contentLength ?? bytes.length;
    request.add(bytes);
    final response = await request.close();
    return (
      status: response.statusCode,
      body: await utf8.decodeStream(response),
    );
  } finally {
    client.close(force: true);
  }
}

/// A GET without credentials.
Future<({int status, List<int> bytes, HttpHeaders headers})> getUrl(
  String url,
) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(Uri.parse(url))).close();
    final bytes = await response.fold<List<int>>(
      [],
      (all, chunk) => all..addAll(chunk),
    );
    return (
      status: response.statusCode,
      bytes: bytes,
      headers: response.headers,
    );
  } finally {
    client.close(force: true);
  }
}

// --- the project's own calls on top of ctx.files ------------------------------

/// Sets the caller's avatar: a row referencing a file id, checked.
final class SetAvatar extends DwActionCommand<DwStoredFile> {
  const SetAvatar(this.fileId);

  final int fileId;

  @override
  String get dwTypeName => 'SetAvatar';

  @override
  Map<String, Object?> toJson() => {'fileId': fileId};

  static SetAvatar fromJson(Map<String, Object?> json) =>
      SetAvatar(json['fileId']! as int);
}

/// Deletes a file through `ctx.files.delete`.
final class DropFile extends DwActionCommand<bool> {
  const DropFile(this.fileId, {this.refuse = false});

  final int fileId;

  /// Refuse after deleting: the transaction rolls back, and the object must
  /// stay.
  final bool refuse;

  @override
  String get dwTypeName => 'DropFile';

  @override
  Map<String, Object?> toJson() => {
    'fileId': fileId,
    if (refuse) 'refuse': true,
  };

  static DropFile fromJson(Map<String, Object?> json) =>
      DropFile(json['fileId']! as int, refuse: json['refuse'] == true);
}

/// Resolves public URLs through `ctx.files.publicUrls`.
final class ResolveUrls extends DwActionCommand<FileUrls> {
  const ResolveUrls(this.fileIds);

  final List<int> fileIds;

  @override
  String get dwTypeName => 'ResolveUrls';

  @override
  Map<String, Object?> toJson() => {'fileIds': fileIds};

  static ResolveUrls fromJson(Map<String, Object?> json) => ResolveUrls([
    for (final id in json['fileIds']! as List<Object?>) id! as int,
  ]);
}

/// Deletes a file from a read, which must not be allowed.
final class DropFromRead extends DwListRequest<NoteView> {
  const DropFromRead(this.fileId);

  final int fileId;

  @override
  String get dwTypeName => 'DropFromRead';

  @override
  Map<String, Object?> toJson() => {'fileId': fileId};

  static DropFromRead fromJson(Map<String, Object?> json) =>
      DropFromRead(json['fileId']! as int);
}

final class FileUrls extends DwWireObject {
  const FileUrls(this.urls);

  final Map<String, String> urls;

  @override
  String get dwTypeName => 'FileUrls';

  @override
  Map<String, Object?> toJson() => {'urls': urls};

  static FileUrls fromJson(Map<String, Object?> json) =>
      FileUrls((json['urls']! as Map<String, Object?>).cast<String, String>());
}

final DwWireProtocol filesProtocol = DwWireProtocol([
  const DwProtocolEntry<SetAvatar>('SetAvatar', SetAvatar.fromJson),
  const DwProtocolEntry<DropFile>('DropFile', DropFile.fromJson),
  const DwProtocolEntry<ResolveUrls>('ResolveUrls', ResolveUrls.fromJson),
  const DwProtocolEntry<DropFromRead>('DropFromRead', DropFromRead.fromJson),
  const DwProtocolEntry<FileUrls>('FileUrls', FileUrls.fromJson),
], include: testProtocol);

List<DwCallHandler> fileHandlers() => [
  DwCallHandler.command<SetAvatar, DwStoredFile>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) => ctx.files.requireOwned(
      command.fileId,
      TestUpload.avatar,
      field: 'fileId',
    ),
  ),
  DwCallHandler.command<DropFile, bool>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      final deleted = await ctx.files.delete(command.fileId);
      if (command.refuse) ctx.refuse(DwCoreRefusal.conflict);
      return deleted;
    },
  ),
  DwCallHandler.command<ResolveUrls, FileUrls>(
    access: DwAccessRule.anonymous,
    handle: (ctx, command) async => FileUrls({
      for (final MapEntry(:key, :value) in (await ctx.files.publicUrls(
        command.fileIds,
      )).entries)
        '$key': value,
    }),
  ),
  DwCallHandler.list<DropFromRead, NoteView>(
    access: DwAccessRule.anonymous,
    handle: (ctx, request) async {
      await ctx.files.delete(request.fileId);
      return const [];
    },
  ),
];

/// A harness with file storage on [bucket]'s storage.
Harness Function() useFilesHarness(
  TestBucket Function() bucket, {
  DwFileStorage Function(DwFileStorageConfig config)? storage,
  DwServerSettings settings = const DwServerSettings(
    jobPollInterval: Duration(seconds: 30),
  ),
}) => useHarness(
  build: (app, config) => app.server(
    config,
    protocol: filesProtocol,
    handlers: [...app.handlers(), ...fileHandlers()],
    files: (storage ?? testStorage)(bucket().config),
    settings: settings,
  ),
);

/// A PNG-ish body of [size] bytes.
List<int> bytesOf(int size, [int seed = 7]) =>
    List.generate(size, (i) => (i * 31 + seed) & 0xff);
