import 'package:serverpod/serverpod.dart';

import '../../private/dw_singleton.dart';
import '../dw_recurring_future_call.dart';

/// Deletes auth keys whose user profile is gone.
///
/// The safety net under [DwAuth.revokeAuthKeys], not a replacement for it. An
/// app is supposed to revoke when an account ends, but revoking is a line
/// somebody has to remember to write, and the cost of forgetting it is a token
/// that works forever: keys carry no expiry, and `DwAuthKey.userId` is a plain
/// int — the profile table belongs to the app, so no foreign key can cascade
/// from it.
///
/// This is also where an aliveness check belongs. Until 0.3.0 one happened by
/// accident on the hot path: reading the caller's id fetched the whole profile
/// row, so a deleted profile read back as "not signed in" — correct, and paid
/// for with a database round trip on **every request**. Here the same fact
/// costs one statement per [interval].
///
/// Register it alongside the app's own jobs:
///
/// ```dart
/// await DwRecurringJobs.startAll(pod, [
///   DwOrphanedAuthKeyCleanup(),
///   ...
/// ]);
/// ```
///
/// A ban or a deactivation leaves the profile row in place, so nothing here
/// sees it — that case only ends when the app calls [DwAuth.revokeAuthKeys].
class DwOrphanedAuthKeyCleanup extends DwRecurringFutureCall {
  DwOrphanedAuthKeyCleanup({this.interval = const Duration(hours: 1)});

  @override
  String get name => 'dwOrphanedAuthKeyCleanup';

  /// How stale an orphaned key may get. This is the window an app that forgot
  /// to revoke leaves open, so shorten it if that worries you more than the
  /// statement costs.
  @override
  final Duration interval;

  @override
  Future<void> run(Session session) async {
    // Expressed as raw SQL because the condition spans two tables, and the
    // second one is the app's — its name is only known at runtime, from
    // `DwCore.init`. It is our own configuration rather than anything a caller
    // sends, but it is still interpolated into a statement, so it is checked
    // against the identifier grammar before it goes in.
    final profileTable = dw.userProfileTable.tableName;

    if (!_isSafeIdentifier(profileTable)) {
      throw StateError(
        'Refusing to build a statement with the user profile table name '
        '"$profileTable": it is not a plain SQL identifier.',
      );
    }

    final deleted = await session.db.unsafeExecute(
      'DELETE FROM "dw_auth_key" WHERE "userId" NOT IN '
      '(SELECT "id" FROM "$profileTable")',
    );

    if (deleted > 0) {
      session.log(
        'Deleted $deleted orphaned auth key(s): the user profile no longer '
        'exists. Whoever removed those profiles should be calling '
        'dw.auth.revokeAuthKeys — until this ran, their tokens still worked.',
        level: LogLevel.warning,
      );
    }
  }

  static final _identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  static bool _isSafeIdentifier(String value) => _identifier.hasMatch(value);
}
