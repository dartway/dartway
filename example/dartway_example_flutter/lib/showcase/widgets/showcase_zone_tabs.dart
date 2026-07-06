import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_router/dartway_router.dart';
import 'package:dartway_example_flutter/core/router/router.dart';
import 'package:dartway_example_flutter/showcase/logic/showcase_language_provider.dart';
import 'package:dartway_example_flutter/showcase/logic/showcase_navigation_model.dart';
import 'package:dartway_example_flutter/showcase/logic/showcase_user_switcher.dart';
import 'package:dartway_example_flutter/showcase/logic/specs/showcase_spec_registry.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// Level-1 navigation: one tab per navigation zone. The auth tab signs the
/// current user out (the guards then land the app on /auth); the club tab is
/// disabled while signed out — the guards would bounce the navigation anyway.
class ShowcaseZoneTabs extends ConsumerWidget {
  const ShowcaseZoneTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeZone = ref.watch(showcaseNavigationProvider).activeZone;
    final language = ref.watch(showcaseLanguageStateProvider);
    final isSignedIn = ref.watch(isSignedInProvider);
    final isBusy = ref.watch(showcaseUserSwitcherProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final zone in ShowcaseSpecRegistry.zones)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ShowcaseZoneTabChip(
              label: zone.label.resolve(language),
              isActive: zone == activeZone,
              isEnabled: !isBusy &&
                  (zone == activeZone ||
                      isSignedIn ||
                      zone.rootRoute == AuthNavigationZone.auth),
              onTap: () {
                if (zone == activeZone) return;
                if (zone.rootRoute == AuthNavigationZone.auth && isSignedIn) {
                  ref
                      .read(showcaseUserSwitcherProvider.notifier)
                      .signOutCurrentUser();
                  return;
                }
                ref
                    .read(appRouterProvider)
                    .router
                    .go(zone.rootRoute.fullPath);
              },
            ),
          ),
      ],
    );
  }
}

class ShowcaseZoneTabChip extends StatelessWidget {
  const ShowcaseZoneTabChip({
    required this.label,
    required this.isActive,
    required this.isEnabled,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isActive;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1 : 0.5,
      child: InkWell(
        borderRadius: ShowcaseChrome.chipRadius,
        onTap: isEnabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? ShowcaseChrome.chipActiveColor
                : ShowcaseChrome.chipColor,
            borderRadius: ShowcaseChrome.chipRadius,
          ),
          child: Text(label, style: ShowcaseChrome.chipLabel),
        ),
      ),
    );
  }
}
