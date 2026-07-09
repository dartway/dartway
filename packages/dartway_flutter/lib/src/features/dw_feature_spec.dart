/// A product feature present on a screen, discovered at runtime from the
/// widgets that declare it (see `DwFeature`). The semantic layer of the app:
/// feature catalogs, error-report context, analytics, docs — and DartWay
/// Studio passports (delivered over the bridge by the app's binding).
class DwFeatureSpec {
  const DwFeatureSpec({
    required this.id,
    required this.title,
    required this.description,
  });

  /// Stable id — deduplicates a feature declared by multiple widget instances.
  final String id;

  final String title;
  final String description;
}
