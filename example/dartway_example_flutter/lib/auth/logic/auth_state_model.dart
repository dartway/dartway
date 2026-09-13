import 'package:dartway_example_flutter/auth/logic/auth_step.dart';

/// Immutable state model for authentication process
/// User input is stored in simple strings, business flags are separate fields.
///
/// Written by hand rather than generated: `copyWith` and equality on six
/// fields cost less than keeping a code generator in the build loop.
class AuthStateModel {
  const AuthStateModel({
    required this.currentStep,
    required this.firstName,
    required this.phoneRaw,
    required this.otpRaw,
    required this.allDocumentsAccepted,
    required this.marketingAgreed,
  });

  final AuthStep currentStep;

  // Input fields
  final String firstName;
  final String phoneRaw;
  final String otpRaw;

  // Agreements
  final bool allDocumentsAccepted;
  final bool marketingAgreed;

  AuthStateModel copyWith({
    AuthStep? currentStep,
    String? firstName,
    String? phoneRaw,
    String? otpRaw,
    bool? allDocumentsAccepted,
    bool? marketingAgreed,
  }) => AuthStateModel(
    currentStep: currentStep ?? this.currentStep,
    firstName: firstName ?? this.firstName,
    phoneRaw: phoneRaw ?? this.phoneRaw,
    otpRaw: otpRaw ?? this.otpRaw,
    allDocumentsAccepted: allDocumentsAccepted ?? this.allDocumentsAccepted,
    marketingAgreed: marketingAgreed ?? this.marketingAgreed,
  );

  /// Value equality keeps the notifier from rebuilding listeners on a state
  /// that did not actually change.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthStateModel &&
          other.currentStep == currentStep &&
          other.firstName == firstName &&
          other.phoneRaw == phoneRaw &&
          other.otpRaw == otpRaw &&
          other.allDocumentsAccepted == allDocumentsAccepted &&
          other.marketingAgreed == marketingAgreed;

  @override
  int get hashCode => Object.hash(
    currentStep,
    firstName,
    phoneRaw,
    otpRaw,
    allDocumentsAccepted,
    marketingAgreed,
  );

  /// Normalized phone: only digits
  String get phoneDigits => phoneRaw.replaceAll(RegExp(r'\D'), '');

  /// Normalized code: only digits
  String get otpDigits => otpRaw.replaceAll(RegExp(r'\D'), '');
}
