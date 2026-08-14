import 'dart:io';

import 'package:dartway_starter_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

/// The `config/passwords.yaml` key naming the first administrator.
const bootstrapAdminIdentifierKey = 'bootstrapAdminIdentifier';

/// Brings the declared first administrator into existence, on every boot.
///
/// The admin role is granted by an admin, which leaves the very first one with
/// nowhere to come from. Declaring it per environment is that somewhere — and
/// the declaration belongs in `config/passwords.yaml` rather than in a constant
/// here, for two reasons. It is a different person on every environment while
/// the code base is one; and whoever can *receive* the one-time code on that
/// identifier becomes the admin, so a default shipped in a public template
/// would hand every project that forgot to change it an administrator whose
/// channel a stranger controls. Hence: no default, and empty is a valid state.
///
/// Idempotent by design — it acts only when the declared identifier is not an
/// admin yet, so restarts stay quiet and an address demoted through the admin
/// panel is back on the next start.
Future<void> bootstrapAdmin(Serverpod pod) async {
  final identifier = pod.server.passwords[bootstrapAdminIdentifierKey]?.trim();
  if (identifier == null || identifier.isEmpty) {
    stdout.writeln(
      'No administrator is declared: set $bootstrapAdminIdentifierKey in '
      'config/passwords.yaml to reach the admin panel.',
    );
    return;
  }

  final session = await pod.createSession(enableLogging: false);
  try {
    // Case-insensitive, and with no wildcards in the pattern: the identifier is
    // typed twice by a human — once into the config, once on the sign-in screen.
    final existing = await UserProfile.db.findFirstRow(
      session,
      where: (t) => t.userIdentifier.ilike(identifier),
    );
    if (existing == null) {
      await UserProfile.db.insertRow(
        session,
        UserProfile(
          userIdentifier: identifier,
          phone: identifier,
          firstName: 'Admin',
          role: UserRole.admin,
          agreedForMarketingCommunications: false,
          conditionsAcceptedAt: DateTime.now(),
        ),
      );
      stdout.writeln('Administrator created: $identifier');
    } else if (existing.role != UserRole.admin) {
      // copyWith, never a model rebuilt field by field: the name, the avatar and
      // the serverOnly fields this profile already carries have to survive the
      // promotion. See `dartway-clean-code` §1.10 and the `model_rebuild_by_
      // constructor` lint.
      await UserProfile.db.updateRow(
        session,
        existing.copyWith(role: UserRole.admin),
      );
      stdout.writeln('Administrator promoted: $identifier');
    }
  } catch (e, stackTrace) {
    // Never take the server down over this step: the database may still be
    // coming up, and the app is perfectly able to serve everyone else.
    stderr.writeln('Could not ensure the administrator: $e\n$stackTrace');
  } finally {
    await session.close();
  }
}
