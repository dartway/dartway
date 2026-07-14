import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_starter_client/dartway_starter_client.dart';

import 'dw_core.dart';

/// Currently signed-in profile, derived from the DartWay session.
/// `null` while signed out or before the session is initialized.
final userProfileProvider = Provider<UserProfile?>((ref) {
  final session = dw.sessionProvider;
  if (session == null) return null;
  return ref.watch(session).signedInUserProfile;
});

extension UserProfileWidgetRefExtension on WidgetRef {
  /// Non-null current profile. Only use inside an authenticated subtree
  /// (e.g. under [DwUserAsyncScope]); throws if no user is signed in.
  UserProfile get watchUserProfile => watch(userProfileProvider)!;

  UserProfile get readUserProfile => read(userProfileProvider)!;
}

extension UserProfileRefExtension on Ref {
  UserProfile get watchUserProfile => watch(userProfileProvider)!;

  UserProfile get readUserProfile => read(userProfileProvider)!;
}
