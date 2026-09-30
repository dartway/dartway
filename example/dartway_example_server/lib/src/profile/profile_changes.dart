import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/generated/dw_schema.dart';
import 'package:dartway_example_server/src/profile/profile_publications.dart';
import 'package:dartway_example_server/src/profile/profile_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// Every way a profile row is written from outside the profile feature — the
/// one place its invariants are kept: a profile starts with its conditions
/// accepted, carries the phone the member signs in with, and a member who
/// left keeps nothing of the person. Another feature never writes
/// `user_profile` itself (`foreignRowWrite`); it calls one of these.
abstract final class ProfileChanges {
  /// The profile a new account starts with, its conditions accepted as of
  /// `ctx.now`. Called by the sign-in hook, and by tools that create accounts
  /// without a running server (the dev seed), so both create the same row.
  static Future<UserProfileRow> create(
    DwCallContext ctx,
    int accountId,
    String phone,
    Map<String, String> registration,
  ) => ctx.db.userProfiles.insert(
    NewUserProfileRow(
      accountId: accountId,
      phone: phone,
      firstName: registration['firstName']?.trim() ?? '',
      agreedForMarketing: registration['marketing'] == 'true',
      conditionsAcceptedAt: ctx.now,
    ),
  );

  /// [row] given [role], locked by the caller, and published to its owner and
  /// the admins. Answers the profile as clients see it.
  static Future<UserProfile> changeRole(
    DwCallContext ctx,
    UserProfileRow row,
    UserRole role,
  ) async => ProfilePublications.profile(
    ctx,
    await ctx.db.userProfiles.update(row.copyWith(role: role)),
  );

  /// The phone [row] shows, after its member changed the one they sign in
  /// with; published to its owner and the admins.
  static Future<UserProfile> changePhone(
    DwCallContext ctx,
    UserProfileRow row,
    String phone,
  ) async => ProfilePublications.profile(
    ctx,
    await ctx.db.userProfiles.update(row.copyWith(phone: phone)),
  );

  /// A member who left: the row stays, because other people's content points
  /// at it, and keeps nothing of the person — name, phone, photo, the code
  /// they signed in with. Published to the admins' members table.
  static Future<UserProfile> tombstone(
    DwCallContext ctx,
    UserProfileRow row,
  ) async => ProfilePublications.tombstone(
    ctx,
    await ctx.db.userProfiles.update(
      row.copyWith(
        firstName: '',
        lastName: const DwFieldPatch.clear(),
        phone: '',
        imageUrl: const DwFieldPatch.clear(),
        gender: const DwFieldPatch.clear(),
        testVerificationCode: const DwFieldPatch.clear(),
        agreedForMarketing: false,
        deletedAt: DwFieldPatch.set(ctx.now),
      ),
    ),
  );

  /// Grants [accountId] the admin role — what this club means by "an
  /// administrator" for the framework's [DwFirstAdministrator] step, which
  /// brings the account into existence and hands it here, in the step's
  /// transaction.
  static Future<void> grantAdmin(DwCallContext ctx, int accountId) async {
    final profile = (await ctx.db.userProfiles.findFirst(
      where: (t) => t.accountId.equals(accountId),
    ))!;
    if (profile.role == UserRole.admin) return;
    await ctx.db.userProfiles.update(
      profile.copyWith(
        role: UserRole.admin,
        firstName: profile.firstName.isEmpty ? 'Admin' : null,
      ),
    );
    ctx.log.info('granted the admin role to account $accountId');
  }
}
