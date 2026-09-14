import 'package:dartway_core_shared/dartway_core_shared.dart';
import 'package:meta/meta.dart';

import '../context/dw_call_context.dart';

/// Where uploaded files are kept: two buckets of an S3-compatible storage
/// (AWS S3, MinIO, Yandex Object Storage, Cloudflare R2 …), one public and one
/// private. A rule's visibility picks the bucket.
///
/// A bucket is public or private as a whole, never by key prefix: a prefix
/// policy is one mistyped resource away from making every file public, and a
/// storage console shows a bucket's access, not a prefix's.
///
/// - [publicBucket] is readable anonymously — its objects, not its listing —
///   and its files are served from [publicBaseUrl];
/// - [privateBucket] is never readable without a signature: its files are
///   read through short presigned links, after `DwFileStorage.canRead`.
///
/// The server holds the keys and signs; clients get presigned URLs for one
/// object at a time and never see the keys. When [verifyBuckets] is on, the
/// server checks at startup that both buckets exist and are exactly as public
/// as declared, and refuses to start otherwise. `DwFileStorageSetup.provision`
/// creates and configures both buckets on a storage the project runs itself.
///
/// A browser app uploads cross-origin, so both buckets' CORS configuration
/// must allow `PUT` from the app's origin with the headers `content-type` and
/// `if-none-match`.
final class DwFileStorageConfig {
  const DwFileStorageConfig({
    required this.endpoint,
    this.region = 'us-east-1',
    required this.accessKey,
    required this.secretKey,
    this.publicBucket,
    this.publicBaseUrl,
    this.privateBucket,
    this.pathStyle = true,
    this.verifyBuckets = true,
  });

  /// Reads `ENDPOINT`, `REGION`, `ACCESS_KEY`, `SECRET_KEY`, `PUBLIC_BUCKET`,
  /// `PUBLIC_BASE_URL`, `PRIVATE_BUCKET`, `PATH_STYLE` and `VERIFY_BUCKETS`
  /// under [prefix].
  ///
  /// Every missing required key and every malformed value is reported at
  /// once, as `DwDatabaseConfig.fromEnvironment` does. Which buckets are
  /// needed is the rules' business, so neither is required here: the server
  /// names the missing one at startup.
  factory DwFileStorageConfig.fromEnvironment(
    Map<String, String> environment, {
    String prefix = 'DW_STORAGE_',
  }) {
    final problems = <String>[];

    String? value(String key, {bool required = false}) {
      final raw = environment['$prefix$key'];
      if (raw == null || raw.isEmpty) {
        if (required) problems.add('$prefix$key is not set');
        return null;
      }
      return raw;
    }

    Uri? url(String key, {bool required = false}) {
      final raw = value(key, required: required);
      if (raw == null) return null;
      final parsed = Uri.tryParse(raw);
      if (parsed == null ||
          (parsed.scheme != 'http' && parsed.scheme != 'https') ||
          parsed.host.isEmpty) {
        problems.add('$prefix$key must be an http or https URL, got "$raw"');
        return null;
      }
      return parsed;
    }

    bool? flag(String key) {
      final raw = value(key);
      if (raw == null) return null;
      switch (raw.toLowerCase()) {
        case 'true':
          return true;
        case 'false':
          return false;
      }
      problems.add('$prefix$key must be "true" or "false", got "$raw"');
      return null;
    }

    final endpoint = url('ENDPOINT', required: true);
    final region = value('REGION');
    final accessKey = value('ACCESS_KEY', required: true);
    final secretKey = value('SECRET_KEY', required: true);
    final publicBucket = value('PUBLIC_BUCKET');
    final publicBaseUrl = url('PUBLIC_BASE_URL');
    final privateBucket = value('PRIVATE_BUCKET');
    final pathStyle = flag('PATH_STYLE');
    final verifyBuckets = flag('VERIFY_BUCKETS');
    if (problems.isNotEmpty) {
      throw ArgumentError('file storage configuration: ${problems.join('; ')}');
    }
    return DwFileStorageConfig(
      endpoint: endpoint!,
      region: region ?? 'us-east-1',
      accessKey: accessKey!,
      secretKey: secretKey!,
      publicBucket: publicBucket,
      publicBaseUrl: publicBaseUrl,
      privateBucket: privateBucket,
      pathStyle: pathStyle ?? true,
      verifyBuckets: verifyBuckets ?? true,
    );
  }

  /// The storage's API: `https://storage.yandexcloud.net`,
  /// `http://127.0.0.1:9000`. Clients upload to it directly, so it must be
  /// reachable from them, not only from the server.
  final Uri endpoint;

  final String region;
  final String accessKey;
  final String secretKey;

  /// The bucket of public files: its objects are readable by anyone, its
  /// listing by no one. `null` when no purpose is public; a public rule
  /// without it fails the server's startup.
  final String? publicBucket;

  /// The base of public files' URLs: a file's URL is this followed by its
  /// object key. Required with [publicBucket] — the bucket itself
  /// (`https://storage.example.com/<publicBucket>` path-style) or a CDN in
  /// front of it.
  final Uri? publicBaseUrl;

  /// The bucket of private files, readable only by signed requests. `null`
  /// when no purpose is private; a private rule without it fails the server's
  /// startup.
  final String? privateBucket;

  /// `endpoint/bucket/key` when true — what MinIO and most compatible
  /// storages serve without DNS setup; `bucket.endpoint/key` otherwise.
  final bool pathStyle;

  /// Whether the server checks the buckets at startup: that each exists and
  /// the keys reach it, that an object of the public bucket is readable
  /// anonymously through [publicBaseUrl], and that neither an object of the
  /// private bucket nor either bucket's listing is. On by default; turn it
  /// off only where the check cannot run from the server — a storage host
  /// that answers only once the stack around the server is up (as
  /// `dartway deploy` renders MinIO, verified from outside after the deploy
  /// instead).
  final bool verifyBuckets;

  /// Problems with the values, empty when usable.
  @internal
  List<String> get problems => [
    if ((endpoint.scheme != 'http' && endpoint.scheme != 'https') ||
        endpoint.host.isEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        (endpoint.path.isNotEmpty && endpoint.path != '/'))
      'file storage endpoint $endpoint must be an http or https URL without '
          'a path, query or fragment',
    for (final (label, bucket) in [
      ('public', publicBucket),
      ('private', privateBucket),
    ])
      if (bucket != null && !_bucketName.hasMatch(bucket))
        'file storage $label bucket "$bucket" is not a valid bucket name',
    if (publicBucket != null && publicBucket == privateBucket)
      'file storage public and private bucket are both "$publicBucket": a '
          'bucket is public or private as a whole, so they must be two',
    if (publicBucket != null && publicBaseUrl == null)
      'file storage public bucket "$publicBucket" has no publicBaseUrl to '
          'serve its files from',
    if (publicBucket == null && publicBaseUrl != null)
      'file storage publicBaseUrl $publicBaseUrl is set without a public '
          'bucket',
    if (region.isEmpty) 'file storage region is empty',
    if (accessKey.isEmpty || secretKey.isEmpty)
      'file storage access key and secret key must be set',
    if (publicBaseUrl case final base?
        when (base.scheme != 'http' && base.scheme != 'https') ||
            base.host.isEmpty ||
            base.hasQuery ||
            base.hasFragment)
      'file storage publicBaseUrl $base must be an http or https URL without '
          'a query or fragment',
  ];

  static final RegExp _bucketName = RegExp(
    r'^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$',
  );

  /// The public URL of [key] in the public bucket: [publicBaseUrl], then the
  /// key encoded as a path; `null` without a base.
  @internal
  Uri? publicUrlOf(String key) {
    final base = publicBaseUrl?.toString();
    if (base == null) return null;
    final encoded = key.split('/').map(Uri.encodeComponent).join('/');
    return Uri.parse(base.endsWith('/') ? '$base$encoded' : '$base/$encoded');
  }

  /// The bucket files of [visibility] are stored in; `null` when there is
  /// none.
  String? bucketFor(DwFileVisibility visibility) => switch (visibility) {
    DwFileVisibility.public => publicBucket,
    DwFileVisibility.private => privateBucket,
  };

  /// The secret key is never part of the text.
  @override
  String toString() =>
      'DwFileStorageConfig($endpoint, publicBucket: $publicBucket, '
      'privateBucket: $privateBucket, region: $region, pathStyle: $pathStyle, '
      'publicBaseUrl: $publicBaseUrl, verifyBuckets: $verifyBuckets)';
}

/// Who may read a file without asking: everyone through its public URL, or
/// only those the project's read rule lets through, by short-lived links.
enum DwFileVisibility {
  /// Kept in the public bucket and read by URL, by anyone who has it
  /// (avatars, product photos). The URL is permanent and costs no call.
  public,

  /// Kept in the private bucket and read through `DwGetFileLink` and
  /// `DwFileStorage.canRead` (documents, chat photos). The default everywhere
  /// a choice is made.
  private,
}

/// One purpose's rule: who may upload, what, and how it is read. A purpose
/// without a rule refuses every upload (`dw.uploadPurposeUnknown`).
final class DwUploadRule {
  /// Throws [ArgumentError] for a limit below one byte or a content type that
  /// is not a lower-case MIME type without parameters.
  DwUploadRule(
    this.purpose, {
    required this.visibility,
    required this.maxBytes,
    required Set<String> contentTypes,
    required this.canUpload,
  }) : contentTypes = Set.unmodifiable(contentTypes) {
    if (maxBytes < 1) {
      throw ArgumentError.value(maxBytes, 'maxBytes', 'must be positive');
    }
    if (contentTypes.isEmpty) {
      throw ArgumentError.value(contentTypes, 'contentTypes', 'is empty');
    }
    for (final type in contentTypes) {
      if (!DwStartUpload.isContentType(type)) {
        throw ArgumentError.value(
          type,
          'contentTypes',
          'is not a lower-case MIME type without parameters',
        );
      }
    }
  }

  final DwUploadPurpose purpose;

  /// Required: whether a file is public is a decision, never a default
  /// (#213 kept every upload public-read).
  final DwFileVisibility visibility;

  /// The largest file, in bytes. Bound into the upload URL's signature, so
  /// storage refuses a larger body even from a client that lies.
  final int maxBytes;

  /// The accepted types, exactly: `image/jpeg`, `image/png`. The type is
  /// bound into the upload URL as well, and decides the object key's
  /// extension.
  final Set<String> contentTypes;

  /// Whether the caller may upload for this purpose. Runs after the size and
  /// type checks, inside the start command's transaction; false refuses
  /// `dw.forbidden`. The caller is always signed in: every file belongs to an
  /// account.
  final Future<bool> Function(DwCallContext ctx) canUpload;
}

/// A stored file as the server knows it: what the read rule decides on.
final class DwFileRecord {
  const DwFileRecord({
    required this.id,
    required this.accountId,
    required this.purpose,
    required this.visibility,
    required this.fileName,
    required this.contentType,
    required this.byteSize,
    required this.createdAt,
    required this.confirmedAt,
  });

  final int id;

  /// The account that uploaded it.
  final int accountId;

  /// [DwUploadPurpose.purposeName].
  final String purpose;
  final DwFileVisibility visibility;
  final String fileName;
  final String contentType;
  final int byteSize;
  final DateTime createdAt;

  /// `null` until the upload is finished.
  final DateTime? confirmedAt;

  /// Whether [purpose] is this file's purpose.
  bool isFor(DwUploadPurpose purpose) => this.purpose == purpose.purposeName;

  @override
  String toString() =>
      'DwFileRecord($id, account $accountId, $purpose, ${visibility.name})';
}

/// File uploads of a server: `DwAppServer(files: DwFileStorage(config,
/// rules: [...]))`.
///
/// Uploads go from the client straight to storage; the server never touches
/// the bytes. It answers `DwStartUpload` with a presigned PUT for a key it
/// builds itself (`<purpose>/<account>/<random>.<ext>`) in the bucket of the
/// rule's visibility, checks the stored object by `HEAD` on `DwFinishUpload`,
/// and records every file, with its bucket, in `dw_stored_file`. Uploads that
/// are not finished are removed with their objects by a framework job once
/// their ticket and [uploadGrace] have passed.
final class DwFileStorage {
  DwFileStorage(
    this.config, {
    required List<DwUploadRule> rules,
    this.canRead,
    this.ticketLifetime = const Duration(minutes: 15),
    this.uploadGrace = const Duration(minutes: 15),
    this.linkLifetime = const Duration(minutes: 10),
    this.maxPendingUploads = 10,
    this.cleanupInterval = const Duration(minutes: 10),
    this.requestTimeout = const Duration(seconds: 30),
  }) : rules = List.unmodifiable(rules);

  final DwFileStorageConfig config;

  /// One per purpose that accepts uploads.
  final List<DwUploadRule> rules;

  /// Whether the caller may read a private file (`DwGetFileLink`). Absent:
  /// only the account that uploaded it. A `false` answers `dw.forbidden` to a
  /// signed-in caller and `unauthenticated` to an anonymous one. Public files
  /// are never asked about: their URL is public anyway.
  final Future<bool> Function(DwCallContext ctx, DwFileRecord file)? canRead;

  /// How long an upload URL accepts the upload. Keep it short: until it
  /// expires, whoever holds the URL can put the object (once — the upload is
  /// conditional on the key being free).
  final Duration ticketLifetime;

  /// How long after its ticket expired an upload may still be finished — a
  /// large upload started just before the expiry arrives after it — and is
  /// kept before cleanup removes it.
  final Duration uploadGrace;

  /// How long a private file's link works.
  final Duration linkLifetime;

  /// Unfinished uploads an account may hold with live tickets; one more is
  /// refused `dw.tooManyRequests` until the oldest expires. Without a limit,
  /// one account could reserve storage without end between two cleanups.
  final int maxPendingUploads;

  /// How often unfinished uploads are looked for.
  final Duration cleanupInterval;

  /// The longest a single storage request (HEAD, DELETE) may take.
  final Duration requestTimeout;

  /// The largest `X-Amz-Expires` storage accepts: seven days.
  static const Duration maxPresignedLifetime = Duration(days: 7);

  static final RegExp _purposeName = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');

  /// Problems with the declaration, empty when it is consistent.
  @internal
  List<String> get problems {
    final problems = [...config.problems];
    final purposes = <String>{};
    for (final rule in rules) {
      final name = rule.purpose.purposeName;
      if (!_purposeName.hasMatch(name)) {
        problems.add(
          'upload purpose "$name" must be an identifier of letters, digits '
          'and "_": it is the first segment of object keys',
        );
      }
      if (!purposes.add(name)) {
        problems.add('upload purpose "$name" has more than one rule');
      }
    }
    for (final visibility in DwFileVisibility.values) {
      final homeless = [
        for (final rule in rules)
          if (rule.visibility == visibility) '"${rule.purpose.purposeName}"',
      ];
      if (homeless.isNotEmpty && config.bucketFor(visibility) == null) {
        problems.add(
          '${visibility.name} upload purposes ${homeless.toSet().join(', ')} '
          'need a ${visibility.name} bucket, and the file storage has none',
        );
      }
    }
    void lifetime(String name, Duration value, {Duration min = Duration.zero}) {
      if (value < min || value > maxPresignedLifetime) {
        problems.add(
          'file storage $name must be between $min and $maxPresignedLifetime, '
          'got $value',
        );
      }
    }

    lifetime('ticketLifetime', ticketLifetime, min: const Duration(seconds: 1));
    lifetime('linkLifetime', linkLifetime, min: const Duration(seconds: 1));
    lifetime('uploadGrace', uploadGrace);
    if (maxPendingUploads < 1) {
      problems.add('file storage maxPendingUploads must be at least 1');
    }
    if (cleanupInterval <= Duration.zero) {
      problems.add('file storage cleanupInterval must be positive');
    }
    if (requestTimeout <= Duration.zero) {
      problems.add('file storage requestTimeout must be positive');
    }
    return problems;
  }
}
