// import 'dart:convert';

// import 'package:crypto/crypto.dart';
// import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
// import 'package:serverpod/serverpod.dart';

// import 'dw_phone_auth_config.dart';

// class DwPhoneAuthOtpUtils {
//   static bool verifyHashData(
//     Session session, {
//     required String hashedData,
//     required String phoneNumber,
//     required String otp,
//   }) {
//     /// Split the string data into hash and expiration time

//     var storedExpirationTime = getHashExpirationTime(hashedData);

//     if (!DateTime.now().isBefore(storedExpirationTime)) {
//       return false;
//     }

//     /// Creates new hash from the data and compares it to the stored hash.
//     var hash = generateHashData(
//       phoneNumber: phoneNumber,
//       otp: otp,
//       expirationTime: storedExpirationTime,
//     );

//     var isValid = hash == hashedData;

//     if (!isValid) {
//       session.log(
//         "Expected hash for $phoneNumber with otp $otp was $hashedData but actual hash wah $hash",
//       );
//       session.db.insertRow(
//         DwPhoneFailedSignIn(
//           phoneNumber: phoneNumber,
//           time: DateTime.now(),
//           ipAddress: (session as MethodCallSession).httpRequest.remoteIpAddress,
//         ),
//       );
//     }

//     return isValid;
//   }

//   static DateTime getHashExpirationTime(String hash) {
//     var parts = hash.split('@');
//     if (parts.length != 2) {
//       throw Exception(
//         'Invalid hash format: $hash. Expected format: <hash>@<expirationTime>',
//       );
//     }
//     var storedExpirationTime = DateTime.parse(parts[1]);
//     return storedExpirationTime;
//   }

//   static String generateHashData(
//       {required String phoneNumber,
//       required String otp,
//       DateTime? expirationTime}) {
//     var secretHashKey = DwPhoneAuthConfig.current.secretHashKey;

//     expirationTime ??= DateTime.now().add(
//       DwPhoneAuthConfig.current.verificationRequestExpirationTime,
//     );

//     var dataToHash = '$phoneNumber$otp$secretHashKey';
//     var hmac = Hmac(sha256, utf8.encode(secretHashKey));
//     var digest = hmac.convert(utf8.encode(dataToHash));
//     var hashedData = digest.toString();

//     var hash = '$hashedData@${expirationTime.toIso8601String()}';

//     return hash;
//   }
// }
