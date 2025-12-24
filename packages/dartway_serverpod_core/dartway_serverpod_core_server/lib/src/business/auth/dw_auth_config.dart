import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

import 'dw_auth_utils.dart';

// typedef InitVerificationCallback = Future<bool> Function(
//   Session session,
//   String userIdentifier,
//   String verificationOneTimePassword, {
//   Map<String, String>? verificationExtraParams,
// });

// typedef GenerateOneTimePasswordCallback = Future<String> Function(
//   Session session,
//   String userIdentifier, {
//   Map<String, String>? verificationExtraParams,
// });

// typedef OnVerificationSuccessCallback = Future<bool> Function(
//   Session session,
//   DwAuthRequest verificationRequest,
// );

class DwAuthConfig<UserProfileClass extends TableRow> {
  final Map<String, String> passwords;

  String get authKeySalt =>
      passwords[DwConfigurationKeys.dwAuthKeySaltKey] ??
      (throw Exception(
        '${DwConfigurationKeys.dwAuthKeySaltKey} missing in passwords',
      ));

  String get verificationCodeSalt =>
      passwords[DwConfigurationKeys.dwVerificationCodeSaltKey] ??
      (throw Exception(
        '${DwConfigurationKeys.dwVerificationCodeSaltKey} missing in passwords',
      ));

  const DwAuthConfig({
    required this.passwords,
    this.generateVerificationCodeMethod =
        DwAuthUtils.defaultVerificationCodeGenerationMethod,
    this.sendVerificationCodeMethod,
    this.onSignInTrigger,
  });

  /// Callback for triggering actions when a user signs in.
  final Future<void> Function(
    Session session, {
    required int userId,
    required bool isFirstSignIn,
  })? onSignInTrigger;

  /// Callback for generating a verification code.
  final Future<String> Function(
    Session session, {
    required DwAuthRequest verificationRequest,
  })? generateVerificationCodeMethod;

  /// Callback for sending validation message.
  final Future<void> Function(
    Session session, {
    required DwAuthRequest verificationRequest,
    required String verificationCode,
  })? sendVerificationCodeMethod;

  // static DwAuthConfig _config = DwAuthConfig(
  //   secretHashKey: 'DwHashSecret',
  //   initVerificationCallback:
  //       (session, phoneNumber, verificationOneTimePassword,
  //           {verificationExtraParams}) async {
  //     throw StateError(
  //       'DwAuthConfig is not configured. '
  //       'Please provide your own config in initDartwayCore().',
  //     );
  //   },
  // );

  // static void set(DwAuthConfig config) {
  //   _config = config;
  // }

  // static DwAuthConfig get current => _config;

  // static final DwAuthConfig defaultDevelopmentConfig = DwAuthConfig(
  //   secretHashKey: 'phoneVerificationHashKey',
  //   maxInitVerificationRequests: 5,
  //   maxAllowedVerificationAttempts: 5,
  //   initVerificationCallback:
  //       (session, phoneNumber, verificationOneTimePassword,
  //           {verificationExtraParams}) async {
  //     session.log(verificationOneTimePassword);

  //     Future.delayed(
  //       Duration(seconds: 1),
  //       () => DwAuth.postOnVerificationStream(
  //         session,
  //         phoneNumber: phoneNumber,
  //         message: DwAppNotification(
  //           toUserId: 0,
  //           title: verificationOneTimePassword,
  //         ),
  //       ),
  //     );

  //     return true;
  //   },
  // );

  // const DwAuthConfig({
  //   required this.secretHashKey,
  //   this.maxAllowedVerificationAttempts = 5,
  //   this.phoneVerificationAttemptsResetTime = const Duration(minutes: 5),
  //   this.verificationRequestExpirationTime = const Duration(minutes: 5),
  //   this.maxInitVerificationRequests = 3,
  //   this.initVerificationRequestsResetTime = const Duration(minutes: 5),
  //   this.generateOneTimePasswordCallback = defaultOtpGenerationCallback,
  //   this.initVerificationCallback,
  //   this.onVerificationSuccessCallback,
  //   this.allowManuallyForcedVerification = false,
  // });

  // /// Secret key used for hashing phone numbers with One Time Passwords.
  // final String secretHashKey;

  // /// If true, endpoint for manual verification is enabled
  // final bool allowManuallyForcedVerification;

  // /// Amount of attempts allowed to request verification. Defaults to 3.
  // final int maxInitVerificationRequests;

  // /// The reset period of resend validation code. Defaults to 5 minutes.
  // final Duration initVerificationRequestsResetTime;

  // /// Verification request expiration time. Defaults to 5 minutes.
  // final Duration verificationRequestExpirationTime;

  // /// Max allowed failed phone verification attempts within the reset period.
  // /// Defaults to 5. (By default, a user can make 5 sign in attempts within a
  // /// 5 minute window.)
  // final int maxAllowedVerificationAttempts;

  // /// the reset period for phone verification attempts. Defaults to 5 minutes.
  // final Duration phoneVerificationAttemptsResetTime;

  // /// Callback that is called when the verification is successful.
  // /// Optional for signIn and registration scenarios but required for other
  // /// Because there are no default actions after successful verification
  // final OnVerificationSuccessCallback? onVerificationSuccessCallback;
}
