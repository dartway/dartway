// ignore_for_file: invalid_use_of_internal_member

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';
import '../business/cloud_storage/dw_cloud_storage.dart';
import '../private/dw_singleton.dart';

/// Uploads, in two steps that the server owns both ends of.
///
/// The endpoint used to take a key from the caller and sign an upload for
/// exactly it, which made two things possible for any signed-in user who knew
/// somebody else's key: overwriting the object behind it, and — through
/// `verifyUpload` alone, with no upload at all — being recorded as its owner.
/// Neither left a trace: object storage reports an overwrite on neither side,
/// and the only surviving evidence was a second row for one path.
///
/// So the caller no longer names anything it could collide with. It offers a
/// folder and may suggest a file name; the server builds the key, records it,
/// and afterwards accepts only the reservation it handed out.
class DwUploadEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// How many keys are tried before the reservation gives up.
  ///
  /// A collision needs the same caller, second, folder and name at once — a
  /// double-tapped upload of one file is the realistic case — so the first
  /// discriminator almost always settles it. The limit is here because a
  /// failure that is not a collision must not loop.
  static const _maxKeyAttempts = 5;

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

  /// Reserves a key for the caller and signs an upload for exactly that key.
  ///
  /// [folder] is where in the bucket the object belongs — `avatars`,
  /// `chat/rooms` — and it is a layout hint, sanitised rather than trusted.
  /// [fileName] is a suggestion for the readable part of the key, and it is
  /// what the object will download as. [fileExtension] describes the bytes
  /// being sent, which is not always the extension of the file the user picked:
  /// the client converts most images to JPEG on the way out, and the recorded
  /// mime type is read off this key.
  Future<DwUploadTicket?> getUploadDescription(
    Session session, {
    String? folder,
    required String fileExtension,
    String? fileName,
  }) async {
    final userId = session.signedInUserProfileId;
    if (userId == null) {
      throw StateError(
        'An upload needs a signed-in user profile: the object key is built '
        'from it, and the reserved row belongs to it.',
      );
    }

    final storage = _storage;
    Object? lastError;

    for (var attempt = 0; attempt < _maxKeyAttempts; attempt++) {
      final objectPath = DwCloudStorage.buildObjectPath(
        userId: userId,
        folder: folder,
        fileExtension: fileExtension,
        fileName: fileName,
        attempt: attempt,
      );

      final DwCloudFile reserved;
      try {
        reserved = await session.db.insertRow(
          storage.createCloudFile(
            userId: userId,
            objectPath: objectPath,
            fileName: fileName,
            // Left unset on purpose: the row is a reservation until the bytes
            // are confirmed, and a row that never gets a size is an upload
            // that never happened.
            size: null,
          ),
        );
      } catch (error) {
        // The unique index on (bucket, path) is what refuses a key already
        // issued, and the next attempt carries a discriminator. A failure that
        // is not a collision fails every attempt the same way and is rethrown
        // below rather than swallowed.
        lastError = error;
        continue;
      }

      return DwUploadTicket(
        fileId: reserved.id!,
        uploadDescription: await storage.createMultipartUploadDescription(
          objectPath: objectPath,
        ),
      );
    }

    throw StateError(
      'Could not reserve an object key after $_maxKeyAttempts attempts. '
      'Last failure: $lastError',
    );
  }

  /// Confirms the bytes for a reservation this server issued to this caller.
  ///
  /// It takes the reserved row rather than an object path, so a caller has
  /// nothing to name but its own reservation. Answers `null` when the
  /// reservation is unknown, belongs to somebody else, or holds no bytes yet —
  /// the three cases a caller must not be able to tell apart.
  Future<DwCloudFile?> verifyUpload(
    Session session, {
    required int fileId,
  }) async {
    final userId = session.signedInUserProfileId;
    final reserved = await DwCloudFile.db.findById(session, fileId);

    if (userId == null || reserved == null || reserved.createdBy != userId) {
      return null;
    }

    // Confirming twice is the same answer as confirming once: a retried
    // request must not restate the size of an object that has since been
    // replaced by its owner.
    if (reserved.verifiedAt != null) return reserved;

    final int? size;
    try {
      size = (await _storage.statObject(reserved.path)).size;
    } catch (_) {
      // The object is not there — the upload never landed. That is an
      // unconfirmed reservation, not a fault.
      return null;
    }

    if (size == null || size <= 0) return null;

    reserved.size = size;
    reserved.verifiedAt = DateTime.now();

    return await session.db.updateRow<DwCloudFile>(reserved);
  }
}
