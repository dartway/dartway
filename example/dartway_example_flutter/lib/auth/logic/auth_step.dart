/// Steps of the auth flow. Titles live in the localizations
/// (`authStepTitle`), keyed by the step name.
enum AuthStep {
  greeting(previousStep: null),
  registration(previousStep: greeting),
  login(previousStep: greeting),
  registrationConfirmation(previousStep: registration),
  loginConfirmation(previousStep: login);

  final AuthStep? previousStep;

  const AuthStep({required this.previousStep});

  AuthStep get requestOtpNextStep => switch (this) {
        AuthStep.registration => AuthStep.registrationConfirmation,
        AuthStep.login => AuthStep.loginConfirmation,
        _ => throw StateError(
            'Incorrect AuthStep $this while requestOtp is called'),
      };
}
