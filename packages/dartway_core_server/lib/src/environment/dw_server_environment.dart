import 'package:dartway_orm/dartway_orm.dart';

import '../files/dw_file_storage.dart';
import 'dw_environment_reader.dart';

/// What the framework's own variables configure: the database, the file
/// storage, the port and the browser origins — read by one call, so a
/// project's `bin/server.dart` parses nothing by hand.
///
/// | Variable | Becomes |
/// |---|---|
/// | `DW_DATABASE_*` | [database], as `DwDatabaseConfig.fromEnvironment` reads it |
/// | `DW_STORAGE_*` | [storage]; `null` without `DW_STORAGE_ENDPOINT` |
/// | `DW_STORAGE_PROVISION` | [provisionStorage] |
/// | `PORT` | [port], 8080 by default |
/// | `DW_ALLOWED_ORIGINS` | [allowedOrigins], comma-separated |
///
/// Read as a part of the project's own environment, so one start reports
/// every missing variable of both:
///
/// ```dart
/// DwEnvironmentReader.read(variables, (read) => AppEnvironment(
///   server: DwServerEnvironment.read(read),
///   …
/// ));
/// ```
final class DwServerEnvironment {
  const DwServerEnvironment({
    required this.database,
    this.storage,
    this.provisionStorage = false,
    this.port = 8080,
    this.allowedOrigins = const {},
  });

  /// The framework's variables out of [read], problems recorded there.
  ///
  /// [defaultPublicBucket] and [defaultPrivateBucket] name the buckets when
  /// `DW_STORAGE_PUBLIC_BUCKET` / `_PRIVATE_BUCKET` are not set — the names
  /// `dartway create` gives a project, and `dartway deploy` its bundled
  /// storage. With `DW_STORAGE_PATH_STYLE` not `false` and no
  /// `DW_STORAGE_PUBLIC_BASE_URL`, the public bucket is served from itself on
  /// the endpoint (`<endpoint>/<public bucket>`). A default that is wrong for
  /// a real storage does not pass silently: the server checks both buckets
  /// as it starts (`DW_STORAGE_VERIFY_BUCKETS`).
  static DwServerEnvironment read(
    DwEnvironmentReader read, {
    String? defaultPublicBucket,
    String? defaultPrivateBucket,
  }) {
    final storage = _storage(
      read,
      defaultPublicBucket: defaultPublicBucket,
      defaultPrivateBucket: defaultPrivateBucket,
    );
    final provision = read.flag(provisionVariable);
    if (provision && read.optional(_endpoint) == null) {
      read.report(
        '$provisionVariable is true and $_endpoint is not set: there is no '
        'storage to provision',
      );
    }
    final port = read.integer('PORT', fallback: 8080);
    if (port < 0 || port > 65535) {
      read.report('PORT must be a port number (0–65535), got $port');
    }
    return DwServerEnvironment(
      database: _database(read),
      storage: storage,
      provisionStorage: provision && storage != null,
      port: port,
      allowedOrigins: read.list('DW_ALLOWED_ORIGINS').toSet(),
    );
  }

  /// The variable that asks `bin/server.dart` to create both buckets and set
  /// their access before starting (`DwFileStorageSetup.provision`): for a
  /// storage the project owns, never for one somebody else administers.
  static const String provisionVariable = 'DW_STORAGE_PROVISION';

  static const String _endpoint = 'DW_STORAGE_ENDPOINT';

  /// The database (`DW_DATABASE_*`). The server applies its migrations as it
  /// starts.
  final DwDatabaseConfig database;

  /// The S3-compatible storage for uploads (`DW_STORAGE_*`), or `null`
  /// without `DW_STORAGE_ENDPOINT`: the server then runs without uploads.
  final DwFileStorageConfig? storage;

  /// `DW_STORAGE_PROVISION=true` with a [storage]: create both buckets and
  /// set their access before starting.
  final bool provisionStorage;

  /// `PORT`, 8080 by default.
  final int port;

  /// `DW_ALLOWED_ORIGINS`: browser origins, besides the one the live socket
  /// is served on, that may open it — `DwServerSettings.allowedOrigins`. A
  /// web app served through the same host needs none.
  final Set<String> allowedOrigins;

  static DwDatabaseConfig _database(DwEnvironmentReader read) {
    try {
      return DwDatabaseConfig.fromEnvironment(read.variables);
    } on ArgumentError catch (error) {
      read.report('${error.message}');
      return const DwDatabaseConfig(host: '', name: '', user: '', password: '');
    }
  }

  static DwFileStorageConfig? _storage(
    DwEnvironmentReader read, {
    required String? defaultPublicBucket,
    required String? defaultPrivateBucket,
  }) {
    final endpoint = read.optional(_endpoint);
    if (endpoint == null) return null;
    final publicBucket =
        read.optional('DW_STORAGE_PUBLIC_BUCKET') ?? defaultPublicBucket;
    final privateBucket =
        read.optional('DW_STORAGE_PRIVATE_BUCKET') ?? defaultPrivateBucket;
    final pathStyle =
        read.optional('DW_STORAGE_PATH_STYLE')?.toLowerCase() != 'false';
    final base = endpoint.endsWith('/')
        ? endpoint.substring(0, endpoint.length - 1)
        : endpoint;
    try {
      return DwFileStorageConfig.fromEnvironment({
        ...read.variables,
        'DW_STORAGE_PUBLIC_BUCKET': ?publicBucket,
        'DW_STORAGE_PRIVATE_BUCKET': ?privateBucket,
        // Path style only: a virtual-hosted base depends on DNS nobody set up
        // for a development storage.
        if (publicBucket != null &&
            read.optional('DW_STORAGE_PUBLIC_BASE_URL') == null &&
            pathStyle)
          'DW_STORAGE_PUBLIC_BASE_URL': '$base/$publicBucket',
      });
    } on ArgumentError catch (error) {
      read.report('${error.message}');
      return null;
    }
  }
}
