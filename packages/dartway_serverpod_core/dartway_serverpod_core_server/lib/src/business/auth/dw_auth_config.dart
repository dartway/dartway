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

/// Raised when the application rejects creation of a new authentication key
/// from [DwAuthConfig.preAuthKeyIssuance].
///
/// The reason is typed so the caller can answer with a safe authorization
/// response without leaking database or application detail.
final class DwAuthKeyIssuanceRejectedException implements Exception {
  const DwAuthKeyIssuanceRejectedException(this.reason);

  final DwAuthFailReason reason;

  @override
  String toString() =>
      'DwAuthKeyIssuanceRejectedException(reason: ${reason.name})';
}

/// The two answers to "what form does this app store its identifier in".
///
/// Named rather than written inline, so the choice is readable at the call site
/// and greppable across projects — and so that the common one is not
/// re-implemented slightly differently in each of them. A project whose rule is
/// neither of these passes its own function; it only has to be idempotent, see
/// [DwAuthConfig.normalizeIdentifier].
abstract final class DwIdentifierForm {
  /// Trim and case-fold. What an email address wants, and what a phone number
  /// does not object to.
  static String folded(String identifier) => identifier.trim().toLowerCase();

  /// Byte for byte, as the caller typed it.
  ///
  /// The right answer for an app whose identifier is case-significant, and the
  /// only one that cannot break data already stored in mixed forms. Choosing it
  /// is choosing it — that is the point of making the parameter required.
  static String asTyped(String identifier) => identifier;
}

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
    this.preAuthValidation,
    this.preAuthKeyIssuance,
    this.verifyExternalCredential,
    this.maxVerificationAttempts = 5,
    this.verificationCodeLifetime = const Duration(minutes: 10),
    this.maxAuthRequestsPerIdentifier = 5,
    this.authRequestRateLimitWindow = const Duration(minutes: 10),
    this.passwordHasher = const DwBcryptPasswordHasher(),
    this.legacyPasswordVerifiers = const [],
    required this.normalizeIdentifier,
  });

  /// Brings a user identifier to the single form this app stores it in.
  ///
  /// `Ivan@acme.com` and `ivan@acme.com` are one person, or they are two, and
  /// only the app knows which — the identifier is not declared to be an email
  /// address, and an app may legitimately use a case-significant one.
  ///
  /// **Required, and deliberately so.** It shipped with a default that changed
  /// nothing, which meant the defect this exists to close — the same address
  /// typed with a capital signing a person into a second account — stayed open
  /// in every project that did not remember to declare a rule. A question the
  /// framework cannot answer is not a question it may answer quietly; it is one
  /// the compiler asks once, per project. Take [DwIdentifierForm.folded] or
  /// [DwIdentifierForm.asTyped], or state your own.
  ///
  /// Where it is applied: to the auth request the moment it arrives, before
  /// anything reads the identifier off it, and inside
  /// [DwCore.getUserProfileByIdentifier]. That covers the profile lookup, the
  /// per-identifier lock, the rate-limit bucket and — on a registration — the
  /// profile the app builds out of that same request. **The rule is therefore
  /// applied more than once, and must be idempotent:** `f(f(x)) == f(x)`.
  ///
  /// ```dart
  /// DwAuthConfig(
  ///   passwords: passwords,
  ///   normalizeIdentifier: (identifier) => identifier.trim().toLowerCase(),
  /// )
  /// ```
  ///
  /// What it does *not* do is touch rows that are already stored. An
  /// identifier written before the rule existed keeps whatever form it was
  /// written in, and one that the rule would change stops being found —
  /// silently, as a "no such user". Switching this on over live data is a data
  /// migration, not a config change: bring the stored identifiers to the same
  /// form in the same release.
  final String Function(String identifier) normalizeIdentifier;

  /// The one hash format DartWay writes — on registration, on password change,
  /// and when upgrading a legacy hash after a successful sign-in.
  final DwPasswordHasher passwordHasher;

  /// Formats DartWay can *read* but never writes: the hashes of a system the app
  /// is migrating off.
  ///
  /// A password hash is one-way, so users cannot be copied over with their
  /// passwords intact — and without their old algorithm they simply cannot log
  /// in. List the old algorithm here and DartWay lets them in with the password
  /// they have always used, then **rewrites the hash in [passwordHasher]'s
  /// format on the spot**. The plaintext exists only during that sign-in, which
  /// is why an offline migration script cannot do this and a lazy one must.
  ///
  /// The list is empty by default: an app that never migrated anything has no
  /// legacy formats, and DartWay refuses a hash nobody can read rather than
  /// guessing.
  ///
  /// Note that a legacy algorithm is usually much faster than bcrypt, so a
  /// not-yet-upgraded user answers measurably sooner. It leaks *who has not
  /// logged in since the migration* — not their password. Empty the list once
  /// the tail has migrated.
  final List<DwPasswordVerifier> legacyPasswordVerifiers;

  /// How many verification codes may be guessed for one auth request before it
  /// is burned.
  final int maxVerificationAttempts;

  /// How long a verification code stays valid after the request was created.
  final Duration verificationCodeLifetime;

  /// How many auth requests one identifier may open within
  /// [authRequestRateLimitWindow] before further ones are rate-limited.
  final int maxAuthRequestsPerIdentifier;
  final Duration authRequestRateLimitWindow;

  /// Callback invoked BEFORE verification code is sent or auth key is created.
  /// Return a [DwAuthFailReason] to reject the request, or `null` to proceed.
  /// Use this to block deleted, banned, or otherwise restricted users.
  final Future<DwAuthFailReason?> Function(
    Session session, {
    required DwAuthRequest authRequest,
    required UserProfileClass? userProfile,
  })?
  preAuthValidation;

  /// Final application-owned authorization check immediately before an auth key
  /// is inserted.
  ///
  /// Runs in the same short transaction as the key insert, so an app that locks
  /// and re-reads its user row through [transaction] here cannot be raced by a
  /// concurrent account deletion: the two serialise instead of passing each
  /// other. Returning a reason rejects issuance and rolls the insert back
  /// (surfaced as [DwAuthKeyIssuanceRejectedException]); returning `null`
  /// allows it.
  final Future<DwAuthFailReason?> Function(
    Session session, {
    required int userId,
    required Transaction transaction,
  })?
  preAuthKeyIssuance;

  /// Validates an external auth provider's credential (e.g. an Apple identity
  /// token) carried on a non-email [DwAuthRequest]. Return `null` when the
  /// credential is valid — DartWay then logs the user in, or registers them on
  /// first sign-in — or a [DwAuthFailReason] to reject the attempt.
  ///
  /// Leaving this unset rejects every non-email provider: an unconfigured
  /// provider must not be an open door.
  final Future<DwAuthFailReason?> Function(
    Session session, {
    required DwAuthRequest authRequest,
  })?
  verifyExternalCredential;

  /// Callback for triggering actions when a user signs in.
  final Future<void> Function(
    Session session, {
    required int userId,
    required bool isFirstSignIn,
  })?
  onSignInTrigger;

  /// Callback for generating a verification code.
  final Future<String> Function(
    Session session, {
    required DwAuthRequest verificationRequest,
  })?
  generateVerificationCodeMethod;

  /// Callback for sending validation message.
  final Future<void> Function(
    Session session, {
    required DwAuthRequest verificationRequest,
    required String verificationCode,
  })?
  sendVerificationCodeMethod;

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
