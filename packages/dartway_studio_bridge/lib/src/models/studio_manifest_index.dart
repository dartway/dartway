import 'studio_project_manifest.dart';
import 'studio_screen_spec.dart';
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

  /// The spec for a location the app is actually at.
  ///
  /// **A manifest declares templates, an app reports addresses.** A screen that
  /// takes a parameter is declared once, as `/public-profile/:userId`, and the
  /// running app reports `/public-profile/7` — so a lookup that only compares
  /// strings finds nothing for exactly those screens, and finds it silently:
  /// the caller gets null and falls back to whatever it does without a spec.
  /// Downstream that shows up as the wrong screen title, the wrong navigation
  /// chip, and an issue filed against an address the project's screen registry
  /// has never heard of.
  ///
  /// Order: exact match, then a template match, then the deepest non-root
  /// prefix (covers nested locations like `/schedule/profile/edit` → the
  /// profile spec).
  StudioScreenSpec? specForPath(String path) {
    final exact = _byPath[path];
    if (exact != null) return exact;

    final templateMatch = _templateMatch(path);
    if (templateMatch != null) return templateMatch;

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

  /// The declared template this address is an instance of.
  ///
  /// A segment beginning with `:` stands for one value and matches any single
  /// segment; every other segment must match literally, and the two paths must
  /// have the same number of segments — `/a/:id` describes one screen, not the
  /// whole subtree below `/a`.
  ///
  /// Where several templates fit, the one with more literal segments wins:
  /// `/admin/users` is a screen in its own right even when `/admin/:section`
  /// is also declared. A tie keeps the first declared, so the answer follows
  /// the manifest and not the iteration order of a map.
  StudioScreenSpec? _templateMatch(String path) {
    final addressSegments = _segmentsOf(path);
    StudioScreenSpec? bestMatch;
    var bestLiteralCount = -1;

    for (final entry in _byPath.entries) {
      final templateSegments = _segmentsOf(entry.key);
      if (templateSegments.length != addressSegments.length) continue;

      var literalCount = 0;
      var fits = true;
      for (var position = 0; position < templateSegments.length; position++) {
        final templateSegment = templateSegments[position];
        if (templateSegment.startsWith(':')) continue;
        if (templateSegment != addressSegments[position]) {
          fits = false;
          break;
        }
        literalCount++;
      }

      if (fits && literalCount > bestLiteralCount) {
        bestMatch = entry.value;
        bestLiteralCount = literalCount;
      }
    }
    return bestMatch;
  }

  static List<String> _segmentsOf(String path) =>
      path.split('/').where((segment) => segment.isNotEmpty).toList();

  StudioZoneSpec zoneOf(StudioScreenSpec spec) => manifest.zones.firstWhere(
        (zone) => zone.screens.contains(spec),
        orElse: () => manifest.zones.first,
      );

  /// Breadcrumb-style label built from the parent chain, e.g.
  /// `Profile › Services`. Zone roots keep their own title.
  String crumbLabel(StudioScreenSpec spec) {
    final labels = <String>[spec.title];
    var parentPath = spec.parentPath;
    while (parentPath != null) {
      final parentSpec = _byPath[parentPath];
      if (parentSpec == null || parentSpec.parentPath == null) break;
      labels.insert(0, parentSpec.title);
      parentPath = parentSpec.parentPath;
    }
    return labels.join(' › ');
  }
}
