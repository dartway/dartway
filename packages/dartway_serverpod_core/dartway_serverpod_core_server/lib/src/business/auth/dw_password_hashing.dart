import 'package:bcrypt/bcrypt.dart';

/// Reads one stored password-hash format.
///
/// A verifier is **read-only** by design: it exists so that users whose
/// passwords were hashed somewhere else — a legacy backend the app is migrating
/// off — can sign in at all. It never produces a hash. DartWay writes exactly
/// one format, the one of [DwAuthConfig.passwordHasher], and rewrites every
/// legacy hash into it on the user's next successful sign-in.
///
/// Register legacy formats through [DwAuthConfig.legacyPasswordVerifiers]. They
/// are the app's code, not the framework's: only the app knows what its old
/// system did.
abstract class DwPasswordVerifier {
  const DwPasswordVerifier();

  /// Whether [storedHash] is written in this verifier's format.
  ///
  /// A cheap shape check (prefix, length, separator count) — it decides *who
  /// reads* the hash, never whether the password is right. Return `false` when
  /// unsure: an unrecognised hash fails the sign-in, it does not crash it.
  bool matches(String storedHash);

  /// Whether [password] is the one behind [storedHash].
  ///
  /// Must not throw on a hash it accepted in [matches]. DartWay treats a throw
  /// as a failed verification rather than letting it reach the client, but a
  /// verifier throwing on its own format has a bug.
  Future<bool> verify(String password, String storedHash);
}

/// The format DartWay writes. Exactly one is active, and it can also read what
/// it wrote — hence a verifier that additionally hashes.
abstract class DwPasswordHasher extends DwPasswordVerifier {
  const DwPasswordHasher();

  /// Hashes [password] for storage. Called on registration, on password change,
  /// and when a legacy hash is upgraded after a successful sign-in.
  Future<String> hash(String password);
}

/// DartWay's default hasher: bcrypt with a per-password salt.
///
/// Deliberately slow — that is the point of a password hash. Do not replace it
/// with a general-purpose digest (SHA-256 and friends) to "speed up" login: a
/// fast hash is a fast offline attack on your users' passwords.
class DwBcryptPasswordHasher extends DwPasswordHasher {
  const DwBcryptPasswordHasher();

  /// bcrypt names its own scheme in the first four bytes of the hash.
  @override
  bool matches(String storedHash) =>
      storedHash.startsWith(r'$2a$') ||
      storedHash.startsWith(r'$2b$') ||
      storedHash.startsWith(r'$2y$');

  @override
  Future<bool> verify(String password, String storedHash) async =>
      BCrypt.checkpw(password, storedHash);

  @override
  Future<String> hash(String password) async =>
      BCrypt.hashpw(password, BCrypt.gensalt());
}
