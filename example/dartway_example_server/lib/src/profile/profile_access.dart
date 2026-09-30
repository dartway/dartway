import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/profile/profile_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_server/dartway_push_server.dart';

/// What the club means by "the caller". The framework only knows an account;
/// the profile, and so the role, is the example's — which is why this is the
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

  Future<bool> get isStaff async => (await profile).role != UserRole.client;

  Future<bool> get isAdmin async => (await profile).role == UserRole.admin;
}

/// Access rules of the example, in the words handlers read.
abstract final class ProfileAccess {
  static final DwAccessRule staff = DwAccessRule.check<DwServerCall<Object?>>(
    (ctx, _) => ctx.isStaff,
  );

  static final DwAccessRule admin = DwAccessRule.check<DwServerCall<Object?>>(
    (ctx, _) => ctx.isAdmin,
  );

  /// A member's photo: public, read by URL. Handed to the file storage by the
  /// server's library, beside every other purpose's rule.
  static final avatarUpload = DwUploadRule(
    DartwayExampleUpload.avatar,
    visibility: DwFileVisibility.public,
    maxBytes: 5 * 1024 * 1024,
    contentTypes: {'image/jpeg', 'image/png', 'image/webp'},
    // Any member. The handler that puts a photo on a profile checks it is the
    // caller's own (`ctx.files.requireOwned`).
    canUpload: (ctx) async => true,
  );

  /// Who a push notice reaches, by its category: news only members who agreed
  /// to marketing — a column of the profile, so the rule is the profile's. Runs
  /// when deliveries fall due, once per batch, with one query. Handed to
  /// `AppPush.module` by the server's library.
  static Future<Map<int, DwPushDecision>> pushEligibility(
    DwCallContext ctx,
    DwPushNotice notice,
    List<int> accountIds,
  ) async {
    switch (notice.categoryIn(DartwayExamplePushCategory.values)) {
      case DartwayExamplePushCategory.news:
        final agreed = {
          for (final profile in await ctx.db.userProfiles.find(
            where: (t) =>
                t.accountId.inList(accountIds) &
                t.agreedForMarketing.equals(true),
          ))
            profile.accountId,
        };
        return {
          for (final id in accountIds)
            if (!agreed.contains(id)) id: DwPushDecision.skip,
        };
      case DartwayExamplePushCategory.bookingReminder || null:
        return const {};
    }
  }
}
