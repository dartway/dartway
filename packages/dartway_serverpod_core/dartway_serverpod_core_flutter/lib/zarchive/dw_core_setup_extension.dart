// import 'package:collection/collection.dart';
// import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart'
//     as dartway;
// import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
// import 'package:dartway_serverpod_core_flutter/socket_state/dw_socket_state.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../zarchive/dw_session_state.dart';

// enum UserIdMode { userProfileId, userInfoId }

// extension DwCoreSetupExtension on WidgetRef {
//   Future<bool>
//   initDartwayServerpodApp<UserProfileClass extends SerializableModel>({
//     required ServerpodClientShared client,
//     required Function() initRepositoryFunction,
//   }) async {
//     final dartwayCaller = client.moduleLookup.values.firstWhereOrNull(
//       (e) => e is dartway.Caller,
//     );

//     // final authCaller = client.moduleLookup.values.firstWhereOrNull(
//     //   (e) => e is auth.Caller,
//     // );

//     if (dartwayCaller == null) {
//       throw Exception(
//         'Dartway Core module not enabled, can not init app. Add dartway_serverpod_core module to the client',
//       );
//     }

//     DwCore.endpointCaller = dartwayCaller as dartway.Caller;
//     DwCoreServerpodClient.protocol = client.serializationManager;

//     await initRepositoryFunction();
//     // DwRepository.setupRepository(
//     //   defaultModel: auth.UserInfo(
//     //     id: DwRepository.mockModelId,
//     //     userIdentifier: 'Dartway',
//     //     created: DateTime.now(),
//     //     scopeNames: [],
//     //     blocked: false,
//     //   ),
//     // );

//     await read(dwSessionStateProvider.notifier).init(client: client);

//     return read(dwSocketStateProvider.notifier).init(client: client);
//   }
// }
