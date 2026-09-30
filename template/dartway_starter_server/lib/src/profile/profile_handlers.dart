import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import 'package:dartway_starter_server/generated/dw_schema.dart';
import 'package:dartway_starter_server/src/core/call_context.dart';
import 'package:dartway_starter_server/src/profile/profile_rows.dart';
import 'package:dartway_starter_server/src/profile/profile_objects.dart';
import 'package:dartway_starter_server/src/profile/profile_publications.dart';

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
        (await ctx.profile).id!,
        lock: DwRowLock.forUpdate,
      ))!;
      final previousAvatar = current.avatarFileId;
      final avatar = command.avatarFileId;
      if (avatar case DwSetField(:final value)) {
        // Only the caller's own finished avatar upload: a file id is a number
        // anyone can type.
        await ctx.files.requireOwned(
          value,
          DartwayStarterUpload.avatar,
          field: 'avatarFileId',
        );
      }
      final updated = await ctx.db.userProfiles.update(
        current.copyWith(
          firstName: command.firstName?.trim(),
          lastName: switch (command.lastName) {
            DwSetField(:final value) when value.trim().isEmpty =>
              const DwFieldPatch.clear(),
            DwSetField(:final value) => DwFieldPatch.set(value.trim()),
            final other => other,
          },
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
