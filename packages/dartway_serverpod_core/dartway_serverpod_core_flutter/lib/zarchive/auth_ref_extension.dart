// import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// extension AuthWidgetRefExtension on WidgetRef {
//   Future<bool> userExists({required String identifier}) async {
//     if (kDebugMode) debugPrint('Searching for user with $identifier');

//     final userInfo = await readMaybeModel<UserInfo>(
//       apiGroupOverride: DwCoreConst.dartwayInternalApi,
//       forceFetch: true,
//       filter: DwBackendFilter.value(
//         type: DwBackendFilterType.equals,
//         fieldName: DwCoreConst.userIdentifierColumnName,
//         fieldValue: identifier,
//       ),
//     );

//     return userInfo != null;
//   }
// }

// extension AuthRefExtension on Ref {
//   Future<bool> userExists({required String identifier}) async {
//     if (kDebugMode) debugPrint('Searching for user with $identifier');

//     final userInfo = await readMaybeModel<UserInfo>(
//       apiGroupOverride: DwCoreConst.dartwayInternalApi,
//       forceFetch: true,
//       filter: DwBackendFilter.value(
//         type: DwBackendFilterType.equals,
//         fieldName: DwCoreConst.userIdentifierColumnName,
//         fieldValue: identifier,
//       ),
//     );

//     return userInfo != null;
//   }
// }
