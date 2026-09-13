import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/dw_core.dart';
import 'auth_state_model.dart';
import 'auth_step.dart';

/// Drives the phone sign-in on DartWay auth: [requestCode] sends
/// `DwRequestCode` and keeps the ticket the server answers with; [verifyCode]
/// sends the typed code against that ticket as `DwVerifyCode`, and the session
/// it answers with is adopted by `dw.signIn` — which is what moves the router
/// out of the auth zone.
///
/// Both return the command's result, so that `dw.action` shows a refusal (an
/// invalid phone, a wrong or expired code, too many attempts) in the user's
/// language without any code here.
class AuthState extends Notifier<AuthStateModel> {
  DwCodeTicket? _ticket;

  @override
  AuthStateModel build() {
    return const AuthStateModel(
      currentStep: AuthStep.greeting,
      firstName: '',
      phoneRaw: '',
      otpRaw: '',
      allDocumentsAccepted: false,
      marketingAgreed: false,
    );
  }

  void goTo(AuthStep step) {
    state = state.copyWith(currentStep: step);
  }

  void update({
    String? firstName,
    String? phoneRaw,
    String? otpRaw,
    bool? allDocumentsAccepted,
    bool? marketingAgreed,
  }) {
    state = state.copyWith(
      firstName: firstName ?? state.firstName,
      phoneRaw: phoneRaw ?? state.phoneRaw,
      otpRaw: otpRaw ?? state.otpRaw,
      allDocumentsAccepted: allDocumentsAccepted ?? state.allDocumentsAccepted,
      marketingAgreed: marketingAgreed ?? state.marketingAgreed,
    );
  }

  /// Asks the server to send a one-time code to the entered phone.
  Future<DwResult<DwCodeTicket>> requestCode() async {
    final result = await dw.command(
      DwRequestCode(
        kind: DwIdentifierKind.phone,
        identifier: state.phoneDigits,
      ),
    );
    if (result case DwOk(value: final ticket)) {
      _ticket = ticket;
      state = state.copyWith(
        currentStep: state.currentStep.requestOtpNextStep,
        otpRaw: '',
      );
    }
    return result;
  }

  /// Verifies the entered code and signs in.
  ///
  /// The registration step sends what it collected; the server hands it to
  /// the account-created hook and ignores it for an account that exists. A
  /// login with a phone that has no account creates one without a name, and
  /// `SignedInGate` asks for it.
  Future<DwResult<DwSession>> verifyCode() async {
    // The code step is only ever entered by a successful [requestCode].
    final ticket =
        _ticket ?? (throw StateError('verifyCode ran before requestCode'));
    final result = await dw.command(
      DwVerifyCode(
        ticketId: ticket.id,
        code: state.otpDigits,
        registration: state.currentStep == AuthStep.registrationConfirmation
            ? {
                'firstName': state.firstName.trim(),
                'marketing': state.marketingAgreed.toString(),
              }
            : const {},
      ),
    );
    if (result case DwOk(value: final session)) {
      await dw.signIn(session);
      // Signed in: the flow starts from the beginning next time, and the
      // phone and code typed here do not outlive it.
      ref.invalidateSelf();
    }
    return result;
  }
}

final authStateProvider = NotifierProvider<AuthState, AuthStateModel>(
  AuthState.new,
);
