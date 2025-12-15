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
      // port: config.port,
      useSSL: true,
      accessKey: config.accessKey,
      secretKey: config.secretKey,
    );
  }

  String get uploadUrl => 'https://${config.endPoint}/${config.bucket}';

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
      scheme: 'https',
      host: config.endPoint,
      path: '${config.bucket}/$objectPath',
    ).toString();
  }

  DwCloudFile createCloudFile({
    required int? userId,
    required String objectPath,
    required int size,
  }) {
    return DwCloudFile(
      createdBy: userId,
      createdAt: DateTime.now(),
      publicUrl: _getPublicUrl(objectPath),
      mimeType: lookupMimeType(objectPath),
      size: size,
      bucket: config.bucket,
      path: objectPath,
    );
  }
}
