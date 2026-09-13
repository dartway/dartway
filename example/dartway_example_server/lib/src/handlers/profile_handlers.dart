import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_server/dartway_server.dart';

import '../../generated/dw_schema.dart';
import '../entities/people.dart';
import '../example_context.dart';
import '../projections.dart';

final profileHandlers = <DwHandler>[
  DwHandler.request<GetMyProfile, ProfileView?>(
    access: DwAccess.signedIn,
    handle: (ctx, request) async {
      if (request.accountId != ctx.requireAccountId) {
        ctx.refuse(DwCoreRefusal.forbidden);
      }
      return Views.profile(await ctx.profile);
    },
  ),

  DwHandler.command<UpdateMyProfile, ProfileView>(
    access: DwAccess.signedIn,
    handle: (ctx, command) async {
      final current = await ctx.profile;
      final firstName = command.firstName?.trim();
      if (firstName != null && firstName.isEmpty) {
        ctx.refuse(ExampleRefusal.firstNameRequired, field: 'firstName');
      }
      final updated = await ctx.db.userProfiles.update(
        current.copyWith(
          firstName: firstName,
          lastName: command.lastName,
          gender: command.gender,
          imageUrl: command.imageUrl,
        ),
      );
      final view = Views.profile(updated);
      ctx.publish(DwChannel(ExampleChannel.profile, updated.accountId), view);
      ctx.publish(const DwChannel(ExampleChannel.admin), view);
      return view;
    },
  ),
];
