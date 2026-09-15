import 'dart:io';

import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_example_shared/dartway_example_shared.dart';
import 'package:dartway_push_server/dartway_push_server.dart';

import '../generated/dw_schema.dart';

/// Push for the club. News goes only to members who agreed to marketing:
/// the rule runs when deliveries fall due, once per batch, with one query.
DwPushModule examplePush({
  List<DwPushProvider> providers = const [],
  DwPushSettings settings = const DwPushSettings(),
}) => DwPushModule(
  providers: providers,
  settings: settings,
  eligibility: (ctx, notice, accountIds) async {
    switch (notice.categoryIn(ExamplePushCategory.values)) {
      case ExamplePushCategory.news:
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
      case null:
        return const {};
    }
  },
);

/// The providers configured by the environment; none without their
/// variables, and then devices are recorded as having no provider:
///
/// - `FCM_SERVICE_ACCOUNT_FILE` — the Firebase service account JSON file;
///   `FCM_WEB_LINK_BASE` — the web app's https origin, for web clicks;
/// - `RUSTORE_PUSH_PROJECT_ID` and `RUSTORE_PUSH_SERVICE_TOKEN` — both, or
///   neither.
List<DwPushProvider> examplePushProviders(Map<String, String> env) {
  final fcmFile = env['FCM_SERVICE_ACCOUNT_FILE'];
  final ruStoreProject = env['RUSTORE_PUSH_PROJECT_ID'];
  final ruStoreToken = env['RUSTORE_PUSH_SERVICE_TOKEN'];
  if ((ruStoreProject == null) != (ruStoreToken == null)) {
    throw StateError(
      'RuStore push needs both RUSTORE_PUSH_PROJECT_ID and '
      'RUSTORE_PUSH_SERVICE_TOKEN, or neither',
    );
  }
  return [
    if (fcmFile != null)
      DwFcmProvider(
        account: DwFcmServiceAccount.fromJson(File(fcmFile).readAsStringSync()),
        webLinkBase: switch (env['FCM_WEB_LINK_BASE']) {
          final base? => Uri.parse(base),
          null => null,
        },
      ),
    if (ruStoreProject != null)
      DwRuStoreProvider(projectId: ruStoreProject, serviceToken: ruStoreToken!),
  ];
}
