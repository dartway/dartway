/// The keys of `DwVerifyCode.registration` the app sends with a code. The
/// server reads them only when the code creates the account; both sides name
/// them here, once.
abstract final class RegistrationKeys {
  /// The terms of use and the privacy policy — `'true'` when accepted. A
  /// sign-up without it is refused with `consentsRequired` and creates
  /// nothing.
  static const String terms = 'terms';

  /// News and offers, optional — `'true'` when wanted.
  static const String marketing = 'marketing';

  /// The name, when the app collected one before the code.
  static const String firstName = 'firstName';
}
