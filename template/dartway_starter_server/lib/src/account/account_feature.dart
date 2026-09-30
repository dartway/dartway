import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_server/src/profile/profile_changes.dart';

/// An account's life in the app: the profile it is created with and what its
/// deletion takes (`AccountAuth`, the sign-in hooks the server's library hands to
/// `DwAppServer(auth:)`), and the administrator made at every start.
///
/// It sits at the top of the features: it imports what an account's life
/// touches — the profile, the admin dashboard — and no feature imports it.
/// That is why the hooks are a feature and not `core/`: every feature imports
/// `core/`, and `core/` imports none.
///
/// [adminIdentifier] is made an administrator at every start
/// (`DwFirstAdministrator`): `bin/server.dart` passes `DW_ADMIN_IDENTIFIER`,
/// read into `DwServerEnvironment.adminIdentifier`.
DwServerFeature accountFeature({required String? adminIdentifier}) =>
    DwServerFeature(
      'account',
      startup: [
        DwFirstAdministrator(
          grant: ProfileChanges.grantAdmin,
          identifier: adminIdentifier,
        ),
      ],
    );
