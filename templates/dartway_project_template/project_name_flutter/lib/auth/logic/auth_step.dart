import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';

enum AuthStep {
  greeting(
    title: 'Welcome!',
    previousStep: null,
  ),
  registration(
    title: 'Step 1 of 3',
    previousStep: greeting,
  ),
  login(
    title: 'Step 1 of 2',
    previousStep: greeting,
  ),
  registrationConfirmation(
    title: 'Step 2 of 3',
    previousStep: registration,
  ),
  loginConfirmation(
    title: 'Step 2 of 2',
    previousStep: login,
  );

  final String? title;
  final AuthStep? previousStep;

  const AuthStep({
    required this.title,
    required this.previousStep,
  });

  AuthStep get requestOtpNextStep => switch (this) {
        AuthStep.registration => AuthStep.registrationConfirmation,
        AuthStep.login => AuthStep.loginConfirmation,
        _ => throw StateError(
            'Incorrect AuthStep $this while requestOtp is called'),
      };

  DwPhoneVerificationRequestType get requestOtpVerificationRequestType =>
      switch (this) {
        AuthStep.registration => DwPhoneVerificationRequestType.registration,
        AuthStep.login => DwPhoneVerificationRequestType.signIn,
        _ => throw StateError(
            'Incorrect AuthStep $this while requestOtp is called'),
      };
}
