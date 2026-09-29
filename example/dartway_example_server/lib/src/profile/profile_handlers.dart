import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../../generated/dw_schema.dart';
import '../core/call_context.dart';
import 'profile_objects.dart';
import 'profile_publications.dart';
import 'profile_rows.dart';

final profileHandlers = <DwCallHandler>[
  /// The caller's own profile. "My" profile names no account: the caller's
  /// is the only one it reads.
  DwCallHandler.single<GetMyProfile, UserProfile>(
    access: DwAccessRule.signedIn,
    handle: (ctx, request) async => ProfileObjects.profile(await ctx.profile),
  ),

  /// Changes the caller's name and gender; publishes the profile to its owner
  /// and to the admins' members table.
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
      return ProfilePublications.profile(ctx, updated);
    },
  ),
];
