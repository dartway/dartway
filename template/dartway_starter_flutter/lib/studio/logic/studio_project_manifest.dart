import 'package:dartway_studio_bridge/dartway_studio_bridge.dart';

import 'app_features.dart';
import 'specs/studio_zone_specs.dart';

/// Everything this app declares about itself for DartWay Studio: its zones
/// and the screens in them. Rename the project and add your zones as the app
/// grows — Studio reads this, nothing else. Demo personas are NOT declared
/// here — test users and their codes are configured in Studio, so the public
/// web build ships no test accounts.
final appStudioManifest = StudioProjectManifest(
  projectName: 'DartWay Starter',
  zones: [appZoneStudioSpec, adminZoneStudioSpec, authZoneStudioSpec],
  // The full feature catalog — the registry enum is enumerable by
  // construction, so the manifest can never miss a feature.
  features: [
    for (final feature in AppFeatures.values)
      StudioFeatureInfo(
        id: feature.id,
        title: feature.title,
        description: feature.description,
      ),
  ],
  // Keep in sync with AppLocalizations.supportedLocales (lib/l10n) — drives
  // the locale switcher in Studio.
  supportedLocales: const ['en', 'ru'],
);
