import 'package:dartway_flutter/dartway_flutter.dart';
import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_state_model.dart';
import 'auth_step.dart';

part 'auth_state.g.dart';

@riverpod
class AuthState extends _$AuthState {
  @override
  AuthStateModel build() {
    return const AuthStateModel(
      currentStep: AuthStep.greeting,
      firstName: '',
      phoneRaw: kDebugMode
          ? ''
          : '', // you can change it to your phone number for testing
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

  /// OTP request
  Future<void> requestOtp() async {
    final userExists = await ref
        .read(dwPhoneAuthStateProvider.notifier)
        .userExists(identifier: state.phoneDigits);

    if (state.currentStep == AuthStep.login && !userExists) {
      dw.notify.error(
          'Account not found, enter your name and accept the user agreement for continued');
      goTo(AuthStep.registration);
      return;
    } else if (state.currentStep == AuthStep.registration && userExists) {
      dw.notify.warning('Account already exists, performing login');
    }

    await ref.read(dwPhoneAuthStateProvider.notifier).startVerification(
          requestType: userExists
              ? DwPhoneVerificationRequestType.signIn
              : DwPhoneVerificationRequestType.registration,
          phoneNumber: state.phoneDigits,
          requestExtraData: !userExists
              ? {
                  'firstName': state.firstName,
                  'agreedForMarketingCommunications':
                      state.marketingAgreed.toString(),
                }
              : null,
        );

    state = state.copyWith(currentStep: state.currentStep.requestOtpNextStep);
  }

  /// Verification of the code
  Future<bool> verifyOtp() async {
    final response =
        await ref.read(dwPhoneAuthStateProvider.notifier).verifyOtp(
              phoneNumber: state.phoneDigits,
              otpDigits: state.otpDigits,
            );

    return response.success;
  }
}
