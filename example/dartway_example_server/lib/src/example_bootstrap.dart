import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../generated/dw_schema.dart';
import 'entities/people.dart';

/// What this club means by "an administrator", for the framework's
/// [DwFirstAdministrator] step.
///
/// The framework brings the account named by `DW_ADMIN_IDENTIFIER` into
/// existence at every start; the role on the profile row is the project's
/// half — here the staff role that opens the admin panel.
abstract final class ExampleBootstrap {
  /// Grants [accountId] the admin role, in the startup step's transaction.
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
