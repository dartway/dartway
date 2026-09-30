import 'package:dartway_starter_flutter/core/dw_core.dart';
import 'package:dartway_starter_flutter/core/profile/my_profile.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// What the zone guards decide by. A record, so the router re-runs its guards
/// only when one of these actually changes.
///
/// `isSignedIn` is known from the stored session at start, before the server
/// has answered: a signed-in user opens straight into the app. `role` is the
/// signed-in user's role — `null` while signed out and while the profile has
/// not loaded yet; a role an admin changes arrives live.
typedef AppRouterState = ({bool isSignedIn, UserRole? role});

/// The router follows this provider (`DwAppRouter.routerState`).
final appRouterStateProvider = Provider<AppRouterState>(
  (ref) => (
    isSignedIn: ref.watch(dw.accountId) != null,
    role: ref.watch(myProfileProvider.select((profile) => profile.value?.role)),
  ),
);
