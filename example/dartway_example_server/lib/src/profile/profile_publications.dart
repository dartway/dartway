import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_server/src/core/channels.dart';
import 'package:dartway_example_server/src/profile/profile_objects.dart';
import 'package:dartway_example_server/src/profile/profile_rows.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

/// What a changed profile is published as, and to whom — one place, so every
/// handler and hook that changes a profile tells the same listeners the same
/// thing.
abstract final class ProfilePublications {
  /// A changed profile to its owner's own profile and to the admins' members
  /// table. Answers the profile as clients see it.
  static UserProfile profile(DwCallContext ctx, UserProfileRow row) {
    final profile = ProfileObjects.profile(row);
    ctx
      ..publish(AppChannels.profileOf(row.ownerAccountId), profile)
      ..publish(AppChannels.admin, profile);
    return profile;
  }

  /// A member who left, to the admins' members table, which holds the row and
  /// must show what it became — not to its owner, who is gone.
  static UserProfile tombstone(DwCallContext ctx, UserProfileRow row) {
    final profile = ProfileObjects.profile(row);
    ctx.publish(AppChannels.admin, profile);
    return profile;
  }
}
