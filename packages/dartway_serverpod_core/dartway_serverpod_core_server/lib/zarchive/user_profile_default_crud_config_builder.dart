// part of '../core/dw_core.dart';

// userProfileDefaultCrudConfigBuilder<UserProfileClass extends TableRow>(
//   Table table,
//   Future<UserProfileClass> Function({
//     required int userInfoId,
//     required String userIdentifier,
//     required Map<String, String> registrationExtraData,
//   }) userProfileConstructor,
// ) =>
//     DwCrudConfig<UserProfileClass>(
//       table: table,
//       getModelConfigs: [
//         DwGetModelConfig(
//           filterPrototype: DwBackendFilter.equalsPrototype(
//             fieldName: DwCoreConst.userInfoIdColumnName,
//           ),
//           createIfMissing: (session, filter) async {
//             final userInfoId = filter.fieldValue!;

//             final userInfo = await UserInfo.db.findById(session, userInfoId);

//             if (userInfo == null) return null;

//             // final dwDataStash = await DwAuthDataStash.db.findFirstRow(
//             //   session,
//             //   where: (t) =>
//             //       t.identifier.equals(userInfo.userIdentifier) &
//             //       t.type
//             //           .equals(DwPhoneVerificationRequestType.registration.name),
//             // );

//             // if (dwDataStash == null) {
//             //   throw Exception(
//             //     'No registration data found for user ${userInfo.userIdentifier}',
//             //   );
//             // }

//             final profile = await session.db.insertRow<UserProfileClass>(
//               await userProfileConstructor(
//                 userInfoId: userInfoId,
//                 userIdentifier: userInfo.userIdentifier,
//                 registrationExtraData: {},
//               ),
//             );

//             return profile;
//           },
//         ),
//       ],
//     );
