import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/dw_core.dart';
import 'auth_state_model.dart';
import 'auth_step.dart';

part 'auth_state.g.dart';

/// Drives the phone-based auth flow on top of the DartWay framework auth:
/// a [DwAuthRequest] (login/register, phone provider) is sent, the server
/// replies `pendingVerification`, the user enters the code, and a
/// [DwAuthVerification] exchanges it for an access token that completes the
/// request and signs the user in.
@riverpod
class AuthState extends _$AuthState {
  DwAuthRequest? _pendingRequest;

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

  /// Requests a one-time code for the entered phone number.
  Future<void> requestOtp() async {
    final isRegistration = state.currentStep == AuthStep.registration;

    final result = await dw.repo.saveModel(
      DwAuthRequest(
        requestType: isRegistration
            ? DwAuthRequestType.register
            : DwAuthRequestType.login,
        userIdentifier: state.phoneDigits,
        authProvider: DwAuthProvider.phone,
        extraData: isRegistration
            ? {
                'firstName': state.firstName,
                'agreedForMarketingCommunications': state.marketingAgreed
                    .toString(),
              }
            : null,
      ),
      apiGroupOverride: DwCoreConst.dartwayInternalApi,
    );

    if (result.status == DwAuthRequestStatus.failed) {
      dw.notify.error('Could not send the code. Please try again.');
      return;
    }

    _pendingRequest = result;
    state = state.copyWith(currentStep: state.currentStep.requestOtpNextStep);
  }

  /// Confirms the entered code and completes sign-in.
  Future<bool> verifyOtp() async {
    final pending = _pendingRequest;
    if (pending == null) {
      dw.notify.error('No pending verification request');
      return false;
    }

    final verification = await dw.repo.saveModel(
      DwAuthVerification(
        dwAuthRequestId: pending.id!,
        verificationCode: state.otpDigits,
      ),
      apiGroupOverride: DwCoreConst.dartwayInternalApi,
    );

    final accessToken = verification.accessToken;
    if (accessToken == null) {
      dw.notify.error('Invalid or expired code. Please try again.');
      return false;
    }

    final result = await dw.repo.saveModel(
      pending.copyWith(accessToken: accessToken),
      apiGroupOverride: DwCoreConst.dartwayInternalApi,
    );

    final success =
        result.status == DwAuthRequestStatus.completed ||
        result.status == DwAuthRequestStatus.verified;
    if (!success) {
      dw.notify.error('Could not complete sign-in. Please try again.');
    }
    return success;
  }
}
