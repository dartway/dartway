// ignore_for_file: invalid_use_of_internal_member

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import '../business/cloud_storage/dw_cloud_storage.dart';
import '../private/dw_singleton.dart';

class DwUploadEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// The configured storage, or a stated refusal.
  ///
  /// Uploads are optional: an app that never configured `cloudStorageConfig`
  /// still has this endpoint mounted. Reaching for `dw.cloudStorage!` there used
  /// to fail on a null check, which says nothing about what is missing — the
  /// same silence a CRUD call without a config would have given before
  /// `notConfigured` existed.
  DwCloudStorage get _storage {
    final storage = dw.cloudStorage;
    if (storage == null) {
      throw StateError(
        'Cloud storage is not configured: uploads are unavailable. '
        'Pass cloudStorageConfig to DwCore.init (see DwCloudStorageConfig) '
        'and provide the dwCloudStorage* keys for this run mode.',
      );
    }
    return storage;
  }

  Future<String?> getUploadDescription(
    Session session, {
    required String path,
  }) async {
    final t = await _storage.createMultipartUploadDescription(
      objectPath: path,
    );

    // final t11 = jsonDecode(t);

    // final t2 = await session.storage.createDirectFileUploadDescription(
    //   storageId: 'public',
    //   path: path,
    // );

    // final t3 = jsonDecode(t2.toString());

    return t;
  }

  // Future<String?> getMultipartUploadDescription(
  //   Session session, {
  //   required String path,
  // }) async {
  //   return await dw.cloudStorage!
  //       .createMultipartUploadDescription(path: path);
  // }

  Future<DwCloudFile?> verifyUpload(
    Session session, {
    required String path,
  }) async {
    final info = await _storage.statObject(path);

    if (info.size == null || info.size! <= 0) return null;

    final file = await session.db.insertRow(
      _storage.createCloudFile(
        userId: await session.currentUserProfileId,
        objectPath: path,
        size: info.size!,
      ),
    );

    return file;
  }
}
