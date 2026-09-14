import 'dart:convert';

import 'package:meta/meta.dart';

import 'dw_file_storage.dart';
import 'dw_object_store.dart';

/// Creates the two buckets of a [DwFileStorageConfig] on a storage the project
/// runs itself — MinIO in development, in tests, in a `dartway deploy` stack —
/// and gives each exactly its access.
///
/// ```dart
/// await DwFileStorageSetup.provision(config);
/// ```
///
/// Idempotent: run it on every start of a development storage, before every
/// test run, on every deploy. An existing bucket keeps its objects.
abstract final class DwFileStorageSetup {
  /// Creates [DwFileStorageConfig.publicBucket] and
  /// [DwFileStorageConfig.privateBucket] where they are missing; sets the
  /// public bucket's policy to [publicReadPolicy] (anonymous `s3:GetObject`
  /// on its objects, nothing else — not its listing); deletes the private
  /// bucket's policy, so nothing but a signed request reads it.
  ///
  /// Deleting the policy is right for a storage the project owns wholly and
  /// wrong for a bucket somebody administers with policies of their own:
  /// there, configure the buckets by hand and let the server's startup check
  /// ([DwFileStorageConfig.verifyBuckets]) say whether they are right.
  ///
  /// Throws [ArgumentError] for a configuration with problems, [StateError]
  /// for a bucket name taken by another owner, and [DwStorageException] when
  /// storage refuses a step.
  static Future<void> provision(
    DwFileStorageConfig config, {
    Duration requestTimeout = const Duration(seconds: 30),
  }) async {
    if (config.problems case final problems when problems.isNotEmpty) {
      throw ArgumentError('file storage configuration: ${problems.join('; ')}');
    }
    final store = DwObjectStore(config, requestTimeout: requestTimeout);
    try {
      if (config.publicBucket case final bucket?) {
        await _create(store, bucket);
        final response = await store.send(
          'PUT',
          bucket: bucket,
          query: [('policy', '')],
          body: utf8.encode(publicReadPolicy(bucket)),
          headers: {'content-type': 'application/json'},
        );
        final code = await DwObjectStore.errorCodeOf(response);
        if (response.statusCode >= 300) {
          throw DwStorageException(
            'PUT policy of $bucket',
            response.statusCode,
            code,
          );
        }
      }
      if (config.privateBucket case final bucket?) {
        await _create(store, bucket);
        final response = await store.send(
          'DELETE',
          bucket: bucket,
          query: [('policy', '')],
        );
        final code = await DwObjectStore.errorCodeOf(response);
        if (response.statusCode >= 300 && code != 'NoSuchBucketPolicy') {
          throw DwStorageException(
            'DELETE policy of $bucket',
            response.statusCode,
            code,
          );
        }
      }
    } finally {
      store.close();
    }
  }

  /// The policy of a public bucket: anyone may read an object whose key they
  /// know. Listing stays private — keys carry 192 random bits precisely so
  /// that nobody can enumerate them.
  static String publicReadPolicy(String bucket) => jsonEncode({
    'Version': '2012-10-17',
    'Statement': [
      {
        'Sid': 'DartWayPublicRead',
        'Effect': 'Allow',
        'Principal': {
          'AWS': ['*'],
        },
        'Action': ['s3:GetObject'],
        'Resource': ['arn:aws:s3:::$bucket/*'],
      },
    ],
  });

  static Future<void> _create(DwObjectStore store, String bucket) async {
    final region = store.config.region;
    final response = await store.send(
      'PUT',
      bucket: bucket,
      // us-east-1 is the one region S3 refuses to be named in.
      body: region == 'us-east-1'
          ? const []
          : utf8.encode(
              '<CreateBucketConfiguration '
              'xmlns="http://s3.amazonaws.com/doc/2006-03-01/">'
              '<LocationConstraint>$region</LocationConstraint>'
              '</CreateBucketConfiguration>',
            ),
    );
    final code = await DwObjectStore.errorCodeOf(response);
    if (response.statusCode < 300 || code == 'BucketAlreadyOwnedByYou') return;
    if (code == 'BucketAlreadyExists') {
      throw StateError(
        'bucket "$bucket" already exists and belongs to another account',
      );
    }
    throw DwStorageException('PUT bucket $bucket', response.statusCode, code);
  }
}

/// The startup check of [DwFileStorageConfig.verifyBuckets]: each bucket
/// exists and takes the keys, and is exactly as public as it is declared.
@internal
abstract final class DwBucketCheck {
  /// The object the check writes into each bucket and reads back without
  /// credentials. Outside every key the server builds: those start with a
  /// purpose, which starts with a letter. Left in place — one constant object
  /// per bucket — so two servers starting at once cannot delete it from
  /// under each other's check.
  static const String probeKey = '_dartway/visibility-probe';

  static final List<int> probeBody = utf8.encode(
    'DartWay checks at startup that this bucket is exactly as public as it is '
    'declared.\n',
  );

  /// Problems with the configured buckets, empty when both are right.
  static Future<List<String>> run(
    DwFileStorageConfig config,
    DwObjectStore store,
  ) async {
    final results = await Future.wait([
      if (config.publicBucket case final bucket?)
        _check(config, store, bucket, public: true),
      if (config.privateBucket case final bucket?)
        _check(config, store, bucket, public: false),
    ]);
    return [for (final problems in results) ...problems];
  }

  static Future<List<String>> _check(
    DwFileStorageConfig config,
    DwObjectStore store,
    String bucket, {
    required bool public,
  }) async {
    final name =
        'file storage ${public ? 'public' : 'private'} bucket "$bucket"';
    try {
      final head = await store.send('HEAD', bucket: bucket);
      await head.drain<void>();
      switch (head.statusCode) {
        case 200:
          break;
        case 404:
          return ['$name does not exist at ${config.endpoint}'];
        case 403:
          return ['$name refuses the configured keys: HEAD answered 403'];
        case final status:
          return [
            '$name cannot be used: HEAD answered $status (a wrong region or '
                'addressing style answers this way too)',
          ];
      }

      final put = await store.send(
        'PUT',
        bucket: bucket,
        key: probeKey,
        body: probeBody,
        headers: {'content-type': 'text/plain'},
      );
      final code = await DwObjectStore.errorCodeOf(put);
      if (put.statusCode >= 300) {
        return [
          '$name does not accept writes with the configured keys: PUT '
              'answered ${put.statusCode}${code == null ? '' : ' $code'}',
        ];
      }

      final problems = <String>[];
      if (public) {
        final url = config.publicUrlOf(probeKey)!;
        final read = await store.anonymousGet(url);
        if (read.status != 200 || !_same(read.body, probeBody)) {
          problems.add(
            '$name is not readable anonymously: GET $url without credentials '
            'answered ${read.status}'
            '${read.status == 200 ? ' with another body' : ''}, so no public '
            'file would open. Give the bucket an anonymous read policy for '
            'its objects (DwFileStorageSetup.provision sets one), or point '
            'publicBaseUrl at what serves it',
          );
        }
      } else {
        final url = store.urlOf(bucket, key: probeKey);
        final read = await store.anonymousGet(url);
        if (read.status < 300) {
          problems.add(
            '$name is readable anonymously: GET $url without credentials '
            'answered ${read.status}, so every private file in it is public. '
            'Remove its anonymous access (its bucket policy)',
          );
        }
      }
      final listing = store.urlOf(bucket, query: [('list-type', '2')]);
      final listed = await store.anonymousGet(listing);
      if (listed.status < 300) {
        problems.add(
          '$name lets anyone list its keys: GET $listing without credentials '
          'answered ${listed.status}, so its files can be enumerated. Allow '
          'anonymous s3:GetObject at most, never s3:ListBucket',
        );
      }
      return problems;
    } on Object catch (error) {
      return [
        '$name could not be checked at ${config.endpoint}: $error. Where the '
            'server cannot reach storage while it starts, turn the check off '
            '(verifyBuckets: false, DW_STORAGE_VERIFY_BUCKETS=false) and '
            'verify the buckets from where they are reachable',
      ];
    }
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
