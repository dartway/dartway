import 'studio_persona_spec.dart';
import 'studio_screen_spec.dart';
import 'studio_zone_spec.dart';

/// Everything an app declares about itself for Studio: navigation zones with
/// screen passports, the available demo personas and the UI locales the app
/// can switch between.
///
/// Delivered over the runtime channel in the handshake response, so it can
/// never go stale relative to the running build.
class StudioProjectManifest {
  const StudioProjectManifest({
    required this.projectName,
    required this.zones,
    this.personas = const [],
    this.supportedLocales = const [],
  });

  final String projectName;

  final List<StudioZoneSpec> zones;

  final List<StudioPersonaSpec> personas;

  /// Language tags of the app's UI locales (e.g. `['en', 'ru']`), first one
  /// is the default. Zero or one locale means the app is not switchable and
  /// Studio hides its locale control.
  final List<String> supportedLocales;

  Map<String, dynamic> toJson() => {
        'projectName': projectName,
        'zones': [for (final zone in zones) zone.toJson()],
        'personas': [for (final persona in personas) persona.toJson()],
        'supportedLocales': supportedLocales,
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
        supportedLocales:
            StudioScreenSpec.stringListFromJson(json['supportedLocales']),
      );
}
