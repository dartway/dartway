import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../dw_core.dart';
import '../profile/my_profile.dart';

/// Refresh listenable for the DartWay router: what the zone guards decide by,
/// notifying the router so the guards re-run whenever it changes.
class AppRouterState extends ChangeNotifier {
  AppRouterState(Ref ref) {
    ref.listen<int?>(dw.accountId, (_, accountId) {
      isSignedIn = accountId != null;
      notifyListeners();
    }, fireImmediately: true);
    ref.listen<UserRole?>(
      myProfileProvider.select((profile) => profile.value?.role),
      (_, next) {
        role = next;
        notifyListeners();
      },
      fireImmediately: true,
    );
  }

  /// Known from the stored session at start, before the server has answered:
  /// a signed-in user opens straight into the app.
  bool isSignedIn = false;

  /// The signed-in user's role — `null` while signed out and while the
  /// profile has not loaded yet. A role an admin changes arrives live.
  UserRole? role;
}
