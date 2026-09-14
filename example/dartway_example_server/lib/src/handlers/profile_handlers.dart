import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';

import '../../generated/dw_schema.dart';
import '../club_objects.dart';
import '../entities/people.dart';
import '../example_context.dart';
import 'admin_handlers.dart';

final profileHandlers = <DwCallHandler>[
  DwCallHandler.single<GetMyProfile, UserProfile>(
    access: ExampleAccess.ownAccount<GetMyProfile>((r) => r.accountId),
    handle: (ctx, request) async => ClubObjects.profile(await ctx.profile),
  ),

  DwCallHandler.command<UpdateMyProfile, UserProfile>(
    access: DwAccessRule.signedIn,
    handle: (ctx, command) async {
      final current = await ctx.profile;
      final updated = await ctx.db.userProfiles.update(
        current.copyWith(
          firstName: command.firstName?.trim(),
          lastName: command.lastName,
          gender: command.gender,
          imageUrl: command.imageUrl,
        ),
      );
      final profile = ClubObjects.profile(updated);
      ctx
        ..publish(
          DwLiveChannel(ExampleChannel.profile, updated.accountId),
          profile,
        )
        ..publish(adminChannel, profile);
      return profile;
    },
  ),
];
