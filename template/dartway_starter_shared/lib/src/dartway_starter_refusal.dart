import 'package:dartway_core_shared/dartway_core_shared.dart';

/// Why the server refuses. Codes only: the app renders every one of them
/// through its string catalogue (`refusal_text.dart`), and a code added here
/// does not compile there until it has a text.
enum DartwayStarterRefusal with DwRefusalCodes {
  /// Signing up creates the account, and the terms were not accepted with the
  /// code. The code itself was right and stays usable: the app asks for the
  /// consent and verifies the same code again.
  consentsRequired,

  /// Signing up is switched off in the app settings (`signUpEnabled`). An
  /// existing account still signs in.
  signUpClosed,

  /// A profile's name cannot be blank.
  firstNameRequired,

  /// A setting key the app does not declare.
  settingKeyUnknown,

  /// An admin changing their own role: the panel would lock its only way back
  /// out from under them. Another admin does it.
  ownRoleLocked,
}
