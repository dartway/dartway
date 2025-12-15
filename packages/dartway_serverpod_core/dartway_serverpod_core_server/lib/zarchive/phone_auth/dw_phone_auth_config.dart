// import 'dart:math';

// import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
// import 'package:serverpod/server.dart';
// import 'package:serverpod_auth_server/serverpod_auth_server.dart';

// typedef InitVerificationCallback = Future<bool> Function(
//   Session session,
//   String phoneNumber,
//   String verificationOneTimePassword, {
//   Map<String, String>? verificationExtraParams,
// });

// typedef GenerateOneTimePasswordCallback = Future<String> Function(
//   Session session,
//   String phoneNumber, {
//   Map<String, String>? verificationExtraParams,
// });

// typedef OnVerificationSuccessCallback = Future<bool> Function(
//   Session session,
//   DwPhoneVerificationRequest verificationRequest,
// );

// class DwPhoneAuthConfig {
//   static DwPhoneAuthConfig _config = DwPhoneAuthConfig(
//     secretHashKey: 'DwHashSecret',
//     initVerificationCallback:
//         (session, phoneNumber, verificationOneTimePassword,
//             {verificationExtraParams}) async {
//       throw StateError(
//         'DwPhoneAuthConfig is not configured. '
//         'Please provide your own config in initDartwayCore().',
//       );
//     },
//   );

//   static void set(DwPhoneAuthConfig config) {
//     _config = config;
//   }

//   static DwPhoneAuthConfig get current => _config;

//   static final DwPhoneAuthConfig defaultDevelopmentConfig = DwPhoneAuthConfig(
//     secretHashKey: 'phoneVerificationHashKey',
//     maxInitVerificationRequests: 5,
//     maxAllowedVerificationAttempts: 5,
//     initVerificationCallback:
//         (session, phoneNumber, verificationOneTimePassword,
//             {verificationExtraParams}) async {
//       session.log(verificationOneTimePassword);

//       Future.delayed(
//         Duration(seconds: 1),
//         () => DwPhoneAuth.postOnVerificationStream(
//           session,
//           phoneNumber: phoneNumber,
//           message: DwAppNotification(
//             toUserId: 0,
//             title: verificationOneTimePassword,
//           ),
//         ),
//       );

//       return true;
//     },
//   );

//   /// Default OTP generation callback that generates a random 6-digit OTP and prints it to the server.
//   static Future<String> defaultOtpGenerationCallback(
//     session,
//     number, {
//     verificationExtraParams,
//   }) async {
//     final otp = randomDigits(6);
//     print('Generated OTP for $number: $otp');
//     return otp;
//   }

//   /// Generates a new DwPhoneAuthConfig.current.validationCodeLength digit OTP.
//   static String randomDigits(int length) {
//     return Random().nextString(length: length, chars: '0123456789');
//   }

//   const DwPhoneAuthConfig({
//     required this.secretHashKey,
//     this.maxAllowedVerificationAttempts = 5,
//     this.phoneVerificationAttemptsResetTime = const Duration(minutes: 5),
//     this.verificationRequestExpirationTime = const Duration(minutes: 5),
//     this.maxInitVerificationRequests = 3,
//     this.initVerificationRequestsResetTime = const Duration(minutes: 5),
//     this.generateOneTimePasswordCallback = defaultOtpGenerationCallback,
//     this.initVerificationCallback,
//     this.onVerificationSuccessCallback,
//     this.allowManuallyForcedVerification = false,
//   });

//   /// Secret key used for hashing phone numbers with One Time Passwords.
//   final String secretHashKey;

//   /// If true, endpoint for manual verification is enabled
//   final bool allowManuallyForcedVerification;

//   /// Callback for sending validation message.
//   final InitVerificationCallback? initVerificationCallback;

//   /// Callback for OTP generation.
//   final GenerateOneTimePasswordCallback generateOneTimePasswordCallback;

//   /// Amount of attempts allowed to request verification. Defaults to 3.
//   final int maxInitVerificationRequests;

//   /// The reset period of resend validation code. Defaults to 5 minutes.
//   final Duration initVerificationRequestsResetTime;

//   /// Verification request expiration time. Defaults to 5 minutes.
//   final Duration verificationRequestExpirationTime;

//   /// Max allowed failed phone verification attempts within the reset period.
//   /// Defaults to 5. (By default, a user can make 5 sign in attempts within a
//   /// 5 minute window.)
//   final int maxAllowedVerificationAttempts;

//   /// the reset period for phone verification attempts. Defaults to 5 minutes.
//   final Duration phoneVerificationAttemptsResetTime;

//   /// Callback that is called when the verification is successful.
//   /// Optional for signIn and registration scenarios but required for other
//   /// Because there are no default actions after successful verification
//   final OnVerificationSuccessCallback? onVerificationSuccessCallback;
// }
