// import 'dart:async';

// // ignore: implementation_imports
// import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
// import 'package:serverpod/serverpod.dart';
// import 'package:serverpod_auth_server/serverpod_auth_server.dart' as auth;
// import 'package:serverpod_auth_server/serverpod_auth_server.dart';

// import 'dw_phone_auth_config.dart';
// import 'dw_phone_auth_otp_utils.dart';

// const _authMethod = 'phone';

// /// Authentication methods for phone.
// class DwPhoneAuth {
//   static String _dwPhoneVerificationChannel(String phone) =>
//       'dwPhoneVerification$phone';

//   static Stream<SerializableModel> createVerificationStream(
//     Session session, {
//     required String phoneNumber,
//   }) =>
//       session.messages.createStream<SerializableModel>(
//         _dwPhoneVerificationChannel(phoneNumber),
//       );

//   static postOnVerificationStream(
//     Session session, {
//     required String phoneNumber,
//     required SerializableModel message,
//   }) async =>
//       await session.messages.postMessage(
//         _dwPhoneVerificationChannel(phoneNumber),
//         message,
//       );

//   /// Initializes the phone verification process.
//   static Future<AuthenticationResponse> requestVerification(
//     Session session, {
//     required DwPhoneVerificationRequestType requestType,
//     required String phoneNumber,
//     Map<String, String>? requestExtraData,
//     Map<String, String>? verificationExtraParams,
//   }) async {
//     try {
//       if (await _hasTooManyVerificationRequests(session, phoneNumber)) {
//         session.log(
//           'Too many verification requests for $phoneNumber',
//           level: LogLevel.warning,
//         );
//         return AuthenticationResponse(
//           success: false,
//           failReason: AuthenticationFailReason.tooManyFailedAttempts,
//         );
//       }

//       var otp = await DwPhoneAuthConfig.current.generateOneTimePasswordCallback(
//         session,
//         phoneNumber,
//         verificationExtraParams: verificationExtraParams,
//       );

//       final initVerificationResult =
//           await DwPhoneAuthConfig.current.initVerificationCallback?.call(
//         session,
//         phoneNumber,
//         otp,
//         verificationExtraParams: verificationExtraParams,
//       );

//       if (initVerificationResult == false) {
//         throw Exception(
//           'initVerificationCallback failed for $phoneNumber',
//         );
//       }

//       var hash = DwPhoneAuthOtpUtils.generateHashData(
//         phoneNumber: phoneNumber,
//         otp: otp,
//       );

//       var expirationTime = DwPhoneAuthOtpUtils.getHashExpirationTime(hash);

//       final stash = requestExtraData == null
//           ? null
//           : await session.db.insertRow(
//               DwAuthDataStash(
//                 type: requestType.name,
//                 identifier: phoneNumber,
//                 createdAt: DateTime.now(),
//                 data: requestExtraData,
//               ),
//             );

//       await session.db.insertRow(
//         DwPhoneVerificationRequest(
//           requestType: requestType,
//           phoneNumber: phoneNumber,
//           hash: hash,
//           expirationTime: expirationTime,
//           stashDataId: stash?.id,
//         ),
//       );
//     } catch (e) {
//       session.log(
//         'Error while initiating verification for $phoneNumber: $e',
//         level: LogLevel.error,
//       );
//       return AuthenticationResponse(
//         success: false,
//         failReason: AuthenticationFailReason.internalError,
//       );
//     }

//     return AuthenticationResponse(
//       success: true,
//     );
//   }

//   static Future<AuthenticationResponse> forceVerification(
//     Session session, {
//     required String phoneNumber,
//   }) async {
//     if (DwPhoneAuthConfig.current.allowManuallyForcedVerification == false) {
//       throw Exception('Manual verification is not allowed');
//     }

//     return _proceedVerification(
//       session,
//       phoneNumber: phoneNumber,
//       oneTimePassword: null,
//     );
//   }

//   static Future<AuthenticationResponse> verifyAfterExternalVerification(
//     Session session, {
//     required String phoneNumber,
//   }) async {
//     return _proceedVerification(
//       session,
//       phoneNumber: phoneNumber,
//       oneTimePassword: null,
//     );
//   }

//   static Future<AuthenticationResponse> verifyWithOneTimePassword(
//     Session session, {
//     required String phoneNumber,
//     required String oneTimePassword,
//   }) async {
//     return _proceedVerification(
//       session,
//       phoneNumber: phoneNumber,
//       oneTimePassword: oneTimePassword,
//     );
//   }

//   /// Verifies the phone number and OTP.
//   static Future<AuthenticationResponse> _proceedVerification(
//     Session session, {
//     required String phoneNumber,
//     required String? oneTimePassword,
//     // Map<String, String>? userExtraData,
//   }) async {
//     if (await _hasTooManyFailedSignIns(session, phoneNumber)) {
//       session.log(
//         'Too many verification attempts for $phoneNumber',
//         level: LogLevel.warning,
//       );
//       return AuthenticationResponse(
//         success: false,
//         failReason: AuthenticationFailReason.tooManyFailedAttempts,
//       );
//     }

//     var entry = await _findVerificationRequest(
//       session,
//       phoneNumber,
//     );

//     if (entry == null) {
//       return AuthenticationResponse(
//         success: false,
//         failReason: AuthenticationFailReason.invalidCredentials,
//       );
//     }

//     if (oneTimePassword != null &&
//         !DwPhoneAuthOtpUtils.verifyHashData(
//           session,
//           hashedData: entry.hash,
//           phoneNumber: phoneNumber,
//           otp: oneTimePassword,
//         )) {
//       session.log('Failed to verify user $phoneNumber');
//       return AuthenticationResponse(
//         success: false,
//         failReason: AuthenticationFailReason.invalidCredentials,
//       );
//     }

//     session.log('User $phoneNumber verified');

//     final isOk = DwPhoneAuthConfig.current.onVerificationSuccessCallback ==
//             null ||
//         true ==
//             await DwPhoneAuthConfig.current.onVerificationSuccessCallback?.call(
//               session,
//               entry,
//             );

//     if (!isOk) {
//       return AuthenticationResponse(
//         success: false,
//         failReason: AuthenticationFailReason.invalidCredentials,
//       );
//     }

//     await session.db.updateRow(
//       entry.copyWith(
//         isUsed: true,
//       ),
//     );

//     final userInfo = switch (entry.requestType) {
//       DwPhoneVerificationRequestType.registration ||
//       DwPhoneVerificationRequestType.signIn =>
//         await _findOrCreateUserByPhone(
//           session,
//           phoneNumber,
//         ),
//       _ => null,
//     };

//     var authKey = switch (entry.requestType) {
//       DwPhoneVerificationRequestType.registration ||
//       DwPhoneVerificationRequestType.signIn =>
//         await auth.UserAuthentication.signInUser(
//           session,
//           userInfo!.id!,
//           _authMethod,
//         ),
//       _ => null,
//     };

//     return AuthenticationResponse(
//       success: true,
//       key: authKey?.key,
//       userInfo: userInfo,
//       keyId: authKey?.id,
//     );
//   }

//   static Future<DwPhoneVerificationRequest?> _findVerificationRequest(
//     Session session,
//     String phoneNumber,
//   ) async {
//     return DwPhoneVerificationRequest.db.findFirstRow(
//       session,
//       where: (t) =>
//           t.phoneNumber.equals(phoneNumber) &
//           t.isUsed.equals(false) &
//           (t.expirationTime >= DateTime.now()),
//       include: DwPhoneVerificationRequest.include(
//         stashData: DwAuthDataStash.include(),
//       ),
//       orderBy: (t) => t.createdAt,
//       orderDescending: true,
//     );
//   }

//   static Future<UserInfo> _findOrCreateUserByPhone(
//     Session session,
//     String phoneNumber,
//   ) async {
//     var userInfo = await Users.findUserByIdentifier(session, phoneNumber);

//     if (userInfo == null) {
//       session.log('User with phone $phoneNumber not found');

//       session.log('Creating new user with phone $phoneNumber');

//       userInfo = await Users.createUser(
//         session,
//         UserInfo(
//           userIdentifier: phoneNumber,
//           created: DateTime.now(),
//           scopeNames: [],
//           blocked: false,
//         ),
//         _authMethod,
//       );

//       if (userInfo == null) {
//         session.log('Failed to create user with phone $phoneNumber');
//         throw Exception('Failed to create user with phone $phoneNumber');
//       }
//     }

//     return userInfo;
//   }

//   static Future<bool> _hasTooManyFailedSignIns(
//     Session session,
//     String phoneNumber,
//   ) async {
//     var numFailedSingIns = await DwPhoneFailedSignIn.db.count(
//       session,
//       where: (t) =>
//           t.phoneNumber.equals(phoneNumber) &
//           (t.time >
//               DateTime.now().toUtc().subtract(
//                     DwPhoneAuthConfig
//                         .current.phoneVerificationAttemptsResetTime,
//                   )),
//     );
//     return numFailedSingIns >=
//         DwPhoneAuthConfig.current.maxAllowedVerificationAttempts;
//   }

//   static Future<bool> _hasTooManyVerificationRequests(
//       Session session, String phoneNumber) async {
//     return DwPhoneAuthConfig.current.maxInitVerificationRequests <=
//         await DwPhoneVerificationRequest.db.count(
//           session,
//           where: (t) =>
//               t.phoneNumber.equals(phoneNumber) &
//               (t.createdAt >=
//                   DateTime.now().subtract(DwPhoneAuthConfig
//                       .current.initVerificationRequestsResetTime)),
//         );
//   }
// }
