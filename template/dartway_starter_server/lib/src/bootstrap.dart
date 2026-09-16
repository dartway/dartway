import 'package:dartway_core_server/dartway_core_server.dart';
import 'package:dartway_starter_shared/dartway_starter_shared.dart';

import '../generated/dw_schema.dart';
import 'entities/people.dart';

/// The first administrator, named by the environment and made one at start.
abstract final class AppBootstrap {
  /// The environment variable naming the first administrator.
  static const adminVariable = 'APP_BOOTSTRAP_ADMIN';

  /// The declared first administrator's identifier in its stored form, or throws
  /// [ArgumentError] when it is neither a phone number nor an e-mail address.
  /// Checked before the server starts: a server with a mistyped admin must not
  /// come up quietly without one.
  static ({DwIdentifierKind kind, String identifier}) parseAdminIdentifier(
    String raw,
  ) {
    final kind = AuthIdentifier.kindOf(raw.trim());
    final identifier =
        AuthIdentifier.normalize(kind, raw) ??
        (throw ArgumentError.value(
          raw,
          adminVariable,
          'is neither a phone number nor an e-mail address',
        ));
    return (kind: kind, identifier: identifier);
  }

  /// Brings the declared first administrator into existence, on every start.
  ///
  /// The admin role is granted by an admin, which leaves the very first one with
  /// nowhere to come from. Declaring it per environment is that somewhere; there
  /// is no default, because whoever receives the code on that identifier becomes
  /// the admin — a default shipped in a public template would hand every project
  /// that forgot it an administrator a stranger controls.
  ///
  /// Idempotent: it acts only when the identifier is not an admin yet, so
  /// restarts stay quiet and an address demoted in the panel is back on the next
  /// start. Answers whether it changed anything.
  static Future<bool> ensureAdministrator(
    DwAppServer server,
    String rawIdentifier,
  ) async {
    final (:kind, :identifier) = AppBootstrap.parseAdminIdentifier(
      rawIdentifier,
    );
    // Created through the framework like any sign-in, so the account, its
    // identifier and its profile appear together (`onAccountCreated` runs with a
    // tool origin).
    final (:accountId, :created) = await server.accounts.ensure(
      kind,
      identifier,
    );
    final profile = (await server.db.userProfiles.findFirst(
      where: (t) => t.accountId.equals(accountId),
    ))!;
    if (profile.role == UserRole.admin) return created;
    await server.db.userProfiles.update(
      profile.copyWith(
        role: UserRole.admin,
        firstName: profile.firstName.isEmpty ? 'Admin' : null,
      ),
    );
    return true;
  }
}
