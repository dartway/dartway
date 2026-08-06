import 'package:dartway_example_client/dartway_example_client.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'dw_core.dart';

/// Shorthand for the framework's profile providers. `dw` is typed with this
/// project's [UserProfile], so `dw.requireUserProfileProvider` already returns
/// it — these getters only spare you the `ref.watch(...)` around it.
///
/// Both throw when nobody is signed in: use them under an authenticated
/// subtree (`DwUserAsyncScope`). Where the user may be signed out, read
/// `dw.userProfileProvider`; to rebuild on one field only, watch
/// `dw.requireUserProfileProvider.select(...)` directly.
extension UserProfileWidgetRefExtension on WidgetRef {
  UserProfile get watchUserProfile => watch(dw.requireUserProfileProvider);

  UserProfile get readUserProfile => read(dw.requireUserProfileProvider);
}

extension UserProfileRefExtension on Ref {
  UserProfile get watchUserProfile => watch(dw.requireUserProfileProvider);

  UserProfile get readUserProfile => read(dw.requireUserProfileProvider);
}
