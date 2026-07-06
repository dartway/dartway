import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:dartway_example_flutter/core/router/router.dart';
import 'package:dartway_example_flutter/showcase/logic/showcase_navigation_model.dart';
import 'package:dartway_example_flutter/showcase/logic/showcase_user_switcher.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// Level-2 navigation: every screen of the active zone as a breadcrumb-style
/// chip ('Profile › Services'). Clicking navigates the app inside the frame.
class ShowcaseRouteChips extends ConsumerWidget {
  const ShowcaseRouteChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chips = ref.watch(showcaseNavigationProvider).chips;
    final isBusy = ref.watch(showcaseUserSwitcherProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                borderRadius: ShowcaseChrome.chipRadius,
                onTap: isBusy || chip.isActive
                    ? null
                    : () =>
                        ref.read(appRouterProvider).router.go(chip.fullPath),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: chip.isActive
                        ? ShowcaseChrome.chipActiveColor
                        : ShowcaseChrome.chipColor,
                    borderRadius: ShowcaseChrome.chipRadius,
                  ),
                  child: Text(chip.label, style: ShowcaseChrome.chipLabel),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
