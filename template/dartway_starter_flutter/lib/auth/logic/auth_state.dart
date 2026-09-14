import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/dw_core.dart';
import 'auth_state_model.dart';
import 'auth_step.dart';

/// Drives signing in on DartWay auth, by phone or by e-mail.
///
/// [requestCode] sends `DwRequestCode` and keeps the ticket the server answers
/// with; [verifyCode] sends the typed code against that ticket as
/// `DwVerifyCode`, and the session it answers with is adopted by `dw.signIn` —
/// which is what moves the router out of the auth zone.
///
/// A code that would create an account is refused with `consentsRequired`
/// until the terms are accepted: the flow then asks for them and verifies the
/// same code again, with what it collected.
///
/// The commands' results are returned, so that `dw.action` shows a refusal (an
/// invalid identifier, a wrong or expired code, too many attempts) in the
/// user's language without any code here.
class AuthState extends Notifier<AuthStateModel> {
  DwCodeTicket? _ticket;

  @override
  AuthStateModel build() => const AuthStateModel();

  void update({
    DwIdentifierKind? kind,
    String? phoneRaw,
    String? emailRaw,
    String? codeRaw,
    String? firstName,
    bool? termsAccepted,
    bool? marketingAgreed,
  }) => state = state.copyWith(
    kind: kind,
    phoneRaw: phoneRaw,
    emailRaw: emailRaw,
    codeRaw: codeRaw,
    firstName: firstName,
    termsAccepted: termsAccepted,
    marketingAgreed: marketingAgreed,
  );

  /// One step back. Leaving the code step forgets the ticket: another
  /// identifier needs a code of its own.
  void back() {
    final previous = state.step.previousStep;
    if (previous == null) return;
    if (previous == AuthStep.identifier) _ticket = null;
    state = state.copyWith(step: previous);
  }

  /// Asks the server to send a one-time code to the entered identifier.
  Future<DwCallResult<DwCodeTicket>> requestCode() async {
    final result = await dw.command(
      DwRequestCode(
        kind: state.kind,
        // The field's validator has let only a valid identifier through; the
        // server applies the same rule to whatever arrives.
        identifier: state.identifier ?? state.rawIdentifier,
      ),
    );
    if (result case DwCallOk(value: final ticket)) {
      _ticket = ticket;
      state = state.copyWith(
        step: AuthStep.code,
        codeRaw: '',
        resendAvailableAt: ticket.resendAfter,
      );
    }
    return result;
  }

  /// Verifies the entered code and signs in.
  ///
  /// Answers `null` when the server asks for the terms first: the consents
  /// step is the answer, not a refusal to show.
  Future<DwCallResult<DwAuthSession>?> verifyCode() async {
    // The code step is only ever entered by a successful [requestCode].
    final ticket =
        _ticket ?? (throw StateError('verifyCode ran before requestCode'));
    final result = await dw.command(
      DwVerifyCode(
        ticketId: ticket.id,
        code: state.codeDigits,
        registration: state.step == AuthStep.consents
            ? {
                RegistrationKeys.terms: '${state.termsAccepted}',
                RegistrationKeys.marketing: '${state.marketingAgreed}',
                RegistrationKeys.firstName: state.firstName.trim(),
              }
            : const {},
      ),
    );
    switch (result) {
      case DwCallRefused(:final refusal)
          when refusal.isCode(DartwayStarterRefusal.consentsRequired):
        state = state.copyWith(step: AuthStep.consents);
        return null;
      case DwCallOk(value: final session):
        await dw.signIn(session);
        // Signed in: the flow starts from the beginning next time, and what
        // was typed here does not outlive it.
        ref.invalidateSelf();
      default:
    }
    return result;
  }
}

final authStateProvider = NotifierProvider<AuthState, AuthStateModel>(
  AuthState.new,
);
