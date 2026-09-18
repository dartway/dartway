/// How the app names the signed-in user to Studio.
///
/// The framework knows the profile model, never which of its fields means
/// "who this is" — a project authenticates by phone, by email or by something
/// of its own, and calls people by a first name, a full name or a nickname.
/// That choice is the one thing `DwStudioBinding` asks the app for.
class DwStudioUser {
  const DwStudioUser({this.identifier, this.label});

  /// The identifier in the form the app's own auth uses (a phone, an email).
  /// Studio matches it against the personas configured in the project — the
  /// app knows nothing about personas.
  final String? identifier;

  /// What to call this user on screen: a name, a nickname, an email.
  final String? label;
}
