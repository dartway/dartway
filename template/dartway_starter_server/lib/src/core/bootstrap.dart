import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import '../../generated/dw_schema.dart';
import '../profile/profile_rows.dart';

/// What this project means by "an administrator", for the framework's
/// [DwFirstAdministrator] step.
///
/// The framework brings the account named by `DW_ADMIN_IDENTIFIER` into
/// existence at every start — accounts and identities are its own — and this
/// is the half that is the project's: a role on the profile row.
abstract final class AppBootstrap {
  /// Grants [accountId] the admin role, in the startup step's transaction.
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
