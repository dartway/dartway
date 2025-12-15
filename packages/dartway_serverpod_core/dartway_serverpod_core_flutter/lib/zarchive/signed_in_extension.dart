// import 'package:dartway_serverpod_core_flutter/dartway_serverpod_core_flutter.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../zarchive/dw_session_state.dart';

// extension SignedInExtension on Ref {
//   Future<bool> signOut({bool allDevices = false}) =>
//       read(dwSessionStateProvider.notifier).signOut(allDevices: allDevices);

//   bool get signedIn => watch(
//     dwSessionStateProvider.select((value) => value.signedInUserInfoId != null),
//   );
// }

// extension SignedInWidgetExtension on WidgetRef {
//   Future<bool> signOut({bool allDevices = false}) =>
//       read(dwSessionStateProvider.notifier).signOut(allDevices: allDevices);

//   bool get signedIn => watch(
//     dwSessionStateProvider.select((value) => value.signedInUserInfoId != null),
//   );
// }
