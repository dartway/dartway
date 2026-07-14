import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';

import 'specs/studio_zone_specs.dart';
import 'studio_personas.dart';

/// Everything this app declares about itself for DartWay Studio: its zones,
/// the screens in them and the demo personas. Rename the project and add your
/// zones as the app grows — Studio reads this, nothing else.
final appStudioManifest = StudioProjectManifest(
  projectName: 'DartWay Starter',
  zones: [appZoneStudioSpec, adminZoneStudioSpec, authZoneStudioSpec],
  personas: StudioPersonas.all,
  // Keep in sync with AppLocalizations.supportedLocales (lib/l10n) — drives
  // the locale switcher in Studio.
  supportedLocales: const ['en', 'ru'],
);
