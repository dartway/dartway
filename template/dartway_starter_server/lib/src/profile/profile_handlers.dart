import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import '../../generated/dw_schema.dart';
import '../core/call_context.dart';
import 'profile_rows.dart';
import 'profile_objects.dart';
import 'profile_publications.dart';

final profileHandlers = <DwCallHandler>[
  /// The caller's own profile. "My" profile names no account: the caller's is
  /// the only one it reads.
  DwCallHandler.single<GetMyProfile, UserProfile>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async =>
        ProfileObjects.profile(ctx, await ctx.profile),
  ),

  /// Changes the caller's name, gender and photo — only their own finished
  /// upload. Publishes the profile to its owner and the admins; a replaced photo
  /// is deleted once the change commits.
  DwCallHandler.command<UpdateMyProfile, UserProfile>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      final current = (await ctx.db.userProfiles.findById(
        (await ctx.profile).id,
        lock: DwRowLock.forUpdate,
      ))!;
      final previousAvatar = current.avatarFileId;
      final avatar = command.avatarFileId;
      if (avatar.newValue case final fileId?) {
        // Only the caller's own finished avatar upload: a file id is a number
        // anyone can type.
        await ctx.files.requireOwned(
          fileId,
          DartwayStarterUpload.avatar,
          field: 'avatarFileId',
        );
      }
      final updated = await ctx.db.userProfiles.update(
        current.copyWith(
          firstName: command.firstName?.trim(),
          lastName: command.lastName.trimmedOrCleared,
          gender: command.gender,
          avatarFileId: avatar,
        ),
      );
      // The photo it replaced is nobody's any more: its object goes once this
      // transaction commits, rather than staying in the bucket for ever.
      if (previousAvatar != null && previousAvatar != updated.avatarFileId) {
        await ctx.files.delete(previousAvatar);
      }
      return ProfilePublications.profile(ctx, updated);
    },
  ),
];
