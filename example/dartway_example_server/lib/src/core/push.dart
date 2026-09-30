import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_server/dartway_push_server.dart';

import '../../generated/dw_schema.dart';
import 'environment.dart';

/// Push notifications: the module, and the providers the environment enables.
abstract final class AppPush {
  /// Push for the club. News goes only to members who agreed to marketing:
  /// the rule runs when deliveries fall due, once per batch, with one query.
  static DwPushModule module({
    List<DwPushProvider> providers = const [],
    DwPushSettings settings = const DwPushSettings(),
  }) => DwPushModule(
    providers: providers,
    settings: settings,
    eligibility: (ctx, notice, accountIds) async {
      switch (notice.categoryIn(DartwayExamplePushCategory.values)) {
        case DartwayExamplePushCategory.news:
          final agreed = {
            for (final profile in await ctx.db.userProfiles.find(
              where: (t) =>
                  t.accountId.inList(accountIds) &
                  t.agreedForMarketing.equals(true),
            ))
              profile.accountId,
          };
          return {
            for (final id in accountIds)
              if (!agreed.contains(id)) id: DwPushDecision.skip,
          };
        case DartwayExamplePushCategory.bookingReminder || null:
          return const {};
      }
    },
  );

  /// The providers [environment] enables; none without their variables, and
  /// then devices are recorded as having no provider.
  static List<DwPushProvider> providers(AppPushEnvironment environment) => [
    if (environment.fcmServiceAccountFile case final file?)
      DwFcmProvider(
        account: DwFcmServiceAccount.fromJson(File(file).readAsStringSync()),
        webLinkBase: environment.fcmWebLinkBase,
      ),
    if (environment.ruStore case (:final projectId, :final serviceToken)?)
      DwRuStoreProvider(projectId: projectId, serviceToken: serviceToken),
  ];
}
