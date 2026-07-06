import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';

/// Fixed dev OTP accepted by the example server in development run mode.
/// Keep in sync with _devVerificationCode in
/// dartway_example_server/lib/src/dartway/dartway_core.dart.
const studioDevOtpCode = '000000';

/// Seeded demo personas declared for Studio's persona switcher
/// (see dartway_example_server/bin/seed_dev.dart).
abstract final class StudioPersonas {
  static const clientIvan = StudioPersonaSpec(
    id: 'client-ivan',
    label: 'Client · Ivan',
    identifier: '79990000003',
  );

  static const coachMaria = StudioPersonaSpec(
    id: 'coach-maria',
    label: 'Coach · Maria',
    identifier: '79990000002',
  );

  static const adminAlex = StudioPersonaSpec(
    id: 'admin-alex',
    label: 'Admin · Alex',
    identifier: '79990000001',
  );

  static const all = [clientIvan, coachMaria, adminAlex];

  static StudioPersonaSpec? byId(String id) {
    for (final persona in all) {
      if (persona.id == id) return persona;
    }
    return null;
  }

  static StudioPersonaSpec? byIdentifier(String identifier) {
    for (final persona in all) {
      if (persona.identifier == identifier) return persona;
    }
    return null;
  }
}
