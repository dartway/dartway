import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import 'dw_auth_utils.dart';

class DwAuth<UserProfileClass extends TableRow> {
  final DwAuthConfig config;

  DwAuth({
    required this.config,
  });

  Future<bool> setUserPassword(
    Session session, {
    required int userId,
    String? newPassword,
    String? newPasswordHash,
  }) async {
    try {
      if (newPassword == null && newPasswordHash == null) {
        throw ArgumentError(
          'Either password or passwordHash must be provided.',
        );
      }

      if (newPassword != null && newPasswordHash != null) {
        throw ArgumentError('Cannot provide both password and passwordHash.');
      }

      // Check if password record already exists
      final existing = await DwUserPassword.db.findFirstRow(
        session,
        where: (t) => t.userId.equals(userId),
      );

      final newHash = newPasswordHash ?? DwAuthUtils.hashPassword(newPassword!);

      if (existing != null) {
        session.log(
          'Updating password for userId=$userId',
          level: LogLevel.info,
        );

        final updated = existing.copyWith(
          passwordHash: newHash,
          updatedAt: DateTime.now(),
        );

        await DwUserPassword.db.updateRow(session, updated);
        return true;
      }

      // Check if user profile exists (without FK)
      final userProfile = await DwCore.instance.getUserProfile(session, userId);
      if (userProfile == null) {
        throw StateError('UserProfile with id=$userId not found.');
      }

      // Create new password record
      final newUserPassword = DwUserPassword(
        userId: userId,
        passwordHash: newHash,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      session.log('Creating password for userId=$userId', level: LogLevel.info);
      await DwUserPassword.db.insertRow(session, newUserPassword);

      return true;
    } catch (e, st) {
      session.log(
        'registerUserPassword() failed for userId=$userId: $e',
        level: LogLevel.error,
        exception: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<DwAuthKey> signInUser(
    Session session,
    int userId, {
    bool updateSession = true,
    bool skipTriggers = false,
  }) async {
    var key = DwAuthUtils.generateRandomString();
    var hash = DwAuthUtils.hashAuthKey(key);

    if (config.onSignInTrigger != null) {
      final existingAuthKeys = await DwAuthKey.db.find(
        session,
        where: (t) => t.userId.equals(userId),
      );

      await config.onSignInTrigger!(
        session,
        userId: userId,
        isFirstSignIn: existingAuthKeys.isEmpty,
      );
    }

    var authKey = DwAuthKey(userId: userId, hash: hash, key: key);

    var insertedAuthKey = await DwAuthKey.db.insertRow(session, authKey);

    if (updateSession) {
      session.updateAuthenticated(
        AuthenticationInfo(
          userId,
          const <Scope>{},
          authId: '${insertedAuthKey.id}',
        ),
      );
    }
    return insertedAuthKey;
  }
}
