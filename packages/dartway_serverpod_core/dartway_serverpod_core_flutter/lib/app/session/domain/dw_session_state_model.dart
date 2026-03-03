import 'package:dartway_serverpod_core_client/dartway_serverpod_core_client.dart';

/// 🧠 UserProfile State Model.
/// Stores information about the current user and their ID.
class DwSessionStateModel<UserProfileClass extends SerializableModel> {
  final UserProfileClass? signedInUserProfile;
  final int? signedInUserId;

  const DwSessionStateModel({this.signedInUserProfile, this.signedInUserId});

  static const _noChange = Object();

  DwSessionStateModel<UserProfileClass> copyWith({
    Object? signedInUserProfile = _noChange,
    Object? signedInUserId = _noChange,
  }) {
    return DwSessionStateModel<UserProfileClass>(
      signedInUserProfile: identical(signedInUserProfile, _noChange)
          ? this.signedInUserProfile
          : signedInUserProfile as UserProfileClass?,
      signedInUserId: identical(signedInUserId, _noChange)
          ? this.signedInUserId
          : signedInUserId as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is DwSessionStateModel<UserProfileClass> &&
            other.signedInUserProfile == signedInUserProfile &&
            other.signedInUserId == signedInUserId);
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, signedInUserProfile, signedInUserId);

  @override
  String toString() {
    return 'DwSessionStateModel('
        'userId: $signedInUserId, '
        'userProfile: $signedInUserProfile'
        ')';
  }
}
