// import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
// import 'package:flutter/foundation.dart';

// class DwCore<UserProfileClass extends SerializableModel> {
//   static late final Caller endpointCaller;

//   // static late final SessionManager serverpodSessionManager;

//   // static DwBackendFilter prepareUserProfileFilter(int serverpodUserInfoId) =>
//   //     DwBackendFilter<int>.value(
//   //       type: DwBackendFilterType.equals,
//   //       fieldName: 'userId',
//   //       fieldValue: serverpodUserInfoId,
//   //     );

//   static void registerSignedInUser(List<DwModelWrapper> wrappedModels) async {
//     try {
//       /// TODO: Auth Rework
//       // final authResponse =
//       //     wrappedModels
//       //             .firstWhereOrNull(
//       //               (wrapper) => wrapper.model is auth.AuthenticationResponse,
//       //             )
//       //             ?.model
//       //         as auth.AuthenticationResponse?;

//       // if (authResponse != null &&
//       //     authResponse.success &&
//       //     authResponse.userInfo != null &&
//       //     authResponse.keyId != null &&
//       //     authResponse.key != null) {
//       //   await DwCore.serverpodSessionManager.registerSignedInUser(
//       //     authResponse.userInfo!,
//       //     authResponse.keyId!,
//       //     authResponse.key!,
//       //   );
//       // }
//     } catch (e, st) {
//       if (kDebugMode) debugPrint('processAuth error: $e\n$st');
//     }
//   }
// }
