import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_server/generated/dw_schema.dart';
import 'package:dartway_starter_server/src/profile/profile_rows.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

/// What the app means by "the caller". The framework only knows an account;
/// the profile, and so the role, is the app's — which is why this is the
/// profile feature's: every feature asking who the caller is imports it, and
/// `core/` asks nothing about a profile.
extension ProfileCallContext on DwCallContext {
  /// The caller's profile, read once per call.
  Future<UserProfileRow> get profile => memo(#profile, () async {
    final accountId = requireAccountId;
    final profile = await db.userProfiles.findFirst(
      where: (t) => t.accountId.equals(accountId),
    );
    // Created in the same transaction as the account: absence is a broken
    // invariant, not a state a caller can be in.
    return profile ?? (throw StateError('Account $accountId has no profile'));
  });

  Future<bool> get isAdmin async => (await profile).role == UserRole.admin;
}

/// Access rules of the app, in the words handlers read.
abstract final class ProfileAccess {
  static final DwAccessRule admin = DwAccessRule.check<DwServerCall<Object?>>(
    (ctx, _) => ctx.isAdmin,
  );

  /// A profile photo: shown to anyone who sees the member, by URL — a photo is
  /// not private. Handed to the file storage by the server's library, beside
  /// every other purpose's rule.
  static final avatarUpload = DwUploadRule(
    DartwayStarterUpload.avatar,
    visibility: DwFileVisibility.public,
    maxBytes: DartwayStarterUpload.avatarMaxBytes,
    contentTypes: DartwayStarterUpload.avatarContentTypes,
    // Any member. The command that puts a photo on a profile checks it is the
    // caller's own finished upload (`ctx.files.requireOwned`).
    canUpload: (ctx) async => true,
  );
}
