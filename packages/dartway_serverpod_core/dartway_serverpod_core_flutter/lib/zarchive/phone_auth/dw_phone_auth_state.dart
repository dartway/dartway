// import 'dart:async';

// import 'package:dartway_flutter/dartway_flutter.dart';
// import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
// import 'package:dartway_serverpod_core_shared/dartway_serverpod_core_shared.dart';
// import 'package:flutter/foundation.dart';
// import 'package:freezed_annotation/freezed_annotation.dart';
// import 'package:riverpod_annotation/riverpod_annotation.dart';
// import 'package:serverpod_auth_client/serverpod_auth_client.dart';

// part 'dw_phone_auth_state.freezed.dart';
// part 'dw_phone_auth_state.g.dart';

// @freezed
// abstract class DwPhoneAuthStateModel with _$DwPhoneAuthStateModel {
//   const factory DwPhoneAuthStateModel() = _DwPhoneAuthStateModel;
// }

// @Riverpod(keepAlive: true)
// class DwPhoneAuthState extends _$DwPhoneAuthState {
//   StreamSubscription? _subscription;
//   String? _subscriptionPhone;

//   @override
//   void build() {
//     ref.onDispose(() {
//       debugPrint("Disposing DwPhoneAuthState state");
//       _subscription?.cancel();
//       _subscription = null;
//       _subscriptionPhone = null;
//     });
//   }

//   /// Starts verification process:
//   /// server will open stream and make requestVerification.
//   Future<void> startVerification({
//     required DwPhoneVerificationRequestType requestType,
//     required String phoneNumber,
//     Map<String, String>? requestExtraData,
//     Map<String, String>? verificationExtraParams,
//   }) async {
//     // if we are already listening to the same number, do nothing
//     if (_subscription != null && _subscriptionPhone == phoneNumber) return;

//     _closeStream();

//     final outStream = DwCore.endpointCaller.dwPhoneAuth.startVerification(
//       requestType: requestType,
//       phoneNumber: phoneNumber,
//       requestExtraData: requestExtraData,
//       verificationExtraParams: verificationExtraParams,
//     );

//     _subscriptionPhone = phoneNumber;

//     _subscription = outStream.listen(
//       (update) async {
//         if (kDebugMode) debugPrint('DwPhoneAuthState stream update: $update');

//         if (update is AuthenticationResponse) {
//           await _processAuthenticationResponse(update);
//         } else if (update is DwAppNotification) {
//           if (kDebugMode) debugPrint('Notification: ${update.title}');

//           dw.notify.info(update.title);
//         }
//       },
//       onError: (e, st) {
//         if (kDebugMode) debugPrint('Auth stream error: $e\n$st');
//       },
//       onDone: () {
//         _subscriptionPhone = null;
//       },
//       cancelOnError: false,
//     );
//   }

//   /// Verify OTP separately
//   Future<AuthenticationResponse> verifyOtp({
//     required String phoneNumber,
//     required String otpDigits,
//   }) async {
//     final res = await DwCore.endpointCaller.dwPhoneAuth
//         .verifyWithOneTimePassword(phoneNumber, otpDigits);

//     await _processAuthenticationResponse(res);
//     return res;
//   }

//   void _closeStream() {
//     _subscription?.cancel();
//     _subscription = null;
//     _subscriptionPhone = null;
//   }

//   Future<void> _processAuthenticationResponse(
//     AuthenticationResponse authResponse,
//   ) async {
//     try {
//       if (authResponse.success &&
//           authResponse.userInfo != null &&
//           authResponse.keyId != null &&
//           authResponse.key != null) {
//         await DwCore.serverpodSessionManager.registerSignedInUser(
//           authResponse.userInfo!,
//           authResponse.keyId!,
//           authResponse.key!,
//         );
//         // Can close stream after successful login
//         _closeStream();
//       }
//     } catch (e, st) {
//       if (kDebugMode) debugPrint('processAuth error: $e\n$st');
//     }
//   }

//   Future<bool> userExists({required String identifier}) async {
//     if (kDebugMode) {
//       debugPrint('Searching for user with phone $identifier');
//     }

//     final userInfo = await ref.readMaybeModel<UserInfo>(
//       apiGroupOverride: DwCoreConst.dartwayInternalApi,
//       forceFetch: true,
//       filter: DwBackendFilter.value(
//         type: DwBackendFilterType.equals,
//         fieldName: DwCoreConst.userIdentifierColumnName,
//         fieldValue: identifier,
//       ),
//     );

//     return userInfo != null;
//   }
// }
