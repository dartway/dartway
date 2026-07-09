import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';

import 'specs/studio_zone_specs.dart';
import 'studio_personas.dart';

/// Everything this app declares about itself for DartWay Studio.
final exampleStudioManifest = StudioProjectManifest(
  projectName: 'DartWay Example — Fitness Club',
  zones: [clubZoneStudioSpec, adminZoneStudioSpec, authZoneStudioSpec],
  personas: StudioPersonas.all,
  // Keep in sync with AppLocalizations.supportedLocales (lib/l10n) — drives
  // the locale switcher in Studio.
  supportedLocales: const ['en', 'ru'],
);
