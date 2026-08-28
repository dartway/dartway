/// A user-visible handle, and the one rule that decides whether it is valid.
///
/// A worked example rather than a feature: it is here to show the shape a
/// shared rule takes, and it is meant to be replaced by a real one.
///
/// The shape is the point. Both sides need this answer — the app to refuse
/// before sending, the server to refuse whatever reaches it — and neither may
/// be the one that decides. Written twice, the two copies pass their own tests
/// and disagree in production about a value on the boundary; and the side that
/// gives way is whichever was edited last.
///
/// Note what it does not take: not a model, not a DTO, not a row. Plain values
/// in, plain values out, so the server can call it on its own generated class
/// and the app on its own.
class StarterHandle {
  const StarterHandle._();

  static const int minLength = 3;
  static const int maxLength = 30;

  static final RegExp _allowed = RegExp(r'^[a-z0-9_]+$');

  /// The form a handle is stored and compared in.
  ///
  /// Comparison happens on this form on both sides, so `Ann` and `ann` cannot
  /// become two accounts.
  static String normalise(String raw) => raw.trim().toLowerCase();

  /// Why [raw] is not a usable handle, or null when it is.
  ///
  /// A reason rather than a bool: the app has to show something, and a message
  /// invented separately on each side is two messages for one rule.
  static String? reasonInvalid(String raw) {
    final handle = normalise(raw);
    if (handle.length < minLength) {
      return 'A handle needs at least $minLength characters.';
    }
    if (handle.length > maxLength) {
      return 'A handle may be at most $maxLength characters.';
    }
    if (!_allowed.hasMatch(handle)) {
      return 'A handle may hold lowercase letters, digits and underscores only.';
    }
    return null;
  }

  static bool isValid(String raw) => reasonInvalid(raw) == null;
}
