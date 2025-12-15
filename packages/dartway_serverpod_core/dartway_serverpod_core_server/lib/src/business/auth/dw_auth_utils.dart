import 'dart:convert';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
import 'package:serverpod/serverpod.dart';

class DwAuthUtils {
  static final Random _random = Random.secure();

  /// Generates a secure random string of the specified length.
  ///
  /// The resulting String is `base64` encoded and capped at [length],
  /// and thus has a lower entropy than [length] bytes.
  static String generateRandomString([int length = 32]) {
    var values = List<int>.generate(length, (int i) => _random.nextInt(256));
    return base64Url.encode(values).substring(0, length);
  }

  static String hashString(String secret, String string) {
    return sha256.convert(utf8.encode(secret + string)).toString();
  }

  static String hashAuthKey(String key) {
    return hashString(DwCore.instance.auth!.config.authKeySalt, key);
  }

  static String hashPassword(String password) =>
      BCrypt.hashpw(password, BCrypt.gensalt());

  static bool verifyPassword(String password, String hash) =>
      BCrypt.checkpw(password, hash);

  static String hashVerificationCode(String verificationCode) {
    return hashString(
      DwCore.instance.auth!.config.verificationCodeSalt,
      verificationCode,
    );
  }

  static String generateSecureToken([int length = 32]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Default OTP generation callback that generates a random 6-digit OTP and prints it to the server.
  static Future<String> defaultVerificationCodeGenerationMethod(
    Session session, {
    required DwAuthRequest verificationRequest,
  }) async {
    final otp = randomDigits(6);
    // print('Generated OTP for $number: $otp');
    return otp;
  }

  // /// Generates a new DwPhoneAuthConfig.current.validationCodeLength digit OTP.
  static String randomDigits(int length) {
    return Random().nextString(length: length, chars: '0123456789');
  }
}

/// An extension for generating random strings.
extension on Random {
  /// Returns a random [String] consisting of letters and numbers, by default
  /// the [length] of the string will be 16 characters.
  String nextString({
    int length = 16,
    String chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890',
  }) {
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(nextInt(chars.length))),
    );
  }
}
