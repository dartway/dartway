import 'studio_screen_spec.dart';
import 'studio_zone_spec.dart';

/// Everything an app declares about itself for Studio: navigation zones with
/// screen passports and the UI locales the app can switch between.
///
/// Demo personas are deliberately NOT part of the manifest: test users and
/// their codes are configured in Studio (a platform concern), so a public web
/// build never ships a list of privileged test accounts.
///
/// Delivered over the runtime channel in the handshake response, so it can
/// never go stale relative to the running build.
class StudioProjectManifest {
  const StudioProjectManifest({
    required this.projectName,
    required this.zones,
    this.supportedLocales = const [],
  });

  final String projectName;

  final List<StudioZoneSpec> zones;

  /// Language tags of the app's UI locales (e.g. `['en', 'ru']`), first one
  /// is the default. Zero or one locale means the app is not switchable and
  /// Studio hides its locale control.
  final List<String> supportedLocales;

  Map<String, dynamic> toJson() => {
        'projectName': projectName,
        'zones': [for (final zone in zones) zone.toJson()],
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
        supportedLocales:
            StudioScreenSpec.stringListFromJson(json['supportedLocales']),
      );
}
