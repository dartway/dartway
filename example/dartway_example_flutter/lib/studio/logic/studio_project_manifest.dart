import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';

import 'specs/studio_zone_specs.dart';

/// Everything this app declares about itself for DartWay Studio. Demo
/// personas are NOT declared here — test users and their codes are configured
/// in Studio, so the public web build ships no test accounts.
final exampleStudioManifest = StudioProjectManifest(
  projectName: 'DartWay Example — Fitness Club',
  zones: [clubZoneStudioSpec, adminZoneStudioSpec, authZoneStudioSpec],
  // Keep in sync with AppLocalizations.supportedLocales (lib/l10n) — drives
  // the locale switcher in Studio.
  supportedLocales: const ['en', 'ru'],
);
