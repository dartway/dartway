import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../dw_core.dart';
import 'studio_persona_switcher.dart';

/// The session as reported to Studio: signed-in state, who it is (by phone —
/// Studio matches it against its configured personas) and whether a requested
/// sign-in is in flight.
final studioSessionStateProvider = Provider<StudioSessionState>((ref) {
  final profile = ref.watch(dw.userProfileProvider);
  final isBusy = ref.watch(studioPersonaSwitcherProvider);

  if (profile == null) {
    return StudioSessionState(isSignedIn: false, isBusy: isBusy);
  }
  return StudioSessionState(
    isSignedIn: true,
    userIdentifier: profile.phone,
    displayLabel: profile.firstName,
    isBusy: isBusy,
  );
});
