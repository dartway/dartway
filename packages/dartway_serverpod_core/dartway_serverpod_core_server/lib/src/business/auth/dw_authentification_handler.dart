import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:dartway_serverpod_core_server/src/business/auth/dw_auth_utils.dart';
import 'package:serverpod/serverpod.dart';

/// The [AuthenticationHandler], uses the auth_key table from the
/// database to authenticate a user.
Future<AuthenticationInfo?> dwAuthenticationHandler(
  Session session,
  String key,
) async {
  Session? tempSession;
  try {
    // Get the secret and user id
    var parts = key.split(':');
    if (parts.length < 2) return null;
    var keyIdStr = parts[0];
    var keyId = int.tryParse(keyIdStr);
    if (keyId == null) return null;
    var secret = parts[1];

    // Get the authentication key from the database
    tempSession = await session.serverpod.createSession(enableLogging: false);

    var authKey = await DwAuthKey.db.findById(tempSession, keyId);

    if (authKey == null) return null;

    var expectedHash = DwAuthUtils.hashAuthKey(secret);

    if (authKey.hash != expectedHash) return null;

    return AuthenticationInfo(
      authKey.userId.toString(),
      const <Scope>{},
      authId: keyIdStr,
    );
  } catch (exception) {
    session.log(
      'Authentication failed (type: ${exception.runtimeType})',
      level: LogLevel.warning,
    );
    return null;
  } finally {
    if (tempSession != null) {
      try {
        await tempSession.close();
      } catch (exception) {
        session.log(
          'Authentication session cleanup failed '
          '(type: ${exception.runtimeType})',
          level: LogLevel.warning,
        );
      }
    }
  }
}
