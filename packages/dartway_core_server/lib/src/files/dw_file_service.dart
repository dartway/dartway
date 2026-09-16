import 'dart:convert';
import 'dart:math';

import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:dartway_orm/dartway_orm.dart';
import 'package:meta/meta.dart';

import '../alerts/dw_server_logger.dart';
import '../context/dw_call_context.dart';
import '../handlers/dw_call_handler.dart';
import '../jobs/dw_job_queue.dart';
import '../server/dw_runtime.dart';
import 'dw_file_storage.dart';
import 'dw_object_store.dart';
import 'dw_storage_buckets.dart';

/// Stored files, for server code: `ctx.files`.
///
/// A project row references a file by id (`imageFileId`), checked with
/// [requireOwned] when the row is written, and turns ids into URLs with
/// [publicUrls] when rows are read — one query for a whole list.
abstract interface class DwFileService {
  /// The caller's confirmed file [fileId] of [purpose]; otherwise refuses
  /// `dw.fileNotOwned` on [field] — whether the file is absent, someone
  /// else's, unfinished or of another purpose, so a caller learns nothing
  /// about files that are not theirs.
  ///
  /// Refuses `unauthenticated` for an anonymous caller.
  Future<DwStoredFile> requireOwned(
    int fileId,
    DwUploadPurpose purpose, {
    String? field,
  });

  /// The URLs of the confirmed public files among [fileIds]; private,
  /// unfinished and absent ids are not in the answer.
  Future<Map<int, String>> publicUrls(Iterable<int> fileIds);

  /// Deletes the file: its row now, in the caller's transaction, and its
  /// object once that transaction commits — by a framework job, retried until
  /// storage confirms, so a crash after the commit cannot leave the object
  /// behind. Answers whether the file existed.
  ///
  /// Throws [StateError] in a request: reads have no side effects.
  Future<bool> delete(int fileId);

  /// The bytes of the confirmed file [fileId], public or private; `null` when
  /// there is none.
  ///
  /// The server's own read, for server code that works on a file — a model
  /// looking at a photo, a document being parsed. No `canRead` is asked: the
  /// reader is the server, and what it does with the bytes is the handler's
  /// decision. Never return them to a caller without checking the caller may
  /// read the file.
  Future<List<int>?> read(int fileId);

  /// A link to the confirmed file [fileId] that anyone holding it can read
  /// until [expires] passes (the storage's link lifetime by default); `null`
  /// when there is none.
  ///
  /// For server code handing a private file to another service that fetches
  /// by URL. Like [read], it asks no `canRead`: it is the server's access,
  /// not the caller's — a client asks for a link with `DwGetFileLink`.
  Future<DwFileLink?> readLink(int fileId, {Duration? expires});

  /// Stores [bytes] as a new confirmed file of [purpose] owned by
  /// [accountId] — a file the server made, not one a client uploaded: a
  /// generated image, a rendered report.
  ///
  /// The purpose's rule applies as to an upload — its visibility picks the
  /// bucket, and a size over `maxBytes` or a content type it does not list
  /// is an [ArgumentError], a mistake in server code rather than a refusal.
  /// `canUpload` is not asked: the writer is the server.
  ///
  /// The object is written at once and the file confirmed in the caller's
  /// transaction. If that transaction rolls back, the file is left
  /// unconfirmed and removed with its object by the cleanup of unfinished
  /// uploads, as an abandoned upload is.
  ///
  /// Throws [StateError] in a request: reads have no side effects.
  Future<DwStoredFile> store(
    DwUploadPurpose purpose, {
    required int accountId,
    required List<int> bytes,
    required String contentType,
    required String fileName,
  });
}

/// The file storage of a running server: the object store, the built-in
/// handlers and jobs, and `ctx.files`.
@internal
final class DwFileStore {
  DwFileStore(this.storage)
    : objects = DwObjectStore(
        storage.config,
        requestTimeout: storage.requestTimeout,
      ),
      rules = {
        for (final rule in storage.rules) rule.purpose.purposeName: rule,
      };

  final DwFileStorage storage;
  final DwObjectStore objects;
  final Map<String, DwUploadRule> rules;

  static final Random _random = Random.secure();

  /// The framework's call types answered here; a project may not register
  /// its own handler for them.
  static const Set<Type> builtInTypes = {
    DwStartUpload,
    DwFinishUpload,
    DwGetFileLink,
  };

  static const String deleteObjectJob = 'dw.files.deleteObject';
  static const String cleanupJob = 'dw.files.cleanup';

  /// Rows removed per cleanup transaction, and transactions per run: a
  /// backlog is worked off in short transactions, and a run is bounded so a
  /// large one spreads over several runs.
  static const int cleanupBatch = 100;
  static const int cleanupBatchesPerRun = 20;

  /// Extensions of the object keys by content type. The extension is for
  /// people and tools looking at the bucket; nothing reads it back, so an
  /// unlisted type is stored as `.bin` rather than refused.
  static const Map<String, String> extensions = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/gif': 'gif',
    'image/avif': 'avif',
    'image/heic': 'heic',
    'image/heif': 'heif',
    'image/svg+xml': 'svg',
    'image/bmp': 'bmp',
    'image/tiff': 'tiff',
    'application/pdf': 'pdf',
    'application/json': 'json',
    'application/zip': 'zip',
    'application/msword': 'doc',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        'docx',
    'application/vnd.ms-excel': 'xls',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
    'text/plain': 'txt',
    'text/csv': 'csv',
    'audio/mpeg': 'mp3',
    'audio/mp4': 'm4a',
    'audio/aac': 'aac',
    'audio/ogg': 'ogg',
    'audio/wav': 'wav',
    'audio/webm': 'weba',
    'video/mp4': 'mp4',
    'video/quicktime': 'mov',
    'video/webm': 'webm',
  };

  /// The window in which a ticket may still be finished, and after which an
  /// unfinished upload is removed.
  Duration get _finishWindow => storage.ticketLifetime + storage.uploadGrace;

  /// The pool, for work that commits on its own: cleanup batches.
  DwDatabaseHandle? _database;

  /// Called once the server's database is open.
  void attach(DwDatabaseHandle database) => _database = database;

  void close() => objects.close();

  /// Problems with the buckets as storage has them — see
  /// [DwFileStorageConfig.verifyBuckets]; empty when both are right.
  Future<List<String>> verifyBuckets() =>
      DwBucketCheck.run(storage.config, objects);

  // --- handlers ---------------------------------------------------------------

  List<DwCallHandler> handlers() => [
    // Transactional: the pending count and the insert run under one lock per
    // account, or two parallel starts would both see room for one more.
    DwCallHandler.command<DwStartUpload, DwUploadTicket>(
      access: DwAccessRule.signedIn,
      handle: _start,
    ),
    // Transactional: the row is locked across the HEAD, so cleanup cannot
    // remove the object between the check and the confirmation.
    DwCallHandler.command<DwFinishUpload, DwStoredFile>(
      access: DwAccessRule.signedIn,
      handle: _finish,
    ),
    // Anonymous at the door: a public file's link is public, and a private
    // file's reader is the project's rule to decide.
    DwCallHandler.single<DwGetFileLink, DwFileLink>(
      access: DwAccessRule.anonymous,
      handle: _link,
    ),
  ];

  /// Handlers that answer every file call with a failure: for a server
  /// without `files`, whose protocol still carries the framework's file DTOs.
  /// An app that uploads against it is a deployment mistake, reported as an
  /// incident rather than a 404 the client would read as a protocol skew.
  static List<DwCallHandler> unconfiguredHandlers() {
    Never fail() => throw StateError(
      'A file call reached a server without file storage: pass '
      'DwAppServer(files: DwFileStorage(...)).',
    );
    return [
      DwCallHandler.command<DwStartUpload, DwUploadTicket>(
        access: DwAccessRule.signedIn,
        handle: (ctx, command) async => fail(),
      ),
      DwCallHandler.command<DwFinishUpload, DwStoredFile>(
        access: DwAccessRule.signedIn,
        handle: (ctx, command) async => fail(),
      ),
      DwCallHandler.single<DwGetFileLink, DwFileLink>(
        access: DwAccessRule.anonymous,
        handle: (ctx, request) async => fail(),
      ),
    ];
  }

  Future<DwUploadTicket> _start(
    DwCallContext ctx,
    DwStartUpload command,
  ) async {
    final rule =
        rules[command.purpose] ??
        ctx.refuse(DwUploadRefusal.purposeUnknown, field: 'purpose');
    if (command.byteSize > rule.maxBytes) {
      ctx.refuse(
        DwUploadRefusal.tooLarge,
        field: 'byteSize',
        params: {'maxBytes': rule.maxBytes},
      );
    }
    if (!rule.contentTypes.contains(command.contentType)) {
      ctx.refuse(
        DwUploadRefusal.typeRejected,
        field: 'contentType',
        params: {'allowed': (rule.contentTypes.toList()..sort()).join(',')},
      );
    }
    if (!await rule.canUpload(ctx)) ctx.refuse(DwCoreRefusal.forbidden);

    final accountId = ctx.requireAccountId;
    await ctx.db.advisoryLock(
      DwLockSpace.pendingUploads,
      dwLockKey('$accountId'),
    );
    final pending = (await ctx.db.query(
      'SELECT count(*) AS n, min(created_at) AS oldest, now() AS now '
      'FROM dw_stored_file WHERE account_id = @account '
      'AND confirmed_at IS NULL '
      'AND created_at > now() - @lifetime::int8 * interval \'1 microsecond\'',
      params: {
        'account': accountId,
        'lifetime': storage.ticketLifetime.inMicroseconds,
      },
    )).single;
    if (pending.get<int>('n') >= storage.maxPendingUploads) {
      // Room frees up when the oldest ticket expires: its URL stops
      // accepting uploads then, finished or not.
      final oldest = pending.get<DateTime>('oldest');
      throw DwRefusalException(
        DwCallRefusal.tooManyRequests(
          oldest
              .add(storage.ticketLifetime)
              .difference(pending.get<DateTime>('now')),
        ),
      );
    }

    // Present: startup refuses a rule whose visibility has no bucket.
    final bucket = storage.config.bucketFor(rule.visibility)!;
    final key =
        '${rule.purpose.purposeName}/$accountId/${_randomName()}.'
        '${extensions[command.contentType] ?? 'bin'}';
    final row = (await ctx.db.query(
      'INSERT INTO dw_stored_file (account_id, purpose, bucket, object_key, '
      'visibility, file_name, content_type, byte_size) '
      'VALUES (@account, @purpose, @bucket, @key, @visibility, @name, @type, '
      '@size) RETURNING id',
      params: {
        'account': accountId,
        'purpose': rule.purpose.purposeName,
        'bucket': bucket,
        'key': key,
        'visibility': rule.visibility.name,
        'name': command.fileName,
        'type': command.contentType,
        'size': command.byteSize,
      },
    )).single;
    final now = DateTime.now().toUtc();
    final put = objects.presignPut(
      bucket: bucket,
      key: key,
      contentType: command.contentType,
      byteSize: command.byteSize,
      expires: storage.ticketLifetime,
      time: now,
    );
    return DwUploadTicket(
      id: row.get<int>('id'),
      uploadUrl: '${put.url}',
      headers: put.headers,
      // Whole seconds: the signature counts them from its own timestamp,
      // which has no fraction.
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch ~/ 1000 * 1000,
        isUtc: true,
      ).add(storage.ticketLifetime),
    );
  }

  /// 24 random bytes, base64url: 192 bits nobody can guess or enumerate, in
  /// characters that need no encoding in a URL.
  static String _randomName() => base64Url
      .encode(List.generate(24, (_) => _random.nextInt(256)))
      .replaceAll('=', '');

  Future<DwStoredFile> _finish(
    DwCallContext ctx,
    DwFinishUpload command,
  ) async {
    final rows = await ctx.db.query(
      'SELECT $_columns, bucket, object_key FROM dw_stored_file '
      'WHERE id = @id FOR UPDATE',
      params: {'id': command.ticketId},
    );
    // Someone else's ticket reads as none: a ticket is its uploader's alone,
    // and ids are sequential.
    if (rows.isEmpty ||
        rows.single.get<int>('account_id') != ctx.requireAccountId) {
      ctx.refuse(DwCoreRefusal.notFound);
    }
    final row = rows.single;
    final record = _record(row);
    if (record.confirmedAt != null) return storedFile(record, row);

    // Read once the lock is held, from the clock rather than the
    // transaction's start: cleanup decides expiry by its own transaction
    // start, which is never later than the moment it took this lock — so
    // whatever cleanup counted as expired, this counts as expired too.
    final expired = (await ctx.db.query(
      'SELECT clock_timestamp() > @created::timestamptz + '
      '@window::int8 * interval \'1 microsecond\' AS expired',
      params: {
        'created': record.createdAt,
        'window': _finishWindow.inMicroseconds,
      },
    )).single.get<bool>('expired');
    if (expired) ctx.refuse(DwUploadRefusal.expired);

    final head = await objects.head(
      row.get<String>('bucket'),
      row.get<String>('object_key'),
    );
    if (head == null) ctx.refuse(DwUploadRefusal.missing);
    if (head.byteSize != record.byteSize ||
        head.contentType != record.contentType) {
      ctx.log.warning(
        'upload ${record.id} does not match its ticket: stored '
        '${head.byteSize} bytes of ${head.contentType}, issued for '
        '${record.byteSize} bytes of ${record.contentType}',
      );
      ctx.refuse(DwUploadRefusal.mismatch);
    }
    await ctx.db.execute(
      'UPDATE dw_stored_file SET confirmed_at = now() WHERE id = @id',
      params: {'id': record.id},
    );
    return storedFile(record, row);
  }

  Future<DwFileLink?> _link(DwCallContext ctx, DwGetFileLink request) async {
    final rows = await ctx.db.query(
      'SELECT $_columns, bucket, object_key FROM dw_stored_file '
      'WHERE id = @id AND confirmed_at IS NOT NULL',
      params: {'id': request.fileId},
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final record = _record(row);
    final bucket = row.get<String>('bucket');
    final key = row.get<String>('object_key');
    final public = record.visibility == DwFileVisibility.public;
    if (public) {
      if (publicUrlOf(bucket, key) case final url?) {
        return DwFileLink(id: record.id, url: url);
      }
    }
    // A public file that is no longer served publicly — its bucket is not
    // the configured public bucket any more — is still everyone's: it gets a
    // link, unasked.
    final canRead = storage.canRead;
    final allowed =
        public ||
        (canRead == null
            ? record.accountId == ctx.accountId
            : await canRead(ctx, record));
    if (!allowed) {
      // An anonymous caller may be allowed once signed in; a signed-in one
      // is told no.
      if (ctx.accountId == null) throw const DwNotAuthenticatedException();
      ctx.refuse(DwCoreRefusal.forbidden);
    }
    final now = DateTime.now().toUtc();
    return DwFileLink(
      id: record.id,
      url:
          '${objects.presignGet(bucket: bucket, key: key, expires: storage.linkLifetime, time: now, fileName: record.fileName)}',
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch ~/ 1000 * 1000,
        isUtc: true,
      ).add(storage.linkLifetime),
    );
  }

  // --- rows -------------------------------------------------------------------

  static const String _columns =
      'id, account_id, purpose, visibility, file_name, content_type, '
      'byte_size, created_at, confirmed_at';

  static DwFileRecord _record(DwResultRow row) => DwFileRecord(
    id: row.get<int>('id'),
    accountId: row.get<int>('account_id'),
    purpose: row.get<String>('purpose'),
    visibility: DwFileVisibility.values.byName(row.get<String>('visibility')),
    fileName: row.get<String>('file_name'),
    contentType: row.get<String>('content_type'),
    byteSize: row.get<int>('byte_size'),
    createdAt: row.get<DateTime>('created_at'),
    confirmedAt: row['confirmed_at'] as DateTime?,
  );

  DwStoredFile storedFile(DwFileRecord record, DwResultRow row) => DwStoredFile(
    id: record.id,
    purpose: record.purpose,
    fileName: record.fileName,
    contentType: record.contentType,
    byteSize: record.byteSize,
    url: record.visibility == DwFileVisibility.public
        ? publicUrlOf(row.get<String>('bucket'), row.get<String>('object_key'))
        : null,
  );

  /// The public URL of [key] in [bucket]: the public base, then the key
  /// encoded as a path. `null` unless [bucket] is the configured public
  /// bucket — a file stays where it was uploaded, and a bucket that is no
  /// longer the public one is not served from the public base.
  String? publicUrlOf(String bucket, String key) =>
      bucket == storage.config.publicBucket
      ? storage.config.publicUrlOf(key)?.toString()
      : null;

  // --- jobs -------------------------------------------------------------------

  List<DwJobDefinition> jobs() => [
    DwJobDefinition(
      deleteObjectJob,
      // Storage is outside the database: a lease, not a transaction.
      transactional: false,
      maxAttempts: 10,
      handle: (ctx, payload) => objects.delete(
        payload['bucket']! as String,
        payload['key']! as String,
      ),
    ),
    DwRecurringJob(
      cleanupJob,
      every: storage.cleanupInterval,
      handle: _cleanup,
    ),
  ];

  /// Removes unfinished uploads whose ticket and grace have passed: the
  /// object first, then the row, under the row's lock. A failure leaves the
  /// rows of its batch — the next run deletes those objects again, which
  /// storage answers as done.
  ///
  /// Each batch is a transaction of its own on the pool, not a savepoint of
  /// the job's claim: a savepoint keeps its row locks until the claim commits,
  /// and a failure in the last batch would roll back the rows of every batch
  /// before it. The claim itself still keeps a second worker from running
  /// cleanup at the same time.
  Future<void> _cleanup(DwCallContext ctx) async {
    final database =
        _database ??
        (throw StateError('the file store is not attached to a database'));
    for (var batch = 0; batch < cleanupBatchesPerRun; batch++) {
      final removed = await database.transaction((tx) async {
        final rows = await tx.query(
          'SELECT id, bucket, object_key FROM dw_stored_file '
          'WHERE confirmed_at IS NULL '
          'AND created_at < now() - @window::int8 * interval \'1 microsecond\' '
          'ORDER BY confirmed_at, created_at LIMIT @limit '
          'FOR UPDATE SKIP LOCKED',
          params: {
            'window': _finishWindow.inMicroseconds,
            'limit': cleanupBatch,
          },
        );
        if (rows.isEmpty) return 0;
        // A few at a time: storage is fast, but not a thousand requests at
        // once from one process.
        for (var i = 0; i < rows.length; i += 8) {
          await Future.wait([
            for (final row in rows.skip(i).take(8))
              objects.delete(
                row.get<String>('bucket'),
                row.get<String>('object_key'),
              ),
          ]);
        }
        await tx.execute(
          'DELETE FROM dw_stored_file WHERE id = ANY(@ids::int8[])',
          params: {
            'ids': [for (final row in rows) row.get<int>('id')],
          },
        );
        return rows.length;
      });
      if (removed > 0) {
        ctx.log.info('removed $removed unfinished uploads');
      }
      if (removed < cleanupBatch) return;
    }
  }

  // --- ctx.files --------------------------------------------------------------

  DwFileService serviceFor(DwRuntimeContext ctx) => _DwContextFiles(this, ctx);
}

/// `ctx.files` of a server without file storage: every use is a
/// misconfiguration, said where it is made.
@internal
final class DwUnconfiguredFiles implements DwFileService {
  const DwUnconfiguredFiles();

  static Never _fail() => throw StateError(
    'ctx.files on a server without file storage: pass '
    'DwAppServer(files: DwFileStorage(...)).',
  );

  @override
  Future<DwStoredFile> requireOwned(
    int fileId,
    DwUploadPurpose purpose, {
    String? field,
  }) async => _fail();

  /// No ids ask nothing of storage, so they answer empty even here: a handler
  /// resolving the URLs of an empty page works on a server without files.
  @override
  Future<Map<int, String>> publicUrls(Iterable<int> fileIds) async =>
      fileIds.isEmpty ? const {} : _fail();

  @override
  Future<bool> delete(int fileId) async => _fail();

  @override
  Future<List<int>?> read(int fileId) async => _fail();

  @override
  Future<DwFileLink?> readLink(int fileId, {Duration? expires}) async =>
      _fail();

  @override
  Future<DwStoredFile> store(
    DwUploadPurpose purpose, {
    required int accountId,
    required List<int> bytes,
    required String contentType,
    required String fileName,
  }) async => _fail();
}

final class _DwContextFiles implements DwFileService {
  _DwContextFiles(this._store, this._ctx);

  final DwFileStore _store;
  final DwRuntimeContext _ctx;

  @override
  Future<DwStoredFile> requireOwned(
    int fileId,
    DwUploadPurpose purpose, {
    String? field,
  }) async {
    final accountId = _ctx.requireAccountId;
    final rows = await _ctx.db.query(
      'SELECT ${DwFileStore._columns}, bucket, object_key FROM dw_stored_file '
      'WHERE id = @id AND account_id = @account AND purpose = @purpose '
      'AND confirmed_at IS NOT NULL',
      params: {
        'id': fileId,
        'account': accountId,
        'purpose': purpose.purposeName,
      },
    );
    if (rows.isEmpty) _ctx.refuse(DwUploadRefusal.notOwned, field: field);
    final row = rows.single;
    return _store.storedFile(DwFileStore._record(row), row);
  }

  @override
  Future<Map<int, String>> publicUrls(Iterable<int> fileIds) async {
    final ids = fileIds.toSet().toList();
    if (ids.isEmpty) return const {};
    final rows = await _ctx.db.query(
      'SELECT id, bucket, object_key FROM dw_stored_file '
      "WHERE id = ANY(@ids::int8[]) AND visibility = 'public' "
      'AND confirmed_at IS NOT NULL',
      params: {'ids': ids},
    );
    return {
      for (final row in rows)
        row.get<int>('id'): ?_store.publicUrlOf(
          row.get<String>('bucket'),
          row.get<String>('object_key'),
        ),
    };
  }

  @override
  Future<bool> delete(int fileId) async {
    _ctx.requireSideEffects('files.delete');
    return _ctx.transaction((tx) async {
      final rows = await tx.query(
        'DELETE FROM dw_stored_file WHERE id = @id '
        'RETURNING bucket, object_key',
        params: {'id': fileId},
      );
      if (rows.isEmpty) return false;
      // Enqueued in the same transaction: the object goes exactly when the
      // row's deletion commits.
      await _ctx.jobs.enqueue(DwFileStore.deleteObjectJob, {
        'bucket': rows.single.get<String>('bucket'),
        'key': rows.single.get<String>('object_key'),
      });
      return true;
    });
  }

  /// The confirmed file's record and where its object is, or `null`.
  Future<({DwFileRecord record, String bucket, String key})?> _confirmed(
    int fileId,
  ) async {
    final rows = await _ctx.db.query(
      'SELECT ${DwFileStore._columns}, bucket, object_key FROM dw_stored_file '
      'WHERE id = @id AND confirmed_at IS NOT NULL',
      params: {'id': fileId},
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return (
      record: DwFileStore._record(row),
      bucket: row.get<String>('bucket'),
      key: row.get<String>('object_key'),
    );
  }

  @override
  Future<List<int>?> read(int fileId) async {
    final file = await _confirmed(fileId);
    if (file == null) return null;
    return _store.objects.get(
      file.bucket,
      file.key,
      maxBytes: file.record.byteSize,
    );
  }

  @override
  Future<DwFileLink?> readLink(int fileId, {Duration? expires}) async {
    final file = await _confirmed(fileId);
    if (file == null) return null;
    final lifetime = expires ?? _store.storage.linkLifetime;
    if (lifetime <= Duration.zero ||
        lifetime > DwFileStorage.maxPresignedLifetime) {
      throw ArgumentError.value(
        expires,
        'expires',
        'must be positive and at most ${DwFileStorage.maxPresignedLifetime}',
      );
    }
    final now = DateTime.now().toUtc();
    return DwFileLink(
      id: file.record.id,
      url:
          '${_store.objects.presignGet(bucket: file.bucket, key: file.key, expires: lifetime, time: now, fileName: file.record.fileName)}',
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch ~/ 1000 * 1000,
        isUtc: true,
      ).add(lifetime),
    );
  }

  @override
  Future<DwStoredFile> store(
    DwUploadPurpose purpose, {
    required int accountId,
    required List<int> bytes,
    required String contentType,
    required String fileName,
  }) async {
    _ctx.requireSideEffects('files.store');
    final rule =
        _store.rules[purpose.purposeName] ??
        (throw ArgumentError.value(
          purpose.purposeName,
          'purpose',
          'has no upload rule',
        ));
    if (bytes.length > rule.maxBytes) {
      throw ArgumentError.value(
        bytes.length,
        'bytes',
        'is over the ${rule.maxBytes} bytes ${purpose.purposeName} allows',
      );
    }
    if (!rule.contentTypes.contains(contentType)) {
      throw ArgumentError.value(
        contentType,
        'contentType',
        'is not one ${purpose.purposeName} allows',
      );
    }
    final database =
        _store._database ??
        (throw StateError('the file store is not attached to a database'));
    // Present: startup refuses a rule whose visibility has no bucket.
    final bucket = _store.storage.config.bucketFor(rule.visibility)!;
    final key =
        '${rule.purpose.purposeName}/$accountId/${DwFileStore._randomName()}.'
        '${DwFileStore.extensions[contentType] ?? 'bin'}';
    // Recorded unconfirmed on the pool, committed before the object exists:
    // whatever happens after — the write failing, the caller's transaction
    // rolling back — the row is there for the cleanup of unfinished uploads
    // to remove the object by.
    final row = (await database.query(
      'INSERT INTO dw_stored_file (account_id, purpose, bucket, object_key, '
      'visibility, file_name, content_type, byte_size) '
      'VALUES (@account, @purpose, @bucket, @key, @visibility, @name, @type, '
      '@size) RETURNING ${DwFileStore._columns}, bucket, object_key',
      params: {
        'account': accountId,
        'purpose': rule.purpose.purposeName,
        'bucket': bucket,
        'key': key,
        'visibility': rule.visibility.name,
        'name': fileName,
        'type': contentType,
        'size': bytes.length,
      },
    )).single;
    await _store.objects.put(
      bucket,
      key,
      bytes: bytes,
      contentType: contentType,
    );
    // In the caller's transaction: the file exists exactly when the work that
    // made it commits.
    await _ctx.db.execute(
      'UPDATE dw_stored_file SET confirmed_at = now() WHERE id = @id',
      params: {'id': row.get<int>('id')},
    );
    return _store.storedFile(DwFileStore._record(row), row);
  }
}
