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

  /// Two of these are the same user when they say the same thing.
  ///
  /// Not decoration: the app hands Studio a `ProviderListenable` and the
  /// README builds it with `select((profile) => DwStudioUser(...))`, which
  /// compares what it produces by equality. Without this, every rebuild of
  /// the profile is a new user, the session is reported again and the feature
  /// tree is rescanned — for a value that did not change.
  @override
  bool operator ==(Object other) =>
      other is DwStudioUser &&
      other.identifier == identifier &&
      other.label == label;

  @override
  int get hashCode => Object.hash(identifier, label);

  @override
  String toString() => 'DwStudioUser($identifier, $label)';
}
