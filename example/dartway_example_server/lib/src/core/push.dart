import 'dart:io';

import 'package:dartway_example_server/src/core/environment.dart';
import 'package:dartway_push_server/dartway_push_server.dart';

/// Push notifications: the module, and the providers the environment enables.
abstract final class AppPush {
  /// Push for the club. Who a notice reaches is [eligibility], the profile
  /// feature's rule (`ProfileAccess.pushEligibility`) — `core/` imports no
  /// feature, so the library hands it in; required, because a default would
  /// send news to members who never agreed to it.
  static DwPushModule module({
    List<DwPushProvider> providers = const [],
    DwPushSettings settings = const DwPushSettings(),
    required DwPushEligibility eligibility,
  }) => DwPushModule(
    providers: providers,
    settings: settings,
    eligibility: eligibility,
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
