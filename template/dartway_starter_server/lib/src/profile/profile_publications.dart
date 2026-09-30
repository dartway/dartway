import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import 'package:dartway_starter_server/src/core/channels.dart';
import 'package:dartway_starter_server/src/profile/profile_rows.dart';
import 'package:dartway_starter_server/src/profile/profile_objects.dart';

/// What a changed profile is published as, and to whom: the objects each
/// channel carries, computed in one place so every handler that changes a
/// profile tells the same listeners the same thing.
abstract final class ProfilePublications {
  /// A changed profile to everyone who shows it: its owner's own profile (and so
  /// the owner's router guards), the members table and the user card of the
  /// admins. Answers the profile as clients see it.
  static Future<UserProfile> profile(
    DwCallContext ctx,
    UserProfileRow row,
  ) async {
    final card = await ProfileObjects.card(ctx, row);
    ctx
      ..publish(AppChannels.profileOf(row.accountId), card.profile)
      ..publish(AppChannels.admin, card.profile)
      ..publish(AppChannels.admin, card);
    return card.profile;
  }
}
