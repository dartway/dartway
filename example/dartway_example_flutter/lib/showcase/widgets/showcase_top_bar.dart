import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:dartway_example_flutter/showcase/widgets/showcase_language_toggle.dart';
import 'package:dartway_example_flutter/showcase/widgets/showcase_route_chips.dart';
import 'package:dartway_example_flutter/showcase/widgets/showcase_user_menu.dart';
import 'package:dartway_example_flutter/showcase/widgets/showcase_zone_tabs.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

class ShowcaseTopBar extends StatelessWidget {
  const ShowcaseTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ShowcaseChrome.panelColor,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('DartWay Showcase', style: ShowcaseChrome.brandTitle),
              Gap(20),
              ShowcaseZoneTabs(),
              Spacer(),
              ShowcaseLanguageToggle(),
              Gap(12),
              ShowcaseUserMenu(),
            ],
          ),
          Gap(10),
          ShowcaseRouteChips(),
        ],
      ),
    );
  }
}
