import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../dw_core.dart';

/// The signed-in member's profile, live: `AsyncData(null)` while signed out.
///
/// It follows the member's profile channel, so a role an admin changes or a
/// name edited on another device arrives here without a refetch.
final myProfileProvider = Provider<AsyncValue<UserProfile?>>((ref) {
  final accountId = ref.watch(dw.accountId);
  if (accountId == null) return const AsyncData(null);
  return ref.watch(dw.request(GetMyProfile(accountId: accountId)));
});

/// Hands the signed-in profile to the screens below it, loaded.
///
/// Placed by `SignedInGate`, which renders nothing of the app until the
/// profile is there — so a screen reads `context.profile` and never meets a
/// loading state or a null.
class SignedInProfile extends InheritedWidget {
  const SignedInProfile({
    required this.profile,
    required super.child,
    super.key,
  });

  /// `null` only while signed out, when no screen that reads it is shown.
  final UserProfile? profile;

  @override
  bool updateShouldNotify(SignedInProfile oldWidget) =>
      profile != oldWidget.profile;
}

extension SignedInProfileContext on BuildContext {
  /// The signed-in member's profile. Rebuilds the caller when it changes.
  UserProfile get profile {
    final profile =
        dependOnInheritedWidgetOfExactType<SignedInProfile>()?.profile;
    assert(
      profile != null,
      'context.profile was read outside a signed-in SignedInGate. Only the '
      'screens of the signed-in zones may read it.',
    );
    return profile!;
  }
}
