import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import 'auth_step.dart';

/// What the sign-in flow holds: where it is, what was typed, what was agreed.
///
/// Written by hand rather than generated: `copyWith` and equality on a few
/// fields cost less than keeping a code generator in the build loop.
class AuthStateModel {
  const AuthStateModel({
    this.step = AuthStep.identifier,
    this.kind = DwIdentifierKind.phone,
    this.phoneRaw = '',
    this.emailRaw = '',
    this.codeRaw = '',
    this.firstName = '',
    this.termsAccepted = false,
    this.marketingAgreed = false,
    this.resendAvailableAt,
  });

  final AuthStep step;

  /// Which identifier the person signs in with.
  final DwIdentifierKind kind;

  // Input, as typed. Both identifiers are kept, so switching the kind back and
  // forth loses nothing.
  final String phoneRaw;
  final String emailRaw;
  final String codeRaw;
  final String firstName;

  // Agreements, asked of a new account only.
  final bool termsAccepted;
  final bool marketingAgreed;

  /// When a new code may be asked for — the ticket's `resendAfter`.
  final DateTime? resendAvailableAt;

  /// What was typed for the chosen [kind].
  String get rawIdentifier => switch (kind) {
    DwIdentifierKind.phone => phoneRaw,
    DwIdentifierKind.email => emailRaw,
  };

  /// [rawIdentifier] in the form the server stores it, or `null` while it is
  /// not an identifier of [kind] — the same rule the server applies.
  String? get identifier => AuthIdentifier.normalize(kind, rawIdentifier);

  /// The code, digits only.
  String get codeDigits => codeRaw.replaceAll(RegExp(r'\D'), '');

  AuthStateModel copyWith({
    AuthStep? step,
    DwIdentifierKind? kind,
    String? phoneRaw,
    String? emailRaw,
    String? codeRaw,
    String? firstName,
    bool? termsAccepted,
    bool? marketingAgreed,
    DateTime? resendAvailableAt,
  }) => AuthStateModel(
    step: step ?? this.step,
    kind: kind ?? this.kind,
    phoneRaw: phoneRaw ?? this.phoneRaw,
    emailRaw: emailRaw ?? this.emailRaw,
    codeRaw: codeRaw ?? this.codeRaw,
    firstName: firstName ?? this.firstName,
    termsAccepted: termsAccepted ?? this.termsAccepted,
    marketingAgreed: marketingAgreed ?? this.marketingAgreed,
    resendAvailableAt: resendAvailableAt ?? this.resendAvailableAt,
  );

  /// Value equality keeps the notifier from rebuilding listeners on a state
  /// that did not actually change.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthStateModel &&
          other.step == step &&
          other.kind == kind &&
          other.phoneRaw == phoneRaw &&
          other.emailRaw == emailRaw &&
          other.codeRaw == codeRaw &&
          other.firstName == firstName &&
          other.termsAccepted == termsAccepted &&
          other.marketingAgreed == marketingAgreed &&
          other.resendAvailableAt == resendAvailableAt;

  @override
  int get hashCode => Object.hash(
    step,
    kind,
    phoneRaw,
    emailRaw,
    codeRaw,
    firstName,
    termsAccepted,
    marketingAgreed,
    resendAvailableAt,
  );
}
