import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../user_profile_provider.dart';
import '../user_profile_roles.dart';

/// True once a user profile is loaded (i.e. signed in).
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(userProfileProvider) != null;
});

/// True when the signed-in user is a club admin — gates the `/admin` zone.
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(userProfileProvider)?.isClubAdmin ?? false;
});

/// Refresh listenable for the DartWay router. Tracks sign-in and admin state and
/// notifies the router so zone guards re-run whenever either changes.
class AppRouterState extends ChangeNotifier {
  AppRouterState(this.ref) {
    ref.listen<bool>(
      isSignedInProvider,
      (_, next) {
        isSignedIn = next;
        notifyListeners();
      },
      fireImmediately: true,
    );
    ref.listen<bool>(
      isAdminProvider,
      (_, next) {
        isAdmin = next;
        notifyListeners();
      },
      fireImmediately: true,
    );
  }

  final Ref ref;

  bool isSignedIn = false;
  bool isAdmin = false;
}
