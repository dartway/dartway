import 'package:dartway_router/dartway_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'showcase_language_provider.dart';
import 'showcase_location_provider.dart';
import 'specs/showcase_screen_spec.dart';
import 'specs/showcase_spec_registry.dart';

part 'showcase_navigation_model.g.dart';

class ShowcaseCrumbChip {
  const ShowcaseCrumbChip({
    required this.label,
    required this.fullPath,
    required this.isActive,
  });

  final String label;
  final String fullPath;
  final bool isActive;
}

class ShowcaseNavigationModel {
  const ShowcaseNavigationModel({
    required this.activeZone,
    required this.currentSpec,
    required this.chips,
  });

  final ShowcaseZoneSpec activeZone;
  final ShowcaseScreenSpec? currentSpec;
  final List<ShowcaseCrumbChip> chips;
}

/// Everything the top bar and the passport panel need, derived from the
/// current location and the spec registry.
@riverpod
ShowcaseNavigationModel showcaseNavigation(Ref ref) {
  final path = ref.watch(showcaseLocationProvider);
  final language = ref.watch(showcaseLanguageStateProvider);

  final currentSpec = ShowcaseSpecRegistry.specForPath(path);
  final activeZone = currentSpec != null
      ? ShowcaseSpecRegistry.zoneOf(currentSpec)
      : ShowcaseSpecRegistry.zones.first;

  final chips = [
    for (final spec in activeZone.screens)
      ShowcaseCrumbChip(
        label: ShowcaseSpecRegistry.crumbLabel(spec, language),
        fullPath: spec.route.fullPath,
        isActive: spec == currentSpec,
      ),
  ];

  return ShowcaseNavigationModel(
    activeZone: activeZone,
    currentSpec: currentSpec,
    chips: chips,
  );
}
