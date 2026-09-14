import 'package:dartway_core_shared/dartway_core_shared.dart';

/// The one form a sign-in identifier is stored and compared in, for both
/// sides.
///
/// The app normalizes what a person typed before it asks for a code, and the
/// server's `DwAuthConfig.normalize` is this same function. Written twice, the
/// two copies drift: the app would send `79991234567` while an administrator
/// declared as `+7 999 123-45-67` stayed with its spaces — and since signing in
/// with an unknown identifier creates an account, the person would get a second,
/// empty one instead of a refusal.
abstract final class AuthIdentifier {
  /// Which kind [identifier] is. The at sign decides, and nothing else: this
  /// sorts, it does not validate — [normalize] does, and the code that arrives
  /// proves the rest.
  static DwIdentifierKind kindOf(String identifier) => identifier.contains('@')
      ? DwIdentifierKind.email
      : DwIdentifierKind.phone;

  /// [raw] in its stored form, or `null` when it is not an identifier of
  /// [kind]: an address without a domain, a number shorter than ten or longer
  /// than fifteen digits, a number typed as an e-mail.
  ///
  /// An e-mail is trimmed and lower-cased (`Ann@Example.COM` and
  /// `ann@example.com` are one person); a phone keeps its digits only, with a
  /// leading trunk `8` of an eleven-digit number read as the country code `7`.
  ///
  /// Idempotent: applied to its own result it changes nothing.
  static String? normalize(DwIdentifierKind kind, String raw) {
    final trimmed = raw.trim();
    if (kindOf(trimmed) != kind) return null;
    return switch (kind) {
      DwIdentifierKind.email => switch (trimmed.toLowerCase()) {
        final email when _email.hasMatch(email) => email,
        _ => null,
      },
      DwIdentifierKind.phone => switch (_digits(trimmed)) {
        final digits when digits.length >= 10 && digits.length <= 15 => digits,
        _ => null,
      },
    };
  }

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String _digits(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length == 11 && digits.startsWith('8')
        ? '7${digits.substring(1)}'
        : digits;
  }
}
