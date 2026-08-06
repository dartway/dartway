import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../domain/dw_session_state_model.dart';

/// The profile pair `DwCore` hands out as `dw.userProfileProvider` and
/// `dw.requireUserProfileProvider`.
///
/// Held apart from `DwCore` because all these providers need from a session is
/// something listenable carrying a [DwSessionStateModel] — which lets them be
/// built over a stand-in, and a core that admits only one instance per process
/// leaves no other way to exercise them.
class DwUserProfileProviders<UserProfileClass extends SerializableModel> {
  /// [_sessionProvider] is `null` when the app runs without an auth key
  /// manager: then nobody is ever signed in, and that is not an error.
  DwUserProfileProviders(this._sessionProvider);

  final ProviderListenable<DwSessionStateModel<UserProfileClass>>?
  _sessionProvider;

  late final Provider<UserProfileClass?> userProfile =
      Provider<UserProfileClass?>((ref) {
        final sessionProvider = _sessionProvider;
        if (sessionProvider == null) return null;
        return ref.watch(
          sessionProvider.select((state) => state.signedInUserProfile),
        );
      });

  late final Provider<UserProfileClass> requireUserProfile =
      Provider<UserProfileClass>((ref) {
        final signedInUserProfile = ref.watch(userProfile);
        if (signedInUserProfile == null) {
          throw StateError(
            'No signed-in user profile. dw.requireUserProfileProvider is only '
            'valid under an authenticated subtree (DwUserAsyncScope); where '
            'the user may be signed out, read dw.userProfileProvider instead.',
          );
        }
        return signedInUserProfile;
      });
}
