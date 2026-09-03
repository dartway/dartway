// Portions of this file are derived from Serverpod S3Manager
// Copyright (c) 2021 Andres Gutierrez
// Copyright (c) 2021 Serverpod authors
//
// Licensed under the BSD 3-Clause License.
// See https://github.com/serverpod/serverpod/blob/main/LICENSE for full license text.
//
// Modifications © 2025 Evgenii Novikov (DartWay)

import 'dart:convert';

import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:mime/mime.dart';
import 'package:minio/minio.dart';
import 'package:minio/models.dart';
import 'package:path/path.dart' as path;

import 'policy.dart';

class DwCloudStorage {
  late final Minio _client;
  final DwCloudStorageConfig config;

  DwCloudStorage({required this.config}) {
    _client = Minio(
      region: config.region,
      endPoint: config.endPoint,
      port: config.port,
      useSSL: config.useSSL,
      accessKey: config.accessKey,
      secretKey: config.secretKey,
    );
  }

  String get _scheme => config.useSSL ? 'https' : 'http';

  String get uploadUrl => Uri(
    scheme: _scheme,
    host: config.endPoint,
    port: config.port,
    pathSegments: [config.bucket],
  ).toString();

  Future<bool> bucketExists() async {
    return await _client.bucketExists(config.bucket);
  }

  // TODO: dicsuss with Aidar
  // Identify MIME-type by file extension
  // String _getMimeType(String objectPath) {
  //   final pathLower = objectPath.toLowerCase();

  //   // Explicitly define types for audio and video
  //   if (pathLower.endsWith('.mp3') || pathLower.endsWith('.mpeg')) {
  //     return 'audio/mpeg';
  //   } else if (pathLower.endsWith('.m4a') || pathLower.endsWith('.aac')) {
  //     return 'audio/aac';
  //   } else if (pathLower.endsWith('.wav')) {
  //     return 'audio/wav';
  //   } else if (pathLower.endsWith('.mp4') || pathLower.endsWith('.m4v')) {
  //     return 'video/mp4';
  //   } else if (pathLower.endsWith('.webm')) {
  //     return 'video/webm';
  //   }

  //   // For other files, use mime package
  //   return lookupMimeType(objectPath) ?? 'application/octet-stream';
  // }

  Future<String> createMultipartUploadDescription({
    required String objectPath,
  }) async {
    // final postPolicy = PostPolicy()
    //   ..setBucket(config.bucket)
    //   ..setKey(path)
    //   ..setContentLengthRange(1, 10 * 1024 * 1024)
    //   ..setExpires(
    //     DateTime.now().add(Duration(minutes: 30)),
    //   );

    // final presignedPostPolicy = await _client.presignedPostPolicy(postPolicy);

    // print(presignedPostPolicy.postURL);
    // print(presignedPostPolicy.formData);

    // return presignedPostPolicy;

    final policy = Policy.fromS3PresignedPost(
      objectPath,
      config.bucket,
      config.accessKey,
      30,
      10 * 1024 * 1024 * 1024, // 10GB
      region: config.region,
      public: true,
    );

    final key = SigV4.calculateSigningKey(
      config.secretKey,
      policy.datetime,
      config.region,
      's3',
    );
    final signature = SigV4.calculateSignature(key, policy.encode());

    var uploadDescriptionData = {
      'url': uploadUrl,
      'type': 'multipart',
      'field': 'file',
      'file-name': path.basename(objectPath),
      'request-fields': {
        'key': policy.key,
        'acl': 'public-read', //public ? 'public-read' : 'private',
        'X-Amz-Credential': policy.credential,
        'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
        'X-Amz-Date': policy.datetime,
        'Policy': policy.encode(),
        'X-Amz-Signature': signature,
      },
    };

    return jsonEncode(uploadDescriptionData);
  }

  Future<Uri> createPresignedUploadUrl({
    required String objectPath,
    Duration expiry = const Duration(minutes: 10),
  }) async {
    final url = await _client.presignedPutObject(
      config.bucket,
      objectPath,
      expires: expiry.inSeconds,
    );
    return Uri.parse(url);
  }

  Future<StatObjectResult> statObject(String objectPath) async {
    try {
      return await _client.statObject(config.bucket, objectPath);
    } catch (e) {
      throw Exception('Failed to stat object: $e');
    }
  }

  String _getPublicUrl(String objectPath) {
    return Uri(
      scheme: _scheme,
      host: config.endPoint,
      port: config.port,
      path: '${config.bucket}/$objectPath',
    ).toString();
  }

  /// The row for [objectPath], reserved or confirmed.
  ///
  /// [size] is null until the bytes are confirmed: the row is written when the
  /// server hands out the description, so that the key it issued is recorded
  /// before anything can be uploaded to it.
  DwCloudFile createCloudFile({
    required int? userId,
    required String objectPath,
    int? size,
    String? fileName,
  }) {
    return DwCloudFile(
      createdBy: userId,
      createdAt: DateTime.now(),
      publicUrl: _getPublicUrl(objectPath),
      mimeType: lookupMimeType(objectPath),
      size: size,
      fileName: fileName,
      bucket: config.bucket,
      path: objectPath,
    );
  }

  /// The longest a single caller-supplied path segment may be, in characters.
  static const _maxSegmentLength = 80;

  /// How deep a caller's folder may go. A hint for bucket layout does not need
  /// more, and a key has 1024 bytes in total to spend.
  static const _maxFolderDepth = 4;

  /// Builds the key an upload is signed for.
  ///
  /// The client names neither the key nor its last segment. It offers a
  /// [folder] and may suggest a [fileName]; both are advisory, and both are
  /// reduced to path segments that cannot escape where the server puts them.
  /// The shape is `<folder>/u<userId>/<stamp>_<name><extension>`:
  ///
  ///  * the folder keeps the bucket legible by subject — `avatars`, `chat`;
  ///  * `u<userId>` puts ownership in the key itself, so who uploaded an
  ///    object is answerable from the object rather than only from a row;
  ///  * the leaf carries a UTC timestamp and the suggested name, and that name
  ///    is also what the object downloads as: the URLs here are public and
  ///    direct, so there is no `Content-Disposition` to set and the browser
  ///    saves the file under the last path segment.
  ///
  /// [attempt] above zero appends a discriminator. The caller raises it when
  /// the unique index on `(bucket, path)` refuses the row — see
  /// `DwUploadEndpoint.getUploadDescription`.
  static String buildObjectPath({
    required int userId,
    String? folder,
    required String fileExtension,
    String? fileName,
    int attempt = 0,
    DateTime? at,
  }) {
    final name = _segment(fileName ?? '');
    final leaf = [
      _stamp((at ?? DateTime.now()).toUtc()),
      if (name.isNotEmpty) '_$name',
      if (attempt > 0) '-$attempt',
      _extension(fileExtension),
    ].join();

    return [..._folderSegments(folder), 'u$userId', leaf].join('/');
  }

  /// Splits a caller's folder into segments that cannot escape it.
  ///
  /// `.` and `..` are dropped rather than refused. The folder is a layout hint,
  /// not a security boundary — what holds the guarantee is the user segment and
  /// the server-built leaf — and refusing here would need a refusal the client
  /// can tell apart from a fault, which the framework does not have yet
  /// (dartway/dartway#132).
  static List<String> _folderSegments(String? folder) => (folder ?? '')
      .split('/')
      .map(_segment)
      .where((segment) => segment.isNotEmpty)
      .take(_maxFolderDepth)
      .toList();

  /// Reduces one caller-supplied string to a single safe path segment.
  static String _segment(String raw) {
    final cleaned = raw
        // Path separators and control characters — including the ones that
        // would arrive percent-encoded and be decoded into the key.
        .replaceAll(RegExp(r'[\\/\x00-\x1f\x7f]'), '')
        // What whitespace is left — tabs and newlines went with the control
        // characters above — becomes one dash: a key with spaces reads as %20
        // in every URL it appears in, and this key is built to be read.
        .replaceAll(RegExp(r'\s+'), '-')
        // Leading dots would make a hidden segment, and `..` a traversal.
        .replaceAll(RegExp(r'^\.+'), '');

    final runes = cleaned.runes.toList();
    return runes.length <= _maxSegmentLength
        ? cleaned
        : String.fromCharCodes(runes.take(_maxSegmentLength));
  }

  /// Normalises the extension the bytes actually have.
  ///
  /// It arrives as its own argument rather than being read off [fileName]
  /// because the two disagree: the client converts most images to JPEG on the
  /// way out, so the picked file is `.heic` while the bytes are `.jpg`. The
  /// recorded mime type is derived from this key, so taking it from the name
  /// would record the format of the file that was picked rather than of the
  /// bytes that were stored.
  static String _extension(String raw) {
    final trimmed = raw.startsWith('.') ? raw.substring(1) : raw;
    return RegExp(r'^[A-Za-z0-9]{1,10}$').hasMatch(trimmed)
        ? '.${trimmed.toLowerCase()}'
        : '';
  }

  static String _stamp(DateTime moment) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${moment.year}-${two(moment.month)}-${two(moment.day)}'
        'T${two(moment.hour)}-${two(moment.minute)}-${two(moment.second)}';
  }
}
