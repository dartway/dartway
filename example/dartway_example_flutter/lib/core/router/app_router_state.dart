import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../user_profile_provider.dart';

/// True once a user profile is loaded (i.e. signed in).
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(userProfileProvider) != null;
});

/// Refresh listenable for the DartWay router. Tracks sign-in state and notifies
/// the router so zone guards re-run whenever auth changes.
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
  }

  final Ref ref;

  bool isSignedIn = false;
}
