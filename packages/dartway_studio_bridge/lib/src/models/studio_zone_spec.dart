import 'studio_screen_spec.dart';
import 'studio_text.dart';

/// Who can enter a navigation zone — lets Studio render zone tabs without
/// app-specific knowledge (e.g. which zone is "the auth one").
enum StudioZoneAccess {
  /// Reachable only when a user is signed in.
  signedIn,

  /// Reachable only when signed out; activating it while signed in means
  /// "sign out" (e.g. an auth zone).
  signedOut,

  /// Reachable regardless of the session.
  any,
}

/// A navigation zone of the app: a labelled group of screens with a root
/// route. Zones have no display metadata in routers — it lives here.
class StudioZoneSpec {
  const StudioZoneSpec({
    required this.label,
    required this.rootPath,
    this.access = StudioZoneAccess.any,
    required this.screens,
  });

  final StudioText label;

  /// Full path of the zone's root screen.
  final String rootPath;

  final StudioZoneAccess access;

  final List<StudioScreenSpec> screens;

  Map<String, dynamic> toJson() => {
        'label': label.toJson(),
        'rootPath': rootPath,
        'access': access.name,
        'screens': [for (final screen in screens) screen.toJson()],
      };

  factory StudioZoneSpec.fromJson(Map<String, dynamic> json) => StudioZoneSpec(
        label: StudioText.fromJson(
          json['label'] as Map<String, dynamic>? ?? const {},
        ),
        rootPath: json['rootPath'] as String? ?? '/',
        access: StudioZoneAccess.values.asNameMap()[json['access']] ??
            StudioZoneAccess.any,
        screens: [
          if (json['screens'] is List)
            for (final item in json['screens'] as List)
              if (item is Map<String, dynamic>) StudioScreenSpec.fromJson(item),
        ],
      );
}
