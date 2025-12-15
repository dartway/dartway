// import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
// import 'package:dartway_serverpod_core_server/zarchive/phone_auth/dw_phone_auth.dart';
// import 'package:serverpod/serverpod.dart';
// import 'package:serverpod_auth_server/serverpod_auth_server.dart';

// /// Endpoint for handling Sign in with phone.
// class DwPhoneAuthEndpoint extends Endpoint {
//   Stream<SerializableModel> startVerification(
//     Session session, {
//     required DwPhoneVerificationRequestType requestType,
//     required String phoneNumber,
//     Map<String, String>? requestExtraData,
//     Map<String, String>? verificationExtraParams,
//   }) async* {
//     session.log('Creating phone verification stream for $phoneNumber');

//     final stream = DwPhoneAuth.createVerificationStream(
//       session,
//       phoneNumber: phoneNumber,
//     );

//     () async {
//       try {
//         final res = await DwPhoneAuth.requestVerification(
//           session,
//           requestType: requestType,
//           phoneNumber: phoneNumber,
//           requestExtraData: requestExtraData,
//           verificationExtraParams: verificationExtraParams,
//         );

//         await DwPhoneAuth.postOnVerificationStream(
//           session,
//           phoneNumber: phoneNumber,
//           message: res,
//         );
//       } catch (e, st) {
//         session.log('startVerification error: $e\n$st');
//       }
//     }(); // fire-and-forget

//     await for (var message in stream) {
//       yield message;
//     }
//   }

//   /// Verifies phoneNumber with OneTimePassword.
//   /// Calls onVerificationSuccessCallback if the verification is successful.
//   /// Returns [AuthenticationResponse] with the user information if it was registration or signIn.
//   Future<AuthenticationResponse> verifyWithOneTimePassword(
//     Session session,
//     String phoneNumber,
//     String oneTimePassword,
//   ) {
//     return DwPhoneAuth.verifyWithOneTimePassword(
//       session,
//       phoneNumber: phoneNumber,
//       oneTimePassword: oneTimePassword,
//     );
//   }

//   Future<AuthenticationResponse> forceVerification(
//     Session session, {
//     required String phoneNumber,
//     bool sendAuthenticationResponseToStream = false,
//   }) async {
//     final response = await DwPhoneAuth.forceVerification(
//       session,
//       phoneNumber: phoneNumber,
//     );

//     if (sendAuthenticationResponseToStream) {
//       await DwPhoneAuth.postOnVerificationStream(
//         session,
//         phoneNumber: phoneNumber,
//         message: response,
//       );
//     }

//     return response;
//   }
// }
