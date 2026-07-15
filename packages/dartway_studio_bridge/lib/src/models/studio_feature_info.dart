/// Wire model of a product feature present on the current screen, as the app
/// reports it over the bridge (shown on the Technical passport tab).
///
/// The bridge does not know *how* the app discovers its features — DartWay
/// apps typically map `DwFeatureSpec`s collected by `DwFeature.scanMounted()`
/// (package `dartway_flutter`) onto this model in their bridge binding, but
/// any source works.
class StudioFeatureInfo {
  const StudioFeatureInfo({
    required this.id,
    required this.title,
    required this.description,
  });

  /// Stable id — deduplicates a feature reported by multiple widget instances.
  final String id;

  final String title;
  final String description;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
      };

  factory StudioFeatureInfo.fromJson(Map<String, dynamic> json) =>
      StudioFeatureInfo(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );

  static List<StudioFeatureInfo> listFromJson(Object? json) => [
        if (json is List)
          for (final item in json)
            if (item is Map<String, dynamic>) StudioFeatureInfo.fromJson(item),
      ];
}
