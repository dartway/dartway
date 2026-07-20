import 'package:dartway_flutter/dartway_flutter.dart';

/// The app's feature registry — the single enumerable source of feature
/// identity. Widgets reference these values from their [DwFeature]
/// implementation; the Studio manifest ships `values` as the full catalog, so
/// the platform can diff it on every connect.
///
/// Id convention: `<feature-folder>/<meaningful-name>` — the prefix is the
/// widget's top-level feature folder under `lib/app/`. Ids are a contract:
/// never rename one in place — add a new value and retire the old id
/// explicitly (platform work may be linked to it).
enum AppFeatures implements DwFeatureSpec {
  homeLiveSettings(
    id: 'home/live-settings',
    title: 'Live app settings',
    description: 'The app name on the home screen is a watchModelList over '
        'AppSetting — change it in the admin panel and it updates here '
        'without a reload.',
  ),
  adminCounters(
    id: 'admin/live-counters',
    title: 'Live dashboard counters',
    description: 'Plain watchModelList calls — the same realtime CRUD the '
        'client app uses, no separate admin API.',
  );

  const AppFeatures({
    required this.id,
    required this.title,
    required this.description,
  });

  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
}
