import 'package:dartway_example_flutter/ui_kit/ui_kit.dart';
import 'package:flutter/widgets.dart';

/// Stable example screen used to exercise the design-check binding.
class ProfileDesign extends StatelessWidget {
  const ProfileDesign({super.key});

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.topLeft,
    child: AppCard(child: Text('Profile')),
  );
}
