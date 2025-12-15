// import 'package:dartway_serverpod_core_server/dartway_serverpod_core_server.dart';
// import 'package:serverpod/serverpod.dart';

// class DwAuth {
//   static Future<UserInfo?> createUser(
//     Session session, {
//     required String userIdentifier,
//     String? password,
//     String? passwordHash,
//   }) async {
//     if (password != null && passwordHash != null) {
//       throw Exception('Can not provide both password and passwordHash');
//     }

//     var userInfo = await Users.findUserByIdentifier(session, userIdentifier);

//     if (userInfo == null) {
//       userInfo = UserInfo(
//         userIdentifier: userIdentifier,
//         created: DateTime.now(),
//         scopeNames: [],
//         blocked: false,
//       );

//       session.log('creating user', level: LogLevel.debug);
//       userInfo = await Users.createUser(session, userInfo, 'email');
//       if (userInfo == null) return null;
//     }

//     if (password != null || passwordHash != null) {
//       // Check if there is email authentication in place already
//       var oldAuth = await EmailAuth.db.findFirstRow(
//         session,
//         where: (t) => t.userId.equals(userInfo?.id!),
//       );
//       if (oldAuth != null) {
//         return userInfo;
//       }

//       session.log(
//         'creating password (email) authentication',
//         level: LogLevel.debug,
//       );
//       passwordHash =
//           passwordHash ?? await Emails.generatePasswordHash(password!);
//       var auth = EmailAuth(
//         userId: userInfo.id!,
//         email: userIdentifier,
//         hash: passwordHash,
//       );

//       await EmailAuth.db.insertRow(session, auth);
//     }

//     await Users.invalidateCacheForUser(session, userInfo.id!);
//     userInfo = await Users.findUserByUserId(session, userInfo.id!);

//     session.log('returning created user', level: LogLevel.debug);
//     return userInfo;
//   }

//   static Future<bool> verifyPassword(
//       Session session, DwAuthRequest authRequest) async {
//     if (authRequest.password == null) {
//       return false;
//     }

//     final emailAuth = await EmailAuth.db.findFirstRow(
//       session,
//       where: (t) => t.email.equals(authRequest.userIdentifier),
//     );

//     if (emailAuth == null ||
//         emailAuth.hash !=
//             await Emails.generatePasswordHash(authRequest.password!)) {
//       return false;
//     }

//     return true;
//   }
// }
