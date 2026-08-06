import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';

import 'specs/studio_zone_specs.dart';

/// Everything this app declares about itself for DartWay Studio. Demo
/// personas are NOT declared here — test users and their codes are configured
/// in Studio, so the public web build ships no test accounts.
final exampleStudioManifest = StudioProjectManifest(
  projectName: 'DartWay Example — Fitness Club',
  zones: [clubZoneStudioSpec, adminZoneStudioSpec, authZoneStudioSpec],
  // No full catalog here on purpose. A feature declares its spec inside its
  // own file, next to the widget, and Dart cannot enumerate those at runtime —
  // only the features currently mounted are observable, and those the bridge
  // binding reports per screen. The whole-project catalog is a job for static
  // analysis of the sources, not for the running app.
  // Keep in sync with AppLocalizations.supportedLocales (lib/l10n) — drives
  // the locale switcher in Studio.
  supportedLocales: const ['en', 'ru'],
);
