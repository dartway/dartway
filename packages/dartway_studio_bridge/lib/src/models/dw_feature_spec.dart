import 'studio_text.dart';

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

  final StudioText title;
  final StudioText description;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title.toJson(),
        'description': description.toJson(),
      };

  factory DwFeatureSpec.fromJson(Map<String, dynamic> json) => DwFeatureSpec(
        id: json['id'] as String? ?? '',
        title: StudioText.fromJson(
          json['title'] as Map<String, dynamic>? ?? const {},
        ),
        description: StudioText.fromJson(
          json['description'] as Map<String, dynamic>? ?? const {},
        ),
      );

  static List<DwFeatureSpec> listFromJson(Object? json) => [
        if (json is List)
          for (final item in json)
            if (item is Map<String, dynamic>) DwFeatureSpec.fromJson(item),
      ];
}
