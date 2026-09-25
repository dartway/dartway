import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../../generated/dw_schema.dart';
import '../club/club_objects.dart';
import 'profile_rows.dart';
import '../core/example_channels.dart';
import '../core/example_context.dart';
import '../admin/admin_handlers.dart';

final profileHandlers = <DwCallHandler>[
  DwCallHandler.single<GetMyProfile, UserProfile>(
    // "My" profile names no account: the caller's is the only one it reads.
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async => ClubObjects.profile(await ctx.profile),
  ),

  DwCallHandler.command<UpdateMyProfile, UserProfile>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      // Locked: two edits at once would each write the other's fields back.
      final current = (await ctx.db.userProfiles.findById(
        (await ctx.profile).id!,
        lock: DwRowLock.forUpdate,
      ))!;
      final updated = await ctx.db.userProfiles.update(
        current.copyWith(
          firstName: command.firstName?.trim(),
          lastName: command.lastName,
          gender: command.gender,
        ),
      );
      final profile = ClubObjects.profile(updated);
      ctx
        ..publish(ExampleChannels.profileOf(updated.ownerAccountId), profile)
        ..publish(adminChannel, profile);
      return profile;
    },
  ),
];
