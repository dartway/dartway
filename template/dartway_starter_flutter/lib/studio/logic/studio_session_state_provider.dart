import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/user_profile_provider.dart';
import 'studio_persona_switcher.dart';
import 'studio_personas.dart';

part 'studio_session_state_provider.g.dart';

/// The session as reported to Studio: signed-in state, the matching declared
/// persona and whether a persona switch is in flight.
@riverpod
StudioSessionState studioSessionState(Ref ref) {
  final profile = ref.watch(userProfileProvider);
  final isBusy = ref.watch(studioPersonaSwitcherProvider);

  if (profile == null) {
    return StudioSessionState(isSignedIn: false, isBusy: isBusy);
  }
  return StudioSessionState(
    isSignedIn: true,
    activePersonaId: StudioPersonas.byIdentifier(profile.phone)?.id,
    displayLabel: profile.firstName,
    isBusy: isBusy,
  );
}
