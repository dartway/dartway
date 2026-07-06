import 'studio_persona_spec.dart';
import 'studio_zone_spec.dart';

/// Everything an app declares about itself for Studio: navigation zones with
/// screen passports and the available demo personas.
///
/// Delivered over the runtime channel in the handshake response, so it can
/// never go stale relative to the running build.
class StudioProjectManifest {
  const StudioProjectManifest({
    required this.projectName,
    required this.zones,
    this.personas = const [],
  });

  final String projectName;

  final List<StudioZoneSpec> zones;

  final List<StudioPersonaSpec> personas;

  Map<String, dynamic> toJson() => {
        'projectName': projectName,
        'zones': [for (final zone in zones) zone.toJson()],
        'personas': [for (final persona in personas) persona.toJson()],
      };

  factory StudioProjectManifest.fromJson(Map<String, dynamic> json) =>
      StudioProjectManifest(
        projectName: json['projectName'] as String? ?? '',
        zones: [
          if (json['zones'] is List)
            for (final item in json['zones'] as List)
              if (item is Map<String, dynamic>) StudioZoneSpec.fromJson(item),
        ],
        personas: [
          if (json['personas'] is List)
            for (final item in json['personas'] as List)
              if (item is Map<String, dynamic>)
                StudioPersonaSpec.fromJson(item),
        ],
      );
}
