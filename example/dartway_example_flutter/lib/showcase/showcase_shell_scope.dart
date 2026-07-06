import 'package:flutter/material.dart';
import 'package:dartway_example_flutter/showcase/widgets/showcase_passport_panel.dart';
import 'package:dartway_example_flutter/showcase/widgets/showcase_top_bar.dart';
import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';

/// The showcase chrome around the live app: top navigation, the app in its
/// device frame on the left, the screen passport on the right. On narrow
/// screens the chrome disappears and the regular app is shown.
class ShowcaseShellScope extends StatelessWidget {
  const ShowcaseShellScope({required this.appChild, super.key});

  final Widget appChild;

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) return appChild;

    return Scaffold(
      backgroundColor: ShowcaseChrome.background,
      body: Column(
        children: [
          const ShowcaseTopBar(),
          Expanded(
            child: Row(
              children: [
                Expanded(child: appChild),
                const ShowcasePassportPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
