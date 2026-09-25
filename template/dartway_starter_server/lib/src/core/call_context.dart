import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import '../../generated/dw_schema.dart';
import '../profile/profile_rows.dart';

/// What the app means by "the caller". The framework only knows an account;
/// the profile, and so the role, is the app's.
extension AppCallContext on DwCallContext {
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
abstract final class AppAccess {
  static final DwAccessRule admin = DwAccessRule.check<DwServerCall<Object?>>(
    (ctx, _) => ctx.isAdmin,
  );
}
