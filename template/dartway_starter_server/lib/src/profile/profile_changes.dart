import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_server/generated/dw_schema.dart';
import 'package:dartway_starter_server/src/profile/profile_publications.dart';
import 'package:dartway_starter_server/src/profile/profile_rows.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

/// Every way a profile row is written from outside the profile feature — the
/// one place its invariants are kept: a profile starts with the terms its
/// sign-up accepted, a role change is published to everyone who shows the
/// profile. Another feature never writes `user_profile` itself
/// (`foreignRowWrite`); it calls one of these.
abstract final class ProfileChanges {
  /// The profile a new account starts with, in the account's transaction.
  ///
  /// A sign-up is refused, and nothing is created, while sign-up is switched off
  /// in the settings ([DartwayStarterRefusal.signUpClosed]) or without the terms
  /// accepted ([DartwayStarterRefusal.consentsRequired]) — the app then asks for
  /// them and verifies the same code again. An account made by a tool
  /// ([DwToolOrigin]: the admin bootstrap, the dev seed) accepts nothing on
  /// anyone's behalf: its `termsAcceptedAt` stays empty.
  static Future<UserProfileRow> create(
    DwCallContext ctx,
    int accountId,
    DwAccountOrigin origin,
  ) async {
    final now = ctx.now;
    switch (origin) {
      case DwSignInOrigin(:final registration):
        if (!(await ctx.settings.read<AppSettings>()).signUpEnabled) {
          ctx.refuse(DartwayStarterRefusal.signUpClosed, field: 'identifier');
        }
        if (registration[RegistrationKeys.terms] != 'true') {
          ctx.refuse(DartwayStarterRefusal.consentsRequired, field: 'consents');
        }
        return ctx.db.userProfiles.insert(
          NewUserProfileRow(
            accountId: accountId,
            firstName: registration[RegistrationKeys.firstName]?.trim() ?? '',
            agreedForMarketing:
                registration[RegistrationKeys.marketing] == 'true',
            termsAcceptedAt: now,
            createdAt: now,
          ),
        );
      case DwToolOrigin():
        return ctx.db.userProfiles.insert(
          NewUserProfileRow(accountId: accountId, createdAt: now),
        );
    }
  }

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

  /// Grants [accountId] the admin role — what this project means by "an
  /// administrator" for the framework's [DwFirstAdministrator] step, which
  /// brings the account into existence and hands it here, in the step's
  /// transaction.
  ///
  /// Idempotent, and quiet when there was nothing to do: the step already
  /// says at every start who the administrator is, and a second line saying
  /// the role was already there is noise in every log of every restart.
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
