// ignore_for_file: invalid_use_of_internal_member

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import '../private/dw_singleton.dart';

class DwUploadEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<String?> getUploadDescription(
    Session session, {
    required String path,
  }) async {
    final t = await dw.cloudStorage!.createMultipartUploadDescription(
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
    final info = await dw.cloudStorage!.statObject(path);

    if (info.size == null || info.size! <= 0) return null;

    final file = await session.db.insertRow(
      dw.cloudStorage!.createCloudFile(
        userId: await session.currentUserProfileId,
        objectPath: path,
        size: info.size!,
      ),
    );

    return file;
  }
}
