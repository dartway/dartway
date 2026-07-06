import 'package:dartway_router/dartway_router.dart';
import 'package:dartway_example_flutter/core/router/router.dart';
import 'package:dartway_example_flutter/showcase/logic/specs/showcase_screen_spec.dart';
import 'package:dartway_example_flutter/showcase/logic/specs/showcase_zone_specs.dart';

/// Single lookup point over the screen passports. Reused by the showcase
/// panels now and by the course track and docs later.
abstract final class ShowcaseSpecRegistry {
  static final zones = <ShowcaseZoneSpec>[
    appZoneShowcaseSpec,
    authZoneShowcaseSpec,
  ];

  static ShowcaseScreenSpec? specFor(DwNavigationRoute<AppRouterState> route) {
    for (final zone in zones) {
      for (final spec in zone.screens) {
        if (spec.route == route) return spec;
      }
    }
    return null;
  }

  static ShowcaseScreenSpec? specForPath(String path) {
    for (final zone in zones) {
      for (final spec in zone.screens) {
        if (spec.route.fullPath == path) return spec;
      }
    }
    // Fallback for nested locations: the deepest non-root prefix match.
    ShowcaseScreenSpec? bestMatch;
    var bestLength = 0;
    for (final zone in zones) {
      for (final spec in zone.screens) {
        final specPath = spec.route.fullPath;
        if (specPath == '/') continue;
        if (path.startsWith('$specPath/') && specPath.length > bestLength) {
          bestMatch = spec;
          bestLength = specPath.length;
        }
      }
    }
    return bestMatch ?? (path == '/' ? null : specForPath('/'));
  }

  static ShowcaseZoneSpec zoneOf(ShowcaseScreenSpec spec) => zones.firstWhere(
        (zone) => zone.screens.contains(spec),
        orElse: () => zones.first,
      );

  /// Breadcrumb-style label built from the parent route chain, e.g.
  /// 'Profile › Services'. Zone roots keep their own title.
  static String crumbLabel(ShowcaseScreenSpec spec, ShowcaseLanguage language) {
    final labels = <String>[spec.title.resolve(language)];
    var parent = spec.route.descriptor.parent;
    while (parent != null) {
      final parentSpec = specFor(parent);
      if (parentSpec == null || parent.descriptor.parent == null) break;
      labels.insert(0, parentSpec.title.resolve(language));
      parent = parent.descriptor.parent;
    }
    return labels.join(' › ');
  }
}
