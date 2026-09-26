import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../files/dw_file_storage.dart';
import '../files/dw_object_store.dart';
import '../files/dw_storage_buckets.dart';

/// A public and a private bucket for one test file, provisioned as a project
/// storage is ([DwFileStorageSetup.provision]) and removed, objects and all,
/// after it — the file storage counterpart of `DwTestDatabase`.
///
/// ```dart
/// late DwTestStorage storage;
/// setUpAll(() async => storage = await DwTestStorage.create());
/// tearDownAll(() async => storage.drop());
/// // DwAppServer(files: DwFileStorage(storage.config, rules: [...]))
/// ```
final class DwTestStorage {
  DwTestStorage._(this.config, this._store);

  /// Both buckets, the public one served from itself on the storage
  /// (path-style, as a development RustFS serves it), with the bucket check
  /// on: a server started on it verifies them as in production.
  final DwFileStorageConfig config;

  final DwObjectStore _store;

  String get publicBucket => config.publicBucket!;
  String get privateBucket => config.privateBucket!;

  /// Creates `<prefix>-pub-<random>` and `<prefix>-prv-<random>` on the
  /// storage named by `DW_STORAGE_ENDPOINT`, `DW_STORAGE_ACCESS_KEY`,
  /// `DW_STORAGE_SECRET_KEY` and optionally `DW_STORAGE_REGION` and
  /// `DW_STORAGE_PATH_STYLE` in [environment] (the process environment by
  /// default); bucket names there are ignored. A missing variable throws a
  /// [StateError] naming them.
  static Future<DwTestStorage> create({
    Map<String, String>? environment,
    String prefix = 'dw-test',
  }) async {
    if (!RegExp(r'^[a-z0-9][a-z0-9-]{0,40}$').hasMatch(prefix)) {
      throw ArgumentError.value(
        prefix,
        'prefix',
        'must be lower-case letters, digits and dashes, at most 41 long',
      );
    }
    final DwFileStorageConfig base;
    try {
      base = DwFileStorageConfig.fromEnvironment({
        ...(environment ?? Platform.environment),
        'DW_STORAGE_PUBLIC_BUCKET': '',
        'DW_STORAGE_PUBLIC_BASE_URL': '',
        'DW_STORAGE_PRIVATE_BUCKET': '',
      });
    } on ArgumentError catch (error) {
      throw StateError(
        'DwTestStorage needs an S3-compatible storage: set '
        'DW_STORAGE_ENDPOINT, DW_STORAGE_ACCESS_KEY and DW_STORAGE_SECRET_KEY '
        '(${error.message})',
      );
    }
    final random = Random.secure();
    String name(String role) =>
        '$prefix-$role-${List.generate(10, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[random.nextInt(36)]).join()}';
    final publicBucket = name('pub');
    final endpoint = base.endpoint;
    final config = DwFileStorageConfig(
      endpoint: endpoint,
      region: base.region,
      accessKey: base.accessKey,
      secretKey: base.secretKey,
      pathStyle: base.pathStyle,
      publicBucket: publicBucket,
      publicBaseUrl: base.pathStyle
          ? endpoint.replace(path: '/$publicBucket')
          : endpoint.replace(host: '$publicBucket.${endpoint.host}', path: ''),
      privateBucket: name('prv'),
    );
    await DwFileStorageSetup.provision(config);
    return DwTestStorage._(
      config,
      DwObjectStore(config, requestTimeout: const Duration(seconds: 10)),
    );
  }

  /// Every key in [bucket], listed with the server's keys.
  Future<List<String>> keys(String bucket) async {
    final response = await _store.send(
      'GET',
      bucket: bucket,
      query: [('list-type', '2')],
    );
    final body = await utf8.decodeStream(response);
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('could not list $bucket: ${response.statusCode} $body');
    }
    return [
      for (final match in RegExp(r'<Key>([^<]+)</Key>').allMatches(body))
        match.group(1)!,
    ];
  }

  /// Removes both buckets with every object in them.
  Future<void> drop() async {
    try {
      for (final bucket in [publicBucket, privateBucket]) {
        final head = await _store.send('HEAD', bucket: bucket);
        await head.drain<void>();
        if (head.statusCode == HttpStatus.notFound) continue;
        for (final key in await keys(bucket)) {
          await _store.delete(bucket, key);
        }
        final response = await _store.send('DELETE', bucket: bucket);
        final code = await DwObjectStore.errorCodeOf(response);
        if (response.statusCode >= 300) {
          throw DwStorageException(
            'DELETE bucket $bucket',
            response.statusCode,
            code,
          );
        }
      }
    } finally {
      _store.close();
    }
  }
}
