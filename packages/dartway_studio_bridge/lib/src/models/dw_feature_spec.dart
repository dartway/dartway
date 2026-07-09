/// A product feature present on a screen, discovered at runtime from the
/// widgets that declare it (see `DwFeature`). Reported live to Studio and
/// shown on the Technical passport tab.
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
      };

  factory DwFeatureSpec.fromJson(Map<String, dynamic> json) => DwFeatureSpec(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );

  static List<DwFeatureSpec> listFromJson(Object? json) => [
        if (json is List)
          for (final item in json)
            if (item is Map<String, dynamic>) DwFeatureSpec.fromJson(item),
      ];
}
