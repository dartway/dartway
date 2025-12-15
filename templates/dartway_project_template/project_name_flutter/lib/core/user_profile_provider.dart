import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:project_name_client/project_name_client.dart';

/// Current signed-in user's profile.
/// Must be overridden inside [SignedInUserScope] or a similar widget.
final userProfileProvider = Provider<UserProfile?>(
  (ref) {
    throw UnimplementedError('userProfileProvider must be overridden');
  },
);

UserProfile requireUserProfile(UserProfile? userProfile) {
  if (userProfile == null) {
    throw StateError('User profile required but missing');
  }
  return userProfile;
}

/// Extensions for [WidgetRef] — usually used inside widgets.
extension UserProfileWidgetRefExtension on WidgetRef {
  /// Safe access to the current user profile (may be null).
  UserProfile? get watchMaybeUserProfile => watch(userProfileProvider);

  /// Safe read access to the current user profile (may be null, non-reactive).
  UserProfile? get readMaybeUserProfile => read(userProfileProvider);

  /// Required access to the current user profile (throws if null).
  UserProfile get watchUserProfile =>
      requireUserProfile(watch(userProfileProvider));

  /// Required read access to the current user profile (throws if null, non-reactive).
  UserProfile get readUserProfile =>
      requireUserProfile(read(userProfileProvider));
}

/// Extensions for [Ref] — convenient for use inside providers or services.
extension UserProfileRefExtension on Ref {
  /// Safe access to the current user profile (may be null).
  UserProfile? get watchMaybeUserProfile => watch(userProfileProvider);

  /// Safe read access to the current user profile (may be null, non-reactive).
  UserProfile? get readMaybeUserProfile => read(userProfileProvider);

  /// Required access to the current user profile (throws if null).
  UserProfile get watchUserProfile =>
      requireUserProfile(watch(userProfileProvider));

  /// Required read access to the current user profile (throws if null, non-reactive).
  UserProfile get readUserProfile =>
      requireUserProfile(read(userProfileProvider));
}
