import 'studio_project_manifest.dart';
import 'studio_screen_spec.dart';
import 'studio_text.dart';
import 'studio_zone_spec.dart';

/// Lookup helpers over a [StudioProjectManifest]: resolve the spec for a
/// route path and build breadcrumb labels from the parent chain.
class StudioManifestIndex {
  StudioManifestIndex(this.manifest)
      : _byPath = {
          for (final zone in manifest.zones)
            for (final screen in zone.screens) screen.path: screen,
        };

  final StudioProjectManifest manifest;
  final Map<String, StudioScreenSpec> _byPath;

  /// Exact match first, then the deepest non-root prefix match (covers nested
  /// locations like `/schedule/profile/edit` → the profile spec).
  StudioScreenSpec? specForPath(String path) {
    final exact = _byPath[path];
    if (exact != null) return exact;

    StudioScreenSpec? bestMatch;
    var bestLength = 0;
    for (final entry in _byPath.entries) {
      final specPath = entry.key;
      if (specPath == '/') continue;
      if (path.startsWith('$specPath/') && specPath.length > bestLength) {
        bestMatch = entry.value;
        bestLength = specPath.length;
      }
    }
    return bestMatch ?? (path == '/' ? null : _byPath['/']);
  }

  StudioZoneSpec zoneOf(StudioScreenSpec spec) => manifest.zones.firstWhere(
        (zone) => zone.screens.contains(spec),
        orElse: () => manifest.zones.first,
      );

  /// Breadcrumb-style label built from the parent chain, e.g.
  /// `Profile › Services`. Zone roots keep their own title.
  String crumbLabel(StudioScreenSpec spec, StudioLanguage language) {
    final labels = <String>[spec.title.resolve(language)];
    var parentPath = spec.parentPath;
    while (parentPath != null) {
      final parentSpec = _byPath[parentPath];
      if (parentSpec == null || parentSpec.parentPath == null) break;
      labels.insert(0, parentSpec.title.resolve(language));
      parentPath = parentSpec.parentPath;
    }
    return labels.join(' › ');
  }
}
