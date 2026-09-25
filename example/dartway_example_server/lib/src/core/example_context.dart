import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../../generated/dw_schema.dart';
import '../profile/profile_rows.dart';

/// What the club means by "the caller". The framework only knows an account;
/// the profile, and so the role, is the example's.
extension ExampleCallContext on DwCallContext {
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
abstract final class ExampleAccess {
  static final DwAccessRule staff = DwAccessRule.check<DwServerCall<Object?>>(
    (ctx, _) => ctx.isStaff,
  );

  static final DwAccessRule admin = DwAccessRule.check<DwServerCall<Object?>>(
    (ctx, _) => ctx.isAdmin,
  );
}
