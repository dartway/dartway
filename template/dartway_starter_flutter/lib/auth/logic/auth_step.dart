/// Steps of the sign-in flow. Titles live in the localizations
/// (`authStepTitle`), keyed by the step name.
///
/// There is no separate registration: a code verified for an identifier the
/// server does not know creates the account. What a new account needs — the
/// terms accepted, a name — is asked only when the server says so
/// (`consentsRequired`), after the right code, with the same code.
enum AuthStep {
  identifier(previousStep: null),
  code(previousStep: identifier),
  consents(previousStep: code);

  const AuthStep({required this.previousStep});

  final AuthStep? previousStep;
}
