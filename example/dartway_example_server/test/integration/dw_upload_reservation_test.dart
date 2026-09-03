// The endpoint is not part of the core's public API and should not become so
// for a test's sake — Serverpod mounts it, applications never name it. Reaching
// into `src/` is the narrower of the two compromises.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_serverpod_core_server/src/endpoints/dw_upload_endpoint.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../support/test_database.dart';
import 'test_tools/serverpod_test_tools.dart';

/// An upload is two calls, and the gap between them used to be open: the second
/// one took an object path from the caller, stated it, and recorded the caller
/// as its owner. So any signed-in user who knew somebody else's key could claim
/// the object behind it — without uploading a byte.
///
/// The endpoint now confirms a reservation rather than a path, and these are
/// the assertions that need a database: that a reservation belongs to one
/// caller, and that the ledger refuses to issue one key twice.
void main() {
  // Before anything registers: a missing database is knowable here, and
  // `withServerpod` silences the output that would have said so.
  requireTestDatabase();

  withServerpod('Given a reservation owned by one user', (
    sessionBuilder,
    endpoints,
  ) {
    const owner = 4001;
    const stranger = 4002;

    Session sessionAs(int userProfileId) => sessionBuilder
        .copyWith(
          authentication: AuthenticationOverride.authenticationInfo(
            '$userProfileId',
            {},
          ),
        )
        .build();

    Future<DwCloudFile> reserve(
      Session session, {
      required String path,
      int? createdBy = owner,
      DateTime? verifiedAt,
    }) => session.db.insertRow(
      DwCloudFile(
        createdBy: createdBy,
        bucket: 'uploads',
        path: path,
        publicUrl: 'http://localhost:8100/uploads/$path',
        createdAt: DateTime.now().toUtc(),
        verifiedAt: verifiedAt,
      ),
    );

    test('its owner is answered with the row', () async {
      // The control for the refusals below: without it, an endpoint that
      // always answered null would pass every one of them.
      final session = sessionAs(owner);
      final reserved = await reserve(
        session,
        path: 'avatars/u$owner/verified.jpg',
        verifiedAt: DateTime.now().toUtc(),
      );

      final answer = await DwUploadEndpoint().verifyUpload(
        sessionAs(owner),
        fileId: reserved.id!,
      );

      expect(answer?.id, reserved.id);
    });

    test('a stranger is refused it', () async {
      final reserved = await reserve(
        sessionAs(owner),
        path: 'avatars/u$owner/claimed.jpg',
        verifiedAt: DateTime.now().toUtc(),
      );

      // Verified and owned by somebody else: the case the old shape recorded
      // as a second row on one object, silently.
      expect(
        await DwUploadEndpoint().verifyUpload(
          sessionAs(stranger),
          fileId: reserved.id!,
        ),
        isNull,
      );
    });

    test('an unclaimed reservation belongs to nobody in particular', () async {
      // `createdBy` is nullable in the model. A row without an owner must not
      // become everybody's.
      final reserved = await reserve(
        sessionAs(owner),
        path: 'avatars/orphan.jpg',
        createdBy: null,
        verifiedAt: DateTime.now().toUtc(),
      );

      expect(
        await DwUploadEndpoint().verifyUpload(
          sessionAs(owner),
          fileId: reserved.id!,
        ),
        isNull,
      );
    });

    test('a reservation that does not exist is refused too', () async {
      expect(
        await DwUploadEndpoint().verifyUpload(
          sessionAs(owner),
          fileId: 987654321,
        ),
        isNull,
      );
    });

    test('the ledger refuses to issue one key twice', () async {
      // This is what the reservation retry in `getUploadDescription` stands on:
      // without the unique index the second row is written, both callers upload
      // to one key, and the first object stops existing with nothing to show
      // for it.
      final session = sessionAs(owner);
      const path = 'avatars/u4001/2026-09-03T14-22-07_photo.jpg';

      await reserve(session, path: path);

      expect(
        () => reserve(session, path: path, createdBy: stranger),
        throwsA(anything),
      );
    });
  });
}
