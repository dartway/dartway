import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import 'dw_auth_utils.dart';
import '../../private/dw_singleton.dart';

class DwAuth<UserProfileClass extends TableRow> {
  final DwAuthConfig<UserProfileClass> config;

  DwAuth({required this.config});

  /// Verifies [password] against the hash stored for [userId], and upgrades that
  /// hash to [DwAuthConfig.passwordHasher]'s format when it was written by a
  /// legacy verifier.
  ///
  /// The upgrade is what makes a migration off another backend finite: a hash is
  /// one-way, so the only moment a legacy password can be re-hashed is the
  /// moment its owner types it. Every migrated user pays the legacy path exactly
  /// once.
  Future<bool> verifyPassword(
    Session session, {
    required int userId,
    required String password,
    required String storedHash,
  }) async {
    final hasher = config.passwordHasher;

    if (hasher.matches(storedHash)) {
      return _verify(session, hasher, password, storedHash);
    }

    for (final verifier in config.legacyPasswordVerifiers) {
      if (!verifier.matches(storedHash)) continue;

      if (!await _verify(session, verifier, password, storedHash)) return false;

      await _upgradeStoredHash(session, userId: userId, password: password);
      return true;
    }

    // Nobody can read this hash. That is a misconfiguration, not a wrong
    // password — the user is rejected either way, but the server must say so:
    // silently answering "wrong password" to every migrated user is exactly the
    // bug this whole mechanism exists to prevent.
    session.log(
      'No password verifier matches the stored hash for userId=$userId — '
      'is the old format registered in DwAuthConfig.legacyPasswordVerifiers?',
      level: LogLevel.error,
    );
    return false;
  }

  /// A verifier that throws is a verifier that failed. A malformed row in
  /// `dw_user_password` must not turn a login into a 500.
  Future<bool> _verify(
    Session session,
    DwPasswordVerifier verifier,
    String password,
    String storedHash,
  ) async {
    try {
      return await verifier.verify(password, storedHash);
    } catch (e, st) {
      session.log(
        '${verifier.runtimeType} threw while verifying a hash it claimed to '
        'read',
        level: LogLevel.error,
        exception: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Rewrites the hash in the active format after a legacy password checked out.
  ///
  /// Runs outside any enclosing transaction on purpose: the password was
  /// correct, so the upgrade is legitimate whatever happens to the sign-in that
  /// follows — and a failed upgrade must never cost the user their login. Worst
  /// case it is retried the next time they sign in.
  Future<void> _upgradeStoredHash(
    Session session, {
    required int userId,
    required String password,
  }) async {
    try {
      await setUserPassword(session, userId: userId, newPassword: password);
      session.log(
        'Upgraded a legacy password hash for userId=$userId',
        level: LogLevel.info,
      );
    } catch (e, st) {
      session.log(
        'Failed to upgrade the legacy password hash for userId=$userId; the '
        'sign-in stands and the upgrade will be retried on the next one',
        level: LogLevel.warning,
        exception: e,
        stackTrace: st,
      );
    }
  }

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

      // `newPasswordHash` is the import path: a migration seeds hashes it cannot
      // reverse. Everything else is hashed by the active hasher.
      final newHash =
          newPasswordHash ?? await config.passwordHasher.hash(newPassword!);

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
      final userProfile = await dw.getUserProfile(session, userId);
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
          userId.toString(),
          const <Scope>{},
          authId: '${insertedAuthKey.id}',
        ),
      );
    }
    return insertedAuthKey;
  }
}
