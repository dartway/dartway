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
/// `DW_STORAGE_REGION`) from the environment, with a public bucket of
/// [publicBucket]'s name served from itself and a private one of
/// [privateBucket]'s. A missing variable fails the suite loudly, as the
/// database does.
///
/// ```
/// docker run -d --name dw10-minio -p 127.0.0.1:55470:9000 \
///   -e MINIO_ROOT_USER=dartway -e MINIO_ROOT_PASSWORD=dartway-secret \
///   quay.io/minio/minio:RELEASE.2025-09-07T16-13-09Z server /data
/// DW_STORAGE_ENDPOINT=http://127.0.0.1:55470 DW_STORAGE_ACCESS_KEY=dartway \
///   DW_STORAGE_SECRET_KEY=dartway-secret dart test
/// ```
DwFileStorageConfig storageConfig({
  String? publicBucket,
  String? privateBucket,
  bool verifyBuckets = true,
}) {
  try {
    final config = DwFileStorageConfig.fromEnvironment(Platform.environment);
    return DwFileStorageConfig(
      endpoint: config.endpoint,
      region: config.region,
      accessKey: config.accessKey,
      secretKey: config.secretKey,
      pathStyle: true,
      publicBucket: publicBucket,
      // The bucket itself: public objects are served by the storage, path
      // style, as a development MinIO serves them.
      publicBaseUrl: publicBucket == null
          ? null
          : config.endpoint.replace(path: '/$publicBucket'),
      privateBucket: privateBucket,
      verifyBuckets: verifyBuckets,
    );
  } on ArgumentError catch (error) {
    throw StateError(
      'The file suites need an S3-compatible storage: set '
      'DW_STORAGE_ENDPOINT, DW_STORAGE_ACCESS_KEY and DW_STORAGE_SECRET_KEY '
      '(${error.message})',
    );
  }
}

/// A fresh bucket name, unique to one test file.
String testBucketName(String role) {
  final random = Random.secure();
  return 'dw-test-$role-${List.generate(10, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[random.nextInt(36)]).join()}';
}

/// A public and a private bucket for one test file: the framework's
/// [DwTestStorage], with the server's own client of the storage beside it.
final class TestStorage {
  TestStorage._(this._buckets, this.store);

  final DwTestStorage _buckets;

  DwFileStorageConfig get config => _buckets.config;

  /// The framework's own client of the storage, with the server's keys: for
  /// looking at objects the way the server does.
  final DwObjectStore store;

  String get publicBucket => _buckets.publicBucket;
  String get privateBucket => _buckets.privateBucket;

  static Future<TestStorage> create() async {
    final buckets = await DwTestStorage.create();
    return TestStorage._(
      buckets,
      DwObjectStore(
        buckets.config,
        requestTimeout: const Duration(seconds: 10),
      ),
    );
  }

  static Future<void> expectOk(HttpClientResponse response, String what) async {
    final body = await utf8.decodeStream(response);
    if (response.statusCode >= 300) {
      throw StateError('could not $what: ${response.statusCode} $body');
    }
  }

  /// Every key in [bucket].
  Future<List<String>> keys(String bucket) => _buckets.keys(bucket);

  /// Every key in [bucket], as [store] lists them.
  static Future<List<String>> keysIn(DwObjectStore store, String bucket) async {
    final response = await store.send(
      'GET',
      bucket: bucket,
      query: [('list-type', '2')],
    );
    final body = await utf8.decodeStream(response);
    if (response.statusCode != 200) {
      throw StateError('could not list $bucket: ${response.statusCode} $body');
    }
    return [
      for (final match in RegExp(r'<Key>([^<]+)</Key>').allMatches(body))
        match.group(1)!,
    ];
  }

  /// Puts an object into [bucket] with the server's keys, around every
  /// ticket.
  Future<void> putDirectly(
    String bucket,
    String key,
    List<int> bytes,
    String type,
  ) async {
    await expectOk(
      await store.send(
        'PUT',
        bucket: bucket,
        key: key,
        body: bytes,
        headers: {'content-type': type},
      ),
      'put $key',
    );
  }

  Future<void> drop() async {
    store.close();
    await _buckets.drop();
  }

  /// Removes [buckets] with every object in them; an absent one is skipped.
  static Future<void> dropBuckets(
    DwObjectStore store,
    Iterable<String> buckets,
  ) async {
    for (final bucket in buckets) {
      final head = await store.send('HEAD', bucket: bucket);
      await head.drain<void>();
      if (head.statusCode == 404) continue;
      for (final key in await keysIn(store, bucket)) {
        await store.delete(bucket, key);
      }
      await (await store.send('DELETE', bucket: bucket)).drain<void>();
    }
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
  Duration linkLifetime = const Duration(minutes: 10),
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
  linkLifetime: linkLifetime,
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

/// Describes files through `ctx.files.describe`, each as
/// `name|size|type|purpose|url`.
final class DescribeFiles extends DwActionCommand<FileUrls> {
  const DescribeFiles(this.fileIds);

  final List<int> fileIds;

  @override
  String get dwTypeName => 'DescribeFiles';

  @override
  Map<String, Object?> toJson() => {'fileIds': fileIds};

  static DescribeFiles fromJson(Map<String, Object?> json) => DescribeFiles([
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

/// Stores a file the server made through `ctx.files.store`: [size] bytes of
/// `bytesOf`, as [purpose] with [type], owned by the caller.
final class StoreMade extends DwActionCommand<DwStoredFile> {
  const StoreMade({
    required this.purpose,
    required this.size,
    this.type = 'text/plain',
    this.refuse = false,
  });

  final String purpose;
  final int size;
  final String type;

  /// Refuse after storing: the transaction rolls back.
  final bool refuse;

  @override
  String get dwTypeName => 'StoreMade';

  @override
  Map<String, Object?> toJson() => {
    'purpose': purpose,
    'size': size,
    'type': type,
    if (refuse) 'refuse': true,
  };

  static StoreMade fromJson(Map<String, Object?> json) => StoreMade(
    purpose: json['purpose']! as String,
    size: json['size']! as int,
    type: json['type']! as String,
    refuse: json['refuse'] == true,
  );
}

/// Reads a file as the server: its length and a digest of its bytes through
/// `ctx.files.read`, and a link through `ctx.files.readLink`. Answers the
/// caller nothing about files it does not own — the test reads the answer.
final class ReadAsServer extends DwActionCommand<FileUrls> {
  const ReadAsServer(this.fileId);

  final int fileId;

  @override
  String get dwTypeName => 'ReadAsServer';

  @override
  Map<String, Object?> toJson() => {'fileId': fileId};

  static ReadAsServer fromJson(Map<String, Object?> json) =>
      ReadAsServer(json['fileId']! as int);
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
  const DwProtocolEntry<DescribeFiles>('DescribeFiles', DescribeFiles.fromJson),
  const DwProtocolEntry<DropFromRead>('DropFromRead', DropFromRead.fromJson),
  const DwProtocolEntry<FileUrls>('FileUrls', FileUrls.fromJson),
  const DwProtocolEntry<StoreMade>('StoreMade', StoreMade.fromJson),
  const DwProtocolEntry<ReadAsServer>('ReadAsServer', ReadAsServer.fromJson),
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
  DwCallHandler.command<DescribeFiles, FileUrls>(
    access: DwAccessRule.anonymous,
    handle: (ctx, command) async => FileUrls({
      for (final MapEntry(:key, :value) in (await ctx.files.describe(
        command.fileIds,
      )).entries)
        '$key': [
          value.fileName,
          value.byteSize,
          value.contentType,
          value.purpose,
          value.url ?? '',
        ].join('|'),
    }),
  ),
  DwCallHandler.command<StoreMade, DwStoredFile>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      final stored = await ctx.files.store(
        TestUpload.values.byName(command.purpose),
        accountId: ctx.requireAccountId,
        bytes: bytesOf(command.size),
        contentType: command.type,
        fileName: 'made.txt',
      );
      if (command.refuse) ctx.refuse(DwCoreRefusal.conflict);
      return stored;
    },
  ),
  DwCallHandler.command<ReadAsServer, FileUrls>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      final bytes = await ctx.files.read(command.fileId);
      final link = await ctx.files.readLink(command.fileId);
      return FileUrls({
        if (bytes != null) 'length': '${bytes.length}',
        if (bytes != null) 'sum': '${bytes.fold<int>(0, (a, b) => a + b)}',
        if (link != null) 'link': link.url,
      });
    },
  ),
  DwCallHandler.list<DropFromRead, NoteView>(
    access: DwAccessRule.anonymous,
    handle: (ctx, request) async {
      await ctx.files.delete(request.fileId);
      return const [];
    },
  ),
];

/// A harness with file storage on [storage]'s buckets.
Harness Function() useFilesHarness(
  TestStorage Function() storage, {
  DwFileStorage Function(DwFileStorageConfig config)? declaration,
  DwServerSettings settings = const DwServerSettings(
    jobPollInterval: Duration(seconds: 30),
  ),
}) => useHarness(
  build: (app, config) => app.server(
    config,
    protocol: filesProtocol,
    handlers: [...app.handlers(), ...fileHandlers()],
    files: (declaration ?? testStorage)(storage().config),
    settings: settings,
  ),
);

/// A PNG-ish body of [size] bytes.
List<int> bytesOf(int size, [int seed = 7]) =>
    List.generate(size, (i) => (i * 31 + seed) & 0xff);
