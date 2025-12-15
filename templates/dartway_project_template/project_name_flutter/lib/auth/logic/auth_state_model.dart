import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:project_name_flutter/auth/logic/auth_step.dart';

part 'auth_state_model.freezed.dart';

/// Immutable state model for authentication process
/// User input is stored in simple strings, business flags are separate fields.
@freezed
class AuthStateModel with _$AuthStateModel {
  const factory AuthStateModel({
    required AuthStep currentStep,

    // Input fields
    required String firstName,
    required String phoneRaw,
    required String otpRaw,

    // Agreements
    required bool allDocumentsAccepted,
    required bool marketingAgreed,
  }) = _AuthStateModel;

  const AuthStateModel._();

  /// Normalized phone: only digits
  String get phoneDigits => phoneRaw.replaceAll(RegExp(r'\D'), '');

  /// Normalized code: only digits
  String get otpDigits => otpRaw.replaceAll(RegExp(r'\D'), '');

  /// Simple phone check (10–15 digits)
  bool get isPhoneValid => phoneDigits.length >= 10 && phoneDigits.length <= 15;

  /// Requirements for requesting code on the registration step
  bool get registrationPrerequisitesOk =>
      firstName.trim().isNotEmpty && allDocumentsAccepted;

  /// Can we request OTP right now
  bool get canRequestOtp {
    if (!isPhoneValid) return false;
    if (currentStep == AuthStep.registration && !registrationPrerequisitesOk) {
      return false;
    }
    return true;
    // !isRequestingOtp && !isVerifyingOtp;
  }

  /// Can we verify the code
  bool get canVerifyOtp =>
      otpDigits.isNotEmpty; // && !isRequestingOtp && !isVerifyingOtp;
}
